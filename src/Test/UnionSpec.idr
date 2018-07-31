module UnionSpec

import Union
import Specdris.Spec

%access public export

specs : IO ()
specs = spec $ do
  describe "can create and extract from a union" $ do
    it "let's start with some clunky type clarifications" $ do
      let union = the (Union [String, Nat, Bool]) (just "Hello")
      (the (Maybe String) (perhaps union)) `shouldBe` Just "Hello"
      (the (Maybe Bool) (perhaps union)) `shouldBe` Nothing
