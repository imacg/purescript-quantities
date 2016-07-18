module Data.Quantity
  ( Quantity
  , quantity
  , (.*)
  , derivedUnit
  , toStandard
  , approximatelyEqual
  -- Conversion errors
  , UnificationError
  , errorMessage
  -- Create a dimensionless quantity
  , scalar
  -- Convert quantities
  , convertTo
  , asValueIn
  -- Calculate with quantities
  , qAdd
  , (⊕)
  , qMultiply
  , (⊗)
  , pow
  , abs
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Tuple (Tuple(..))

import Data.DerivedUnit (DerivedUnit, toString, (.^))
import Data.DerivedUnit as D

import Math as Math

-- | Representation of a physical quantity as a (product of a) numerical value
-- | and a physical unit.
data Quantity = Quantity Number DerivedUnit

-- Used only internally for pattern matching
infix 3 Quantity as .*.

-- | Construct a physical quantity from a numerical value and the physical
-- | unit.
quantity :: Number → DerivedUnit → Quantity
quantity = Quantity -- note that we define `quantity` because we do not want
                    -- to export the `Quantity` constructor. This would leak
                    -- the internal representation and the bare numerical
                    -- values.

infix 5 quantity as .*

instance eqQuantity :: Eq Quantity where
  eq q1 q2 = value q1' == value q2' && derivedUnit q1' == derivedUnit q2'
    where
      q1' = toStandard q1
      q2' = toStandard q2

instance showQuantity :: Show Quantity where
  show (Quantity num unit) = show num <> toString unit

-- | The numerical value stored inside a `Quantity`. For internal use only
-- | (bare `Number`s without units should be handled with care).
value :: Quantity → Number
value (v .*. _) = v

-- | The unit of a physical quantity.
derivedUnit :: Quantity → DerivedUnit
derivedUnit (_ .*. u) = u

-- | Convert a quantity to its SI representation.
toStandard :: Quantity → Quantity
toStandard (num .*. du) =
  case D.toStandardUnit du of
    Tuple du' conversion → (conversion * num) .* du'

-- | Check whether two quantities have matching units (or can be converted
-- | to the same representation) and test if the numerical are approximately
-- | equal.
approximatelyEqual :: Number → Quantity → Quantity → Boolean
approximatelyEqual tol q1' q2' =
  derivedUnit q1 == derivedUnit q2 &&
  Math.abs (v1 - v2) < tol * Math.abs (v1 + v2) / 2.0
    where
      q1 = toStandard q1'
      q2 = toStandard q2'
      v1 = value q1
      v2 = value q2

-- | A unit conversion error that appears if two given units cannot be
-- | converted into each other.
data UnificationError = UnificationError DerivedUnit DerivedUnit

derive instance eqUnificationError :: Eq UnificationError

instance showUnificationError :: Show UnificationError where
  show (UnificationError u1 u2) = "(UnificationError " <> show u1 <> " "
                                                       <> show u2 <> ")"

-- | Textual representation of a unit conversion error.
errorMessage :: UnificationError → String
errorMessage (UnificationError u1 u2) =
  "Cannot unify unit '" <> toString u1 <> "' with unit '" <> toString u2 <> "'"

-- | Create a scalar (i.e. dimensionless) quantity from a number.
scalar :: Number → Quantity
scalar factor = factor .* D.unity

-- | Attempt to convert a physical quantity to a given target unit. Returns a
-- | `UnificationError` if the conversion fails.
convert :: DerivedUnit → Quantity → Either UnificationError Quantity
convert to q@(val .*. from)
  | to == from = Right q
  | otherwise =
      case D.toStandardUnit to of
        Tuple to' factor →
          let q' = toStandard q
              from' = derivedUnit q'
          in
            if from' == to'
              then Right $ q' ⊗ scalar (1.0 / factor)
              else Left $ UnificationError to from

-- | Flipped version of `convert`.
convertTo :: Quantity → DerivedUnit → Either UnificationError Quantity
convertTo = flip convert

-- | Get the numerical value of a physical quantity in a given unit. Returns a
-- | `UnificationError` if the conversion fails.
asValueIn :: Quantity → DerivedUnit → Either UnificationError Number
asValueIn u = convertTo u >=> value >>> pure

-- | Attempt to add two quantities. If the units can not be unified, an error
-- | is returned.
qAdd :: Quantity → Quantity → Either UnificationError Quantity
qAdd (v1 .*. u1) q2 = do
  q2' <- q2 `convertTo` u1
  case q2' of
    (v2 .*. _) → pure $ (v1 + v2) .* u1

infixl 3 qAdd as ⊕

-- | Multiply two quantities.
qMultiply :: Quantity → Quantity → Quantity
qMultiply (v1 .*. u1) (v2 .*. u2) = (v1 * v2) .* (u1 <> u2)

infixl 4 qMultiply as ⊗

-- | Raise a quantity to a given power.
pow :: Quantity → Number → Quantity
pow (val .*. u) exp = (val `Math.pow` exp) .* (u .^ exp)

-- | The absolute value of a quantity.
abs :: Quantity → Quantity
abs (val .*. u) = Math.abs val .* u
