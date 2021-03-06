|Markdown version of this file: https://github.com/rpeszek/IdrisTddNotes/wiki/Part1_Sec2_2_2_the
|Idris Src: Sec2_3_3.idr

Section 2.2.2. Idris `the` function vs Haskell vs Groovy
========================================================

Idris code example
------------------  
Idris Prelude comes with a very cool `the` function reimplemented here as `the'`.
This function allows to resolve polymorphic or overloaded data constructors:
|IdrisRef: Sec2_2_2_the.idr 

idris repl:
```
*src/Part1/Sec2_2_2_the> the' Double 3
3.0 : Double
*src/Part1/Sec2_2_2_the> the' Int 3
3 : Int
*src/Part1/Sec2_2_2_the> the' Int "Test"
(input):1:1-15:When checking an application of function Part1.Sec2_2_2_the.the':
        Type mismatch between
                String (Type of "Test")
        and
                Int (Expected type)

*src/Part1/Sec2_2_2_the> the' (List Int) [1,2,3]
[1, 2, 3] : List Int
*src/Part1/Sec2_2_2_the> the' (List _) [1,2,3]
[1, 2, 3] : List Integer
*src/Part1/Sec2_2_2_the> :module Data.Vect
*src/Part1/Sec2_2_2_the *Data/Vect> the' (Vect _ _) [1,2,3]
[1, 2, 3] : Vect 3 Integer
```

Compared to Haskell
-------------------
To do something similar, Haskell would need a value level representation of types. 

> module Part1.Sec2_2_2_the where
> import Data.Proxy
>
> the :: Proxy a -> a -> a
> the _ x = x
>
> double :: Proxy Double 
> double = Proxy 
>
> int :: Proxy Int 
> int = Proxy 
>
> string :: Proxy String 
> string = Proxy 
>
> list :: Proxy a -> Proxy ([a])
> list _ = Proxy
>
> numList :: Num a => Proxy ([a])
> numList = Proxy

ghci:
```
*Part1.Sec2_2_2_the> :t the int 3
the intProxy 3 :: Int
*Part1.Sec2_2_2_the> :t the double 3
the doubleProxy 3 :: Double
*Part1.Sec2_2_2_the> :t the double "test"

<interactive>:1:17: error:
    • Couldn't match expected type ‘Double’ with actual type ‘[Char]’
    • In the second argument of ‘the’, namely ‘"test"’
      In the expression: the double "test"

*Part1.Sec2_2_2_the> :t the (list int) [1,2,3]
the (list int) [1,2,3] :: [Int]
*Part1.Sec2_2_2_the> :t the numList [1,3,4]
the numList [1,3,4] :: Num a => [a]
```
(Vector equivalent not shown because I am just lazy, besides Haskell does not have
data constructor overloading.)

This approach is clearly not as nice as Idris'. 
I had to declare helper proxies which is ugly.


Groovy
------
Any language that can express types as first class values should be able to implement
`the`.  Java comes to mind because it has the `Class<T>` type.  But it is not so easy. 
Here is Groovy console showing what happens in Groovy
```Groovy
groovy> static <T> T the(Class<T> tc, T t) { return t;}
groovy> (the(Double, 3)).getClass()

Result: class java.lang.Integer
```
This is not a fair example since Java does not really have a concept of polymorphic numeric literals.
I think, this can be blamed on Java type erasure and Groovy being weak on types.  

If this was Java code, this would not compile `the(Double.class, 3)`, 
neither would this `the(Long.class, 3)`, these would: `the(Integer.class, 3)` as well as `the(Object.class, 3)`.
Adding `@CompileStatic` annotation to Groovy code prevents compilation of the above code as well.
 
