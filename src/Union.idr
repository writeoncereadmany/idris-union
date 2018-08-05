module Union

%access public export

infixl 0 $
infixl 0 >>>
infixl 5 |->

namespace Function
  ($) : (a -> b) -> a -> b
  ($) f a = f a

  (>>>) : a -> (a -> b) -> b
  (>>>) x f = f x

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

  data IsUnion : Type -> List Type -> Type where
    MkIsUnion : IsUnion (Union xs) xs

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

namespace Funion
  data (|->) : List Type -> Type -> Type where
    Nil : [] |-> a
    (::) : (x -> a) -> (xs |-> a) -> (x :: xs) |-> a

  total
  match' : xs |-> a -> Union xs -> a
  match' (f :: _) (This val) = f val
  match' (_ :: cases) (NotYet rest) = match' cases rest

  total
  match : ys |-> a
       -> Union xs
       -> { auto prf : SupersetOf ys xs}
       -> a
  match clauses xs = match' clauses (widen xs)

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
  map f { prf  =  ReplaceHere } (This x) = just (f x)
  map f { prf  =  (ReplaceThere prf') } (NotYet union') = NotYet (map f union')
  map f { prf  =  (ReplaceThere z) } (This x) = just x
  -- this case should be probably impossible, if I can find a way to
  -- ensure a union never mentions the same type twice
  -- The trick is formulating an expression that is only matched when two
  -- types are distinct, ie not unifiable :/
  -- Once I've solved that problem, I can also implement operations like
  -- narrow or split
  map f { prf  =  ReplaceHere } (NotYet x) = ?only_possible_under_type_duplication_1

  infixl 0 |$|
  (|$|) : (xs |-> t) -> Union ys -> { auto prf: SupersetOf xs ys } -> t
  (|$|) f u = match f u

  ($) : (xs |-> t) -> a -> { auto prf: SupersetOf xs [a] } -> t
  ($) f { prf } v = match f (just v)

  infixl 0 |>>
  (|>>) : Union ys -> (xs |-> t) -> { auto prf : SupersetOf xs ys } -> t
  u |>> f = f |$| u

  (>>>) :a -> (xs |-> t) -> { auto prf: SupersetOf xs [a] } -> t
  a >>> f = f |$| (just a)

namespace FunionShorthand
  (|->) : (a : Type) -> Type -> { auto prf : IsUnion a xs } -> Type
  (|->) a b { xs } = xs |-> b


namespace FunctionFunction
  (||) : (a -> c) -> (b -> c) -> [a, b] |-> c
  (||) f g = [f, g]

namespace FunctionFunion
  (||) : (a -> c) -> (b |-> c) -> (a :: b) |-> c
  (||) f g = f :: g

namespace FunionFunction
  (||) : (a |-> c) -> (b -> c) -> (a ++ [b]) |-> c
  (||) [] f = [f]
  (||) (f :: fs) g = f :: (fs || g)

namespace FunionFunion
  (||) : (a |-> c) -> (b |-> c) -> (a ++ b) |->  c
  (||) [] g = g
  (||) (f :: fs) g = f :: (fs || g)
