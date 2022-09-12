module Iri.Data.Instances.Lift
where

import Iri.Prelude
import Iri.Data.Types
import Language.Haskell.TH.Lift


deriveLift ''Scheme

deriveLift ''User

deriveLift ''Password

deriveLift ''UserInfo

deriveLift ''DomainLabel

deriveLift ''RegName

deriveLift ''Host

deriveLift ''Port

deriveLift ''Authority

deriveLift ''PathSegment

deriveLift ''Path

deriveLift ''Hierarchy

deriveLift ''Query

deriveLift ''Fragment

deriveLift ''Security

deriveLift ''HttpIri

deriveLift ''Iri
