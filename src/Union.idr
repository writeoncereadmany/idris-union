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

  total
  just : a -> { auto prf : Contains ys a } -> Union ys
  just x { prf = Now } = This x
  just x { prf = Later _} = NotYet $ just x

  total
  perhaps : Union xs -> { auto prf : Contains xs a } -> Maybe a
  perhaps (This x) { prf = Now } = Just x
  perhaps (This _) { prf = (Later _) } = Nothing
  perhaps (NotYet _) { prf = Now } = Nothing
  perhaps (NotYet x) { prf = (Later _) } = perhaps x

  ||| converts an instance of a union to an instance of a "larger" union,
  ||| defined as a union which covers all the possibilities of the input union
  ||| eg, (String || Nat || Bool) is larger than (String || Nat), but
  ||| (String || Nat || Bool) is not larger than (String || Double), because the
  ||| former does not cover the Double case.
  ||| Under this definition is it legal to "widen" from (String || Nat) to
  ||| (Nat || String)
  total
  widen : Union xs
       -> { auto prf : SupersetOf ys xs }
       -> Union ys
  widen _ { prf = AnythingSuperEmpty } impossible
  widen (This x) { prf = (ThisOneCovered y z) } = just x
  widen (NotYet x) { prf = (ThisOneCovered y z) } = widen x

  -- a funion is a function on unions, built from functions on its alternative
  -- types
  data Funion : List Type -> Type -> Type where
    Nil : Funion [] a
    (::) : (x -> a) -> Funion xs a -> Funion (x :: xs) a

  total
  match' : Union xs -> Funion xs a -> a
  match' (This val) (f :: _) = f val
  match' (NotYet rest) (_ :: cases) = match' rest cases

  total
  match : Union xs
       -> { auto prf : SupersetOf ys xs}
       -> Funion ys a
       -> a
  match xs clauses = match' (widen xs) clauses



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
  -- these three cases completely describe the behaviour of map
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
