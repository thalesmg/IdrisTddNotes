|Markdown version of this file: https://github.com/rpeszek/IdrisTddNotes/wiki/Part1_Sec1_4_5
|Idris Src: Sec1_4_5.idr

Section 1.4.5. Simple Idris example vs Haskell
==============================================

Idris code example
------------------
|IdrisRef: Sec1_4_5.idr 

StringOrInt example is used later in Section 6.1.3 to demonstrate type holes
in type signatures. Type holes are amazing but unfortunately sometimes do not work. 
This does not compile (note full implementation in place and holes in type signature -
my guess undecidable in dependently typed language):

```
-- this does not work! (6.1.3)
valToString : (isInt : Bool) -> (case isInt of
                                      False => ?argType_1
                                      True => ?argType_2) -> String
valToString False y = trim y
valToString True y = cast y
```


idris repl
```
   |
41 | valToString False y = trim y
   |                       ~~~~~~
When checking right hand side of valToString with expected type
        String

When checking an application of function Prelude.Strings.trim:
        Type mismatch between
                case False of
                  False => ?argType_1
                  True => ?argType_2 (Type of y)
        and
                String (Expected type)
        
        Specifically:
                Type mismatch between
                        ?argType_1
                and
                        String
```

Compared to Haskell
-------------------

> {-# LANGUAGE TypeFamilies
>  , DataKinds 
>  , KindSignatures 
>  , GADTs 
>  , ScopedTypeVariables
> #-}
> {-# OPTIONS_GHC -fwarn-incomplete-patterns #-}
> {-# OPTIONS_GHC -fwarn-unused-imports #-}

> module Part1.Sec1_4_5 where
> import Data.Kind (Type)

Naive solution that tries to mimic Idris code is not type safe

> showInt :: Int -> String
> showInt = show
> 
> data StringOrInt1 = MkStr1 String | MkInt1 Int 
> 
> getStringOrInt1 :: Bool -> StringOrInt1
> getStringOrInt1 x = case x of
>           True -> MkInt1 10
>           False -> MkStr1 "Hello"
> 
> {-| Problem this compiles as well -}
> getStringOrInt1' :: Bool -> StringOrInt1
> getStringOrInt1' x = case x of
>            True -> MkStr1 "Hello"
>            False -> MkInt1 10
> 
> {-| Problem this does not depend on first param -}
> valToString1 :: Bool -> StringOrInt1 -> String
> valToString1 _ val = case val of
>          MkInt1 x -> showInt x
>          MkStr1 x -> x


Using Type Families, GADTs, and DataKinds provides good (almost equivalent with some differences) type safety but
the boiler plate is significant and conceptual difficulty is higher.
It also has other limitations explained below.

> data StringOrInt2 a where
>     MkStr2 :: String -> StringOrInt2 String
>     MkInt2 :: Int -> StringOrInt2 Int
> 
> extractStr :: StringOrInt2 String -> String
> extractStr (MkStr2 s) = s
> 
> extractInt :: StringOrInt2 Int -> Int 
> extractInt (MkInt2 i) = i

The above GADT solution is nice but it is different.  It is not a clean type mapping
to `String` or `Int` rather is involves parametrized type `StringOrInt2 a`

Type family solution is closer to Idris but is also not equivalent. Type Families
are not first class, for example I cannot define expressions like 
`data MyGadt StrOrIntF where` because type family needs to be fully applied in type 
signatures.
 
> type family StrOrIntF (x::Bool) :: Type where
>    StrOrIntF 'True = Int 
>    StrOrIntF 'False = String 
> 
> data SBool (b :: Bool) where 
>    STrue :: SBool True
>    SFalse :: SBool False
> 
> getStringOrInt2 :: forall (a :: Bool). SBool a -> StringOrInt2 (StrOrIntF a)
> getStringOrInt2 x = case x of
>           STrue -> MkInt2 10
>           SFalse -> MkStr2 "Hello"
> 
> {-! This compiles with warn-incomplete-patterns, sweet!!! -}
> valToString2 :: forall (a :: Bool). SBool a -> StringOrInt2 (StrOrIntF a) -> String
> valToString2 x val = case x of
>           STrue -> showInt $ extractInt val
>           SFalse -> extractStr val
> 
> {-| However this still compiles which seems bad but see testGood below -}
> valToString2' :: forall (a :: Bool). SBool a -> StringOrInt2 (StrOrIntF a) -> String
> valToString2' _ val = case val of
>          MkInt2 x -> showInt x
>          MkStr2 x -> x
> 
> testGood = valToString2' SFalse (MkStr2 "Test")

This no longer builds. Good!:
```
getStringOrInt2' :: forall (a :: Bool). SBool a -> StringOrInt2 (StrOrIntF a)
getStringOrInt2' x = case x of
          STrue -> MkStr2 "Hello"
          SFalse -> MkInt2 10
```
Neither does this:
```
testBad = valToString2' STrue (MkStr2 "Test")
```


Conclusions
-----------
Idris dependent types are NICE!!! 
Compared to Haskell, this type of code is much simpler and has much less boiler plate.
