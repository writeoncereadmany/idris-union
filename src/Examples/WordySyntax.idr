module WordySyntax

import Union

-- declaring union types

StringOrBool : Type
StringOrBool = Union [ String, Bool ]

BoolOrString : Type
BoolOrString = Union [ Bool, String ]

StringBoolOrNat : Type
StringBoolOrNat = Union [ String, Bool, Nat ]

-- instantiating union types

itsABool : StringOrBool
itsABool = just True

itsAString : StringOrBool
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

stillAString : StringBoolOrNat
stillAString = widen itsAString

-- or exactly the same set of types, just specified in a different order

alsoStillAString : BoolOrString
alsoStillAString = widen itsAString

-- funions are functions over unions, built from functions over its possibilities

display : Funion [String, Bool, Nat ] String
display = [ id, show, show ]

-- and can be applied to a union using match

showMeTheString : String
showMeTheString = match stillAString display

-- including subtype matches - note that here,
-- display is a (String || Bool || Nat) |-> String
-- but itsAString is just a (String || Bool)

showMeTheString2 : String
showMeTheString2 = match itsAString display
