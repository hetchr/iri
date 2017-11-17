module Iri.Parsing.Attoparsec.ByteString
(
  url,
)
where

import Iri.Prelude hiding (foldl, hash)
import Iri.Data
import Data.Attoparsec.ByteString hiding (try)
import qualified Data.Attoparsec.ByteString.Char8 as F
import qualified Data.ByteString as K
import qualified Data.Text as R
import qualified Data.Text.Punycode as A
import qualified Data.Text.Encoding as B
import qualified Data.Text.Encoding.Error as L
import qualified Data.HashMap.Strict as O
import qualified VectorBuilder.Builder as P
import qualified VectorBuilder.Vector as Q
import qualified Iri.PercentEncoding as I
import qualified Iri.CodePointPredicates.Rfc3986 as C
import qualified Iri.MonadPlus as R
import qualified VectorBuilder.MonadPlus as E
import qualified Ptr.Poking as G
import qualified Ptr.ByteString as H
import qualified Text.Builder as J
import qualified Net.IPv4 as M
import qualified Net.IPv6 as N


{-# INLINE percent #-}
percent :: Parser Word8
percent =
  word8 37

{-# INLINE colon #-}
colon :: Parser Word8
colon =
  word8 58

{-# INLINE at #-}
at :: Parser Word8
at =
  word8 64

{-# INLINE forwardSlash #-}
forwardSlash :: Parser Word8
forwardSlash =
  word8 47

{-# INLINE question #-}
question :: Parser Word8
question =
  word8 63

{-# INLINE hash #-}
hash :: Parser Word8
hash =
  word8 35

{-# INLINE equality #-}
equality :: Parser Word8
equality =
  word8 61

{-# INLINE ampersand #-}
ampersand :: Parser Word8
ampersand =
  word8 38

{-# INLINE semicolon #-}
semicolon :: Parser Word8
semicolon =
  word8 59

{-|
Parser of a well-formed URL conforming to the RFC1738 standard into IRI.
-}
url :: Parser Iri
url =
  do
    parsedScheme <- scheme
    string "://"
    parsedAuthority <- (presentAuthority PresentAuthority <* at) <|> pure MissingAuthority
    parsedHost <- host
    parsedPort <- PresentPort <$> (colon *> port) <|> pure MissingPort
    pathFollows <- True <$ forwardSlash <|> pure False
    if pathFollows
      then do
        parsedPath <- path
        parsedQuery <- query
        parsedFragment <- fragment
        return (Iri parsedScheme parsedAuthority parsedHost parsedPort parsedPath parsedQuery parsedFragment)
      else return (Iri parsedScheme parsedAuthority parsedHost parsedPort (Path mempty) (Query mempty) (Fragment mempty))

{-# INLINE scheme #-}
scheme :: Parser Scheme
scheme =
  fmap Scheme (takeWhile1 (C.scheme . fromIntegral))

{-# INLINABLE presentAuthority #-}
presentAuthority :: (User -> Password -> a) -> Parser a
presentAuthority result =
  do
    user <- User <$> urlEncodedComponent (C.unencodedPathSegment . fromIntegral)
    passwordFollows <- True <$ colon <|> pure False
    if passwordFollows
      then do
        password <- PresentPassword <$> urlEncodedComponent (C.unencodedPathSegment . fromIntegral)
        return (result user password)
      else return (result user MissingPassword)

{-# INLINE host #-}
host :: Parser Host
host =
  IpV6Host <$> ipV6 <|>
  IpV4Host <$> M.parserUtf8 <|>
  NamedHost <$> domainName

{-# INLINABLE ipV6 #-}
ipV6 :: Parser IPv6
ipV6 =
  do
    a <- F.hexadecimal
    colon
    b <- F.hexadecimal
    colon
    c <- F.hexadecimal
    colon
    d <- F.hexadecimal
    colon
    mplus
      (do
        e <- F.hexadecimal
        colon
        f <- F.hexadecimal
        colon
        g <- F.hexadecimal
        colon
        h <- F.hexadecimal
        return (N.fromWord16s a b c d e f g h))
      (do
        colon
        return (N.fromWord16s a b c d 0 0 0 0))

{-# INLINE domainName #-}
domainName :: Parser Idn
domainName =
  fmap Idn (E.sepBy1 domainLabel (word8 46))

{-|
Domain label with Punycode decoding applied.
-}
{-# INLINE domainLabel #-}
domainLabel :: Parser DomainLabel
domainLabel =
  do
    punycodeFollows <- True <$ string "xn--" <|> pure False
    ascii <- takeWhile1 (C.domainLabel . fromIntegral)
    if punycodeFollows
      then case A.decode ascii of
        Right text -> return (DomainLabel text)
        Left exception -> fail (showString "Punycode decoding exception: " (show exception))
      else return (DomainLabel (B.decodeUtf8 ascii))

{-# INLINE port #-}
port :: Parser Word16
port =
  F.decimal

{-# INLINE path #-}
path :: Parser Path
path =
  fmap Path (E.sepBy pathSegment (word8 47))

{-# INLINE pathSegment #-}
pathSegment :: Parser PathSegment
pathSegment =
  fmap PathSegment (urlEncodedComponent (C.unencodedPathSegment . fromIntegral))

{-# INLINABLE urlEncodedComponent #-}
urlEncodedComponent :: (Word8 -> Bool) -> Parser Text
urlEncodedComponent unencodedBytesPredicate =
  R.foldlM progress (mempty, mempty, B.streamDecodeUtf8) partPoking >>= finish
  where
    progress (!builder, _, decode) bytes =
      case unsafeDupablePerformIO (try (evaluate (decode bytes))) of
        Right (B.Some decodedChunk undecodedBytes newDecode) ->
          return (builder <> J.text decodedChunk, undecodedBytes, newDecode)
        Left (L.DecodeError error _) ->
          fail (showString "UTF8 decoding: " error)
    finish (builder, undecodedBytes, _) =
      if K.null undecodedBytes
        then return (J.run builder)
        else fail (showString "UTF8 decoding: Bytes remaining: " (show undecodedBytes))
    partPoking =
      takeWhile1 unencodedBytesPredicate <|> encoded
      where
        encoded =
          K.singleton <$> percentEncodedByte

{-# INLINE percentEncodedByte #-}
percentEncodedByte :: Parser Word8
percentEncodedByte =
  do
    percent 
    byte1 <- anyWord8
    byte2 <- anyWord8
    I.matchPercentEncodedBytes (fail "Broken percent encoding") return byte1 byte2

{-# INLINABLE query #-}
query :: Parser Query
query =
  do
    queryFollows <- True <$ question <|> pure False
    if queryFollows
      then existingQuery
      else return (Query mempty)

{-|
The stuff after the question mark.
-}
{-# INLINABLE existingQuery #-}
existingQuery :: Parser Query
existingQuery =
  fmap Query (E.sepBy (queryPair (,)) ampersand)

{-# INLINE queryPair #-}
queryPair :: (Text -> Text -> a) -> Parser a
queryPair result =
  do
    !key <- urlEncodedComponent (C.unencodedQueryComponent . fromIntegral)
    when (R.null key) (fail "Key is empty")
    optional (string "[]")
    !value <- (equality *> urlEncodedComponent (C.unencodedQueryComponent . fromIntegral)) <|> pure ""
    return (result key value)

{-# INLINABLE fragment #-}
fragment :: Parser Fragment
fragment =
  do
    fragmentFollows <- True <$ hash <|> pure False
    if fragmentFollows
      then Fragment <$> urlEncodedComponent (C.unencodedFragment . fromIntegral)
      else return (Fragment mempty)