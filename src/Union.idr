module Union

%access public export

namespace Union
  data Union : List Type -> Type where
    This  : a -> Union (a :: rest)
    NotYet : Union xs -> Union (a :: xs)

  data Contains : List Type -> Type -> Type where
    Now : Contains (x :: _) x
    Later : Contains xs type -> Contains (_ :: xs) type

  data SupersetOf : (super : List Type) -> (sub : List Type) -> Type where
    AnythingSuperEmpty : SupersetOf _ []
    ThisOneCovered : Contains super first
                  -> SupersetOf super (rest)
                  -> SupersetOf super (first :: rest)

  -- i'll work out how to use pattern matching instead once I get deeper into
  -- elaborator reflection
  -- maybe?
  data MatchClause : List Type -> Type -> Type where
    Nil : MatchClause [] a
    (::) : (x -> a) -> MatchClause xs a -> MatchClause (x :: xs) a

  total
  perhaps : Union xs -> { auto prf : Contains xs a } -> Maybe a
  perhaps (This x) { prf = Now } = Just x
  perhaps (This _) { prf = (Later _) } = Nothing
  perhaps (NotYet _) { prf = Now } = Nothing
  perhaps (NotYet x) { prf = (Later _) } = perhaps x

  total
  match' : Union xs -> MatchClause xs a -> a
  match' (This val) (f :: _) = f val
  match' (NotYet rest) (_ :: cases) = match' rest cases

  total
  just : a -> { auto prf : Contains ys a } -> Union ys
  just x { prf = Now } = This x
  just x { prf = Later _} = NotYet $ just x

  total
  widen : Union xs
       -> { auto prf : SupersetOf ys xs }
       -> Union ys
  widen _ { prf = AnythingSuperEmpty } impossible
  widen (This x) { prf = (ThisOneCovered y z) } = just x
  widen (NotYet x) { prf = (ThisOneCovered y z) } = widen x

  data CanReplace : List Type -> Type -> Type -> List Type -> Type where
    ReplaceHere : CanReplace (a :: xs) a b (b :: xs)
    ReplaceThere : CanReplace xs a b ys -> CanReplace (x :: xs) a b (x :: ys)

  showReplacement : (xs : List Type)
                 -> (a : Type)
                 -> (b : Type)
                 -> { auto prf : CanReplace xs a b ys }
                 -> List Type
  showReplacement (a :: ys) a b { prf  =  ReplaceHere } = (b :: ys)
  showReplacement (x :: zs) a b { prf  =  (ReplaceThere ys) } = x :: showReplacement zs a b

  total
  map : (a -> b)
     -> { auto prf : CanReplace xs a b ys }
     -> Union xs
     -> Union ys
  -- these two cases are the two cases I want
  map f { prf  =  ReplaceHere } (This x) = just $ f x
  map f { prf  =  (ReplaceThere prf') } (NotYet union') = NotYet $ map f union'
  map f { prf  =  (ReplaceThere z) } (This x) = just x
  -- this case should be probably impossible, if I can find a way to
  -- ensure a union never mentions the same type twice
  -- The trick is formulating an expression that is only matched when two
  -- types are distinct, ie not unifiable :/
  -- Once I've solved that problem, I can also implement operations like
  -- narrow or split
  map f { prf  =  ReplaceHere } (NotYet x) = ?only_possible_under_type_duplication_1

  total
  match : Union xs
       -> { auto prf : SupersetOf ys xs}
       -> MatchClause ys a
       -> a
  match xs clauses = match' (widen xs) clauses

  funion : MatchClause ys a
        -> { auto prf : SupersetOf ys xs }
        -> Union xs
        -> a
  funion clauses union = match union clauses

  (||) : (a -> c)
      -> (b -> c)
      -> { auto prf : SupersetOf [a, b] xs }
      -> Union xs
      -> c
  (||) f g u = funion [f, g] u



definitelyString : Union [String]
definitelyString = just "gday"

stringOrNum : Union [String, Nat]
stringOrNum = just "hello"

stringOrNum2 : Union [String, Nat]
stringOrNum2 = just (the Nat 44)

showWithType : Union [String, Nat] -> String
showWithType union = match union
  [ (\x => "A string, of " ++ x)
  , (\x => "A number, of " ++ show (x + 1) )
  ]

greaterThan3 : Nat -> Bool
greaterThan3 x = x > 3

stringOrBool : Union [String, Bool]
stringOrBool = map greaterThan3 stringOrNum

showWithType2 : Union xs -> { auto prf : SupersetOf [Nat, String] xs } -> String
showWithType2 union = match union
  [ (\x => "A number, of " ++ show (x + 1) )
  , (\x => "A string, of " ++ x)
  ]

stringy : String
stringy = showWithType stringOrNum

stringy2 : String
stringy2 = showWithType2 stringOrNum

stringy3 : String
stringy3 = showWithType2 definitelyString

showString : String -> String
showString = id

showNat : Nat -> String
showNat = show

stringy4 : String
stringy4 = funion [showString, showNat] stringOrNum

stringy5 : String
stringy5 = funion [showNat, showString] stringOrNum

stringy6 : String
stringy6 = (showString || showNat) stringOrNum

funionExample : { auto prf : SupersetOf [String, Nat] xs } -> Union xs -> String
funionExample = showString || showNat

stringy7 : String
stringy7 = funionExample stringOrNum

stringy8 : String
stringy8 = funionExample definitelyString -- have to widen, as we're back in the realms of idris' type system

stringOrNumOrBool : Union [String, Nat, Bool]
stringOrNumOrBool = widen stringOrNum

reordered : Union [Nat, String]
reordered = widen stringOrNum
