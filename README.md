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
