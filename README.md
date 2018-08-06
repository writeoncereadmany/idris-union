## Idris Unions, or: Stumbling around with Subtyping in Idris

Sum types are awesome. Sometimes I wish they worked slightly differently.
This is an adventure into trying to see if I can make them work slightly
differently, within Idris, and then see what the consequences of that are.

### What's Wrong with Sum Types?

Let's take an example of a `Shape` type, used for rendering and collision
detection in a simple 2D game engine:

```idris
data Shape : Type where
   Circle : (centre : (Double, Double)) -> (radius : Double) -> Shape
   Rectangle : (left -> Double) -> (right : Double) -> (top : Double) -> (bottom: Double) -> Shape
```
There are two frustrations I have with sum types: working with subsets, and
working with supersets.

### Working with Subsets

When writing collision-detection logic, each case of the functions quickly gets
long and convoluted. What I'd really like to do is:

```idris
circleCollides : Circle -> Circle -> Maybe Collision
circleCollides a b = ?circle_hole

rectangleCollides : Rectangle -> Rectangle -> Maybe Collision
rectangleCollides a b = ?rectangle_hole

circleRectCollides : Circle -> Rectangle -> Maybe Collision
circleRectCollides a b = ?mixed_hole
```

That allows me to separate each of them individually, opens up the opportunity
to implement them in different modules, and then I can combine them later.

Now, I can already do that. I can either pass through the arguments to each
constructor, or bung them in a tuple or some other type to make passing them
around easier.

But, as someone with an OO background, the idea `Shape` being a type with
`Circle` and `Rectangle` as subtypes is appealing. It feels like a convenient
and intuitive way to think about sum types.

### Working with Supersets

Circles and rectangles got me quite a long way, but now I want slopes in my
game, so I need a new construct: triangles. I don't expect to simply add a new
constructor to my sum type, because then that would invalidate all the functions
already written over `Shape`: they won't be able to handle the `Triangle` cases.

However, what I would like to be able to do is define a new type that's something
like:

```idris
data Shape2 : Type where
   Circle : (centre : (Double, Double)) -> (radius : Double) -> Shape2
   Rectangle : (left -> Double) -> (right : Double) -> (top : Double) -> (bottom: Double) -> Shape2
   Triangle : (points : Vect 3 (Double, Double)) -> Shape2
```

