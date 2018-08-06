module UnionSpec

import Union
import Specdris.Spec

%access public export

data Square = FourSides Double
data Triangle = WidthAndHeight Double Double
data Circle = Radius Double

Shape : Type
Shape = Union [Square, Triangle, Circle]

-- these are functions
area_square : Square -> Double
area_square (FourSides x) = x * x

area_triangle : Triangle -> Double
area_triangle (WidthAndHeight x y) = x * y / 2

area_circle : Circle -> Double
area_circle (Radius r) = pi * r * r

-- and this is a funion
area : [Square, Triangle, Circle] |-> Double
area = area_square || area_triangle || area_circle

-- also expressible thusly
area' : Shape |-> Double
area' = area

specs : IO ()
specs = spec $ do
  describe "can create and extract from a union" $ do
    it "let's start with some clunky type clarifications" $ do
      let union = the (Union [String, Nat, Bool]) (just "Hello")
      (the (Maybe String) (extract union)) `shouldBe` Just "Hello"
      (the (Maybe Bool) (extract union)) `shouldBe` Nothing
