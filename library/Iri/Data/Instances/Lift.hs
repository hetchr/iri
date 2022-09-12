module Iri.Data.Instances.Lift
where

import Iri.Prelude
import Iri.Data.Types
import Language.Haskell.TH.Lift


deriveLift ''Scheme

deriveLift ''Authority

deriveLift ''Hierarchy

deriveLift ''UserInfo

deriveLift ''User

deriveLift ''Password

deriveLift ''Host

deriveLift ''RegName

deriveLift ''DomainLabel

deriveLift ''Port

deriveLift ''Path

deriveLift ''PathSegment

deriveLift ''Query

deriveLift ''Fragment

deriveLift ''HttpIri

deriveLift ''Security

deriveLift ''Iri