Only thing is, I'd like to be able to reuse the definitions of (and functions over)
`Circle` and `Rectangle` already defined by the `Shape` library (which I can't
modify: it's imported from a library or something).

In fact, what I really want is to be able to do something like:

```idris
-- this we can already do
data Circle = MkCircle (Double, Double) Double
data Rectangle = MkRectangle Double Double Double Double
data Triangle = MkTriangle (Vect 3 (Double, Double))

-- this bit doesn't currently work
data Shape = Circle | Rectangle
data Shape2 = Circle | Rectangle | Triangle
```

Hence: unions.

### Using unions

A union is a type paramaterised by a list of types, and stores a value of one
of those types. You can create an instance of a union containing a value using
the `just` constructor:

```idris
shape : Union [Rectangle, Circle]
shape = just $ MkCircle (0, 0) 10
```

So far, so much like sum types. But you can also upcast any union into any
supertype:

```idris
-- can upcast to any union which can hold all the possibilities
-- of the original union
shape2 : Union [Rectangle, Circle, Triangle]
shape2 = upcast shape

-- including exactly the same possibilities,
-- just in a different order.
shape3 : Union [Circle, Rectangle]
shape3 = upcast shape
```

And thus we have subtype/supertype relationships between different unions:
a `Union [a, b]` is a subtype of `Union [a]`, and a supertype of a `Union [a, b, c]`.

What do we do with unions? We can try extracting individual shapes:

```idris
maybeRect : Maybe Rectangle
maybeRect = extract shape
```

But this isn't super useful. What we really want to do is pattern match on
different shapes - and this is done via funions (functions over unions).

Where a regular function has the type `a -> b`, a funion has the type `a |-> b`,
where a can be specified either as a union or a list of types.

```idris
-- given a union type Shape...
Shape : Type
Shape = Union [Rectangle, Circle]

-- ...both of these declarations are legal and equivalent
area : [Rectangle, Circle] |-> Double
perimeter : Shape |-> Double
```

It would be nice to be able to define funions using pattern matching. I suspect
that it's possible to do so via syntax extensions and elaborator reflection, but
I'm not nearly at that level yet. What you can do, though, is build funions from
functions:

```idris
-- given functions on individual shapes...
rectArea : Rectangle -> Double
circArea : Circle -> Double

area : Shape |-> Double
area = rectArea || circArea
```

And then you can apply those funions in a similar way to regular functions:

```idris
-- both to unions, using |$
anArea : Double
anArea = area |$ shape

-- or to regular values, as long as their type is in the union, using $
anArea : Double
anArea = area $ Circle (0, 0) 10
```

You can also compose funions with functions, functions with funions, and funions
with funions the same way:

```idris
perimeter : Shape |-> Double
trianglePerimeter : Triangle -> Double

perimeter2 : [Rectangle, Circle, Triangle] |-> Double
perimeter2 = perimeter || trianglePerimeter
```

### Some Things with Unions that Don't Work

There are various formulations of unions that don't make sense, but which I
can't currently prevent:

```idris
-- this is expressible - as unions are types - but I don't really want it
-- to be, because nested unions don't really make sense. If there were a way
-- to have a Union [Shape, Triangle] automatically flatten to a
-- Union [Rectangle, Circle, Triangle], that would be super convenient
shape : Union [ Union [ Rectangle, Circle ], Triangle ]

-- this is expressible, but as all operations are keyed by type alone,
-- i don't want it to be. not being able to prove that a union is parameterised
-- by a list of distinct types makes certain useful operations impossible to
-- implement properly
stringOrError : Union [String, String]

-- there is also the concept of unions where each form is labelled,
-- so it mimics a constructor with a name rather than just a type-keyed union,
-- which is sometimes a lighter-weight approach than using fresh types.
-- Whilst this is expressible, and possible to prove we don't reuse the same
-- tag, I've not built anything around the concept yet.
stringOrError : LabelledUnion ["success" ::: String, "failure" ::: String]
```

The one I'm currently trying to resolve is the one which permits types like
`Union [String, String]`. Let's take a look at `map`:

```idris
-- given a couple of simple unions and a simple function:
aString : Union [String, Bool]
aString = just "hello"

aBool : Union [String, Bool]
aBool = just True

boolToNat : Bool -> Nat
boolToNat b = if b then 1 else 0

-- map takes a function from a to b, a union over types xs,
-- and a proof that there is an a in the union which can be replaced by a b,
-- and a list of types ys which is xs with the a replaced by a b
-- and returns a union over types ys
map : (a -> b) -> Union xs -> { auto prf : CanReplace xs a b ys } -> Union ys

-- we can map over the unions, and only modify the value if types match:

stillAString : Union [String, Nat]
stillAString = map boolToNat aString -- yields the string "hello"

nowANumber : Union [String, Nat]
nowANumber = map boolToNat aBool -- yields the number 1
```

The problem with this comes when we have types like `Union [String, String]`,
and to understand why, we need to look at the definition of `Union`:

```idris
data Union : List Type -> Type where
  This  : a -> Union (a :: rest)
  NotYet : Union xs -> Union (a :: xs)
```

So, `aString : Union [String, Bool]` specified above is represented by
`This "hello"`, whereas `aBool : Union [String, Bool]` is represented by
`NotYet (This True)`. As we add various proofs, we can add some new capabilities:

```idris
-- this proof lets us know not only that a type is within a union, but where in
-- that union it lies, by pattern matching on the proof term:
data Contains : List Type -> Type -> Type where
  Now : Contains (x :: _) x
  Later : Contains xs type -> Contains (_ :: xs) type

-- this allows us to construct unions from values in a nice clean way:
total
just : a -> { auto prf : Contains ys a } -> Union ys
just x { prf = Now } = This x
just x { prf = Later _} = NotYet $ just x

-- this proof lets us know that all of one set of types are present in the
-- other set, and where each set of corresponding types lie
data SupersetOf : (super : List Type) -> (sub : List Type) -> Type where
  ListsMatch : SupersetOf xs xs
  ExtraTypes : (x : Type) -> SupersetOf (x :: xs) xs
  Covered    : Contains super first
            -> SupersetOf super rest
            -> SupersetOf super (first :: rest)

-- which allows us to upcast unions
total
upcast : Union xs
      -> { auto prf : SupersetOf ys xs }
      -> Union ys
upcast x { prf = ListsMatch } = x
upcast x { prf = (ExtraTypes y) } = NotYet x
upcast (This x) { prf = (Covered y z) } = just x
upcast (NotYet x) { prf = (Covered y z) } = upcast x
```

But that's not sufficiently constraining, as is made obvious when we try
to implement `extract`, which turns a `Union` into a `Maybe`:

```idris
total
extract : Union xs -> { auto prf : Contains xs a } -> Maybe a
extract (This x) { prf = Now } = Just x
extract (This _) { prf = (Later _) } = Nothing
extract (NotYet _) { prf = Now } = Nothing
extract (NotYet x) { prf = (Later _) } = extract x
```

This works just fine... until you have duplicated types in the union. The
problem is that there are two ways to have a `String` in a `Union [String, String]`:
either `This "hello"` or `NotYet (This "hello")`. Both are valid constructions.

However, if you try this:

```idris
string1 : Union [String, String]
string1 = This "hello"

string2 : Union [String, String]
string2 = NotYet (This "hello")

maybeString1 : Maybe String
maybeString1 = extract string1 -- yields: Just "hello"

maybeString2 : Maybe String
maybeString2 = extract string2 -- yields: Nothing
```

This happens because we're looking up where in the union to retrieve the string
from, based on the proof that it contains a String, and the first proof found
by search is `Now`. So if it's not in the head position, it doesn't find it.

But there are multiple viable proofs available that a `String` is in the union,
and they imply different positions. Which is true, because we have a union with
multiple incidences of `String`.
