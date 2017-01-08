{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE DeriveGeneric #-}

module GraphQL.API.Enum where

import Protolude hiding (Enum, U1, TypeError)
import GraphQL.Internal.AST (Name, nameFromSymbol)
import qualified GraphQL.Value as GValue
import GHC.Generics -- TODO explicit imports
import GHC.TypeLits (KnownSymbol, TypeError, ErrorMessage(..))

{-
For values we need to extract the whole representation, e.g.:

λ  :kind! (Rep B)
(Rep B) :: * -> *
= D1
    ('MetaData "B" "Ghci1" "interactive" 'False)
    (C1 ('MetaCons "B1" 'PrefixI 'False) U1
     :+: (C1 ('MetaCons "B2" 'PrefixI 'False) U1
          :+: C1 ('MetaCons "B3" 'PrefixI 'False) U1))
-}

class GenricEnumValues (r :: Type -> Type) where
  genericEnumValues :: [Name]
  genericEnumFromValue :: GValue.Value -> Either Text (r p)

instance forall n m p f nt. (KnownSymbol n, KnownSymbol m, KnownSymbol p, GenricEnumValues f) => GenricEnumValues (M1 D ('MetaData n m p nt) f) where
  genericEnumValues = genericEnumValues @f
  genericEnumFromValue v@(GValue.ValueEnum _) = fmap M1 (genericEnumFromValue v)
  genericEnumFromValue x = Left ("Not an enum: " <> show x)

instance (KnownSymbol n, GenricEnumValues f) => GenricEnumValues (C1 ('MetaCons n p b) U1 :+: f) where
  genericEnumValues = let Right name = nameFromSymbol @n in name:(genericEnumValues @f)
  genericEnumFromValue v@(GValue.ValueEnum vname) =
    case nameFromSymbol @n of
      Right name -> if name == vname
                    then fmap L1 (Right (M1 U1 :: (C1 ('MetaCons n p b) U1 f')))
                    else fmap R1 (genericEnumFromValue v)
      Left x -> Left ("Not a valid enum name: " <> show x)
  genericEnumFromValue _ = panic "This case should have been caught at top-level. Please file a bug."

instance forall n p b. (KnownSymbol n) => GenricEnumValues (C1 ('MetaCons n p b) U1) where
  genericEnumValues = let Right name = nameFromSymbol @n in [name]
  genericEnumFromValue (GValue.ValueEnum vname) =
    case nameFromSymbol @n of
      Right name -> if name == vname
                    then Right (M1 U1 :: (C1 ('MetaCons n p b) U1 f'))
                    else Left ("Not a valid enum name: " <> show vname)
      Left x -> Left ("Not a valid enum name: " <> show x)
  genericEnumFromValue _ = panic "This case should have been caught at top-level. Please file a bug."


-- TODO(tom): better type errors using `n`
instance ( TypeError ('Text "Constructor not unary: " ':<>: 'Text n), KnownSymbol n
         ) => GenricEnumValues (C1 ('MetaCons n p b) (S1 sa sb)) where
  genericEnumValues = undefined
  genericEnumFromValue = undefined

instance ( TypeError ('Text "Constructor not unary: " ':<>: 'Text n), KnownSymbol n
         ) => GenricEnumValues (C1 ('MetaCons n p b) (S1 sa sb) :+: f) where
  genericEnumValues = undefined
  genericEnumFromValue = undefined

-- | For each enum type we need 1) a list of all possible values 2) a
-- way to serialise and 3) deserialise.
class (GenricEnumValues (Rep a), Generic a) => GraphQLEnum a where
  enumValues :: [Name]
  enumValues = genericEnumValues @(Rep a)

  enumFromValue :: GValue.Value -> Either Text a
  enumFromValue v = fmap to (genericEnumFromValue v)
  enumToValue :: a -> GValue.Value

  enumToValue _ = undefined -- TODO

instance GraphQLEnum B

data B = B1 | B2 | B3 deriving (Generic, Show)
data A = A1 | A2 Text | A3 deriving (Generic, Show)
