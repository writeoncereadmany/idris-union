module SymbolicSyntax

import Union

-- instantiating union types

itsABool : Union [String, Bool]
itsABool = just True

itsAString : Union [String, Bool]
itsAString = just "Hello"

-- extracting from union types: it could be a string, or a bool, but not a nat

probablyString : Maybe String
probablyString = perhaps itsAString -- yielding Just "Hello"

probablyNotBool : Maybe Bool
probablyNotBool = perhaps itsAString -- yielding Nothing

-- fails to compile
-- definitelyNotNat : Maybe Nat
-- definitelyNotNat = perhaps itsAString

-- widening union types, either to a larger set of types

stillAString : Union [String, Bool, Nat]
stillAString = widen itsAString

-- or exactly the same set of types, just specified in a different order

alsoStillAString : Union [Bool, String]
alsoStillAString = widen itsAString

-- funions are functions over unions, built from functions over its possibilities

display : [String, Bool, Nat] |-> String
display = id || show || show

-- and can be applied to a union using match

showMeTheString : String
showMeTheString = display |$| stillAString

-- including subtype matches - note that here,
-- display is a (String || Bool || Nat) |-> String
-- but itsAString is just a (String || Bool)

showMeTheString2 : String
showMeTheString2 = display |$| itsAString

-- and even on raw types, if they match a union case

showMeTheString3 : String
showMeTheString3 = display $ True

-- we can also create funions inline
showString : String -> String
showString str = "A string, value " ++ str

showBool : Bool -> String
showBool b = "A boolean, value " ++ show b

showNat : Nat -> String
showNat n = "A number, value " ++ show n

showStringOrBool : [String, Bool] |-> String
showStringOrBool = showString || showBool

showMe : String
showMe = (the Nat 42) >>> showStringOrBool || showNat

data Yay = Awesome String
data Whoopsie = OhNo String

beforeErrorHandling : String -> Yay
beforeErrorHandling = Awesome

afterErrorHandling : String -> Union [Yay, Whoopsie]
afterErrorHandling input = if input == "explode" then just (OhNo input) else just (Awesome input)

showYay : Yay -> String
showYay (Awesome x) = "Awesome! " ++ x

showWhoopsie : Whoopsie -> String
showWhoopsie (OhNo x) = "Oh no! " ++ x

original : String -> String
original str = str >>> beforeErrorHandling >>> showYay

original2 : String -> String
original2 str = str >>> beforeErrorHandling >>> showYay
                                             || showWhoopsie

modified : String -> String
modified str = str >>> afterErrorHandling |>> showYay
                                           || showWhoopsie
