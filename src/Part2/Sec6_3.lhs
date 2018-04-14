|Markdown version of this file: https://github.com/rpeszek/IdrisTddNotes/wiki/idrVsHs_Part2_Sec6_3
|Idris Src: Sec6_3b.idr
|Idris Src: Sec6_3.idr

Section 6.3. data store with adjustable schema example vs Haskell
=================================================================
Code example for data store with a type safe schema.  
_I think the best way to read this is to open two windows and look at 
Idris and Haskell code side-by-side._

Goal:
```
shell$ ./IdrisTddNotes
Command: schema Int String
OK
Command: add 99 "Red balloons"
ID 0
Command: add 76 "Trombones"
ID 1
Command: get 1
76, "Trombones"
Command: quit
shell$ 
```
I have implemented it here 
[/src/Part2/Sec6_3.idr](../blob/master/src/Part2/Sec6_3.lhs)
following the example from the book.  
Large part of this code is devoted to parsing user input and that code is rather imperative
and not exciting. I wanted to see how that would look like using a more functional parsing approach.  

__Monadic MiniParser__ I want to avoid dependency on external libraries (Idris still does not have a package manager). 
I also wanted to learn Idris better.  So I wrote a very primitive parser 
[/src/Util/MiniParser.idr](../blob/master/src/Util/MiniParser.idr) myself.
Such parser code likes to use recursion and that results in reduced totality claims that I can make.  
(Maybe I can provide proofs of totality - but I currently do not know how.)

Here is the replaced version, I will use it as the starting point for my Haskell code.
 
|IdrisRef: Sec6_3b.idr 

This demonstrates type safety around adding and retrieving records (in idris repl):

<img src="https://github.com/rpeszek/IdrisTddNotes/blob/master/image/Part2/Sec6_3_idrisrepl.png" alt="/image/Part2/Sec6_2_2.png" width="900">


Compared to Haskell
-------------------
This version was codes 'by-hand'. Using `singletons` will should make it much simpler.
(`singletons` version is work in progress) 
[/src/Part2/Sec6_3sing.hs](../blob/master/src/Part2/Sec6_3sing.hs)  

*  I am using `attoparsec` just to play with it, I may created a version using the more commonly used `parsec` library
in the future. Obviously, the existence of super nice parser (and other) libraries is a big plus for Haskell.
*  GHC.TypeLits based vectors are hard to work with and I moved to using my own implementation `Util.NonLitsNatAndVector`
*  Implementing polymorphic setSchema while keeping addSchema and getEntry type safe was hard
*  Tuples in Haskell are yucky
*  It is hard to implement locally scoped dependently typed helper functions in Haskell
*  Idris type dependent records are nice, useful, and reduce boilerplate
*  Name overloading in Idris is nice!
*  Seems like Idris is more flexible with operator names like `.+.`
   
> {-# LANGUAGE 
>    StandaloneDeriving
>    , GADTs
>    , KindSignatures
>    , DataKinds
>    , TypeOperators 
>    , TypeFamilies
>    , ScopedTypeVariables
>    , OverloadedStrings
>    , AllowAmbiguousTypes -- prevents "‘SchemaType’ is a type function, and may not be injective" error
>
>    -- rest is needed for HList appending
>    , PolyKinds
>    , MultiParamTypeClasses
>    , FlexibleInstances
>    , UndecidableInstances
> #-}
>
> {-# OPTIONS_GHC -fwarn-incomplete-patterns #-}
>
> module Part2.Sec6_3 where
> import Control.Applicative ((<|>))
> import Data.Monoid ((<>))
> import Data.Kind (Type)
> -- I struggled with "Couldn't match type ‘n’ with ‘(n + 1) - 1’" in addToStore implementation
> -- when trying to use TypeLits based Vect
> -- import GHC.TypeLits
> -- import Part2.Sec6_2_1 (Vect(..), SNat(..), UnknownNat(..), sNatToUnknownNat, unknownNatToInteger)
> import Util.NonLitsNatAndVector (Vect(..), Nat(..), SNat(..), UnknownNat(..), sNatToUnknownNat, unknownNatToInteger)
> import Data.ByteString (ByteString)
> import qualified Data.ByteString as B
> import Data.ByteString.Char8 ()
> import qualified Data.ByteString.Char8 as CH8
> import Data.Attoparsec.ByteString hiding (takeTill)
> import Data.Attoparsec.ByteString.Char8 
> import Prelude hiding (getLine, putStrLn)
>
> {-| Almost the same as Idris version
>    I had hard time using .+. so I changed it.
>    TODO learn why
> -}
> data Schema = SString
>             | SInt
>             | (:+) Schema Schema
>              deriving Show
> infixr 5 :+
>
> {-| Type level representation of Schema (reflexion).
>  This adds quite a bit of boilerplate 
> -}
> data SSchema (sch :: Schema) where
>   SSString :: SSchema 'SString 
>   SSInt :: SSchema 'SInt
>   SSCons :: SSchema s1 -> SSchema s2 -> SSchema (s1 :+ s2) 
>
> {-| type family instead of type-level function used in Idris, but almost identical -}
> type family SchemaType  (sch :: Schema) :: Type where
>  SchemaType 'SString = ByteString
>  SchemaType 'SInt = Int
>  SchemaType (x :+ y) = (SchemaType x, SchemaType y)
>
> testST :: SchemaType ('SInt :+ 'SString :+ 'SInt)
> testST = undefined

ghci:
```
*Part2.Sec6_3> :t testST
testST :: (Int, (ByteString, Int))
```
Unfortunately, tuples are not simply right associative in Haskell 
and `(a,b,c)` is not the same as `(a,(b,c))`.  
Haskell tuples are rather crazy: 
https://hackage.haskell.org/package/ghc-prim-0.4.0.0/docs/GHC-Tuple.html

I would prefer to replace tuples with something better and HList comes to mind.

> data HList (as :: [Type]) where
>   HNil :: HList '[]
>   (::-) :: a -> HList as -> HList (a ': as)
>
> infixr 5 ::-

ghci:
```
*Part2.Sec6_3> :t (CH8.pack "hi") ::- (2::Int) ::- HNil
(CH8.pack "hi") ::- (2::Int) ::- HNil :: HList '[ByteString, Int]
```
Using HList SchemaType mapping becomes complicated. I need to be able to abstract over single 
types and lists of types (`Type` and `[Type]` are different).  
The following code is copied from the `HList` package   
https://hackage.haskell.org/package/HList-0.4.1.0 

> type family HAppendListR (l1 :: [k]) (l2 :: [k]) :: [k]
> type instance HAppendListR '[] l = l
> type instance HAppendListR (e ': l) l' = e ': HAppendListR l l'
>
> class HAppendList l1 l2 where
>  hAppendList :: HList l1 -> HList l2 -> HList (HAppendListR l1 l2)
> instance HAppendList '[] l2 where
>   hAppendList HNil l = l
> instance HAppendList l l' => HAppendList (x ': l) l' where
>   hAppendList (x ::- l) l' = x ::- (hAppendList l l')
>
> type family SchemaTypeList  (sch :: Schema) :: [Type] where
>   SchemaTypeList 'SString = '[ByteString]
>   SchemaTypeList 'SInt = '[Int] 
>   SchemaTypeList (x :+ y) = HAppendListR (SchemaTypeList x) (SchemaTypeList y)
>
> type family SchemaTypeHList  (sch :: Schema) :: Type where
>   SchemaTypeHList sch = HList (SchemaTypeList sch)
>
> testSTList :: SchemaTypeHList ('SInt :+ 'SString :+ 'SInt)
> testSTList = undefined

ghci:
```
*Part2.Sec6_3> :t testSTList
testSTList :: HList '[Int, ByteString, Int]
```
This is great, it works!, but feels like swimming upstream (checkout my list of LANGUAGE extensions). 
__I will continue__ with nested tuples.

> data Command (sch :: Schema) where
>            -- SetSchema is polymorphic in schema type
>            SetSchema :: SSchema asch -> Command sch
>            Add :: SchemaType sch -> Command sch
>            Get :: Int -> Command sch
>            Quit :: Command sch

I need to create an equivalent for `SetSchema` data constructor from Idris.   
idris repl:
```
*Part2/Sec6_3b> :t SetSchema
SetSchema : Schema -> Command schema
```
In Haskell, SetSchema is also polymorphic in `sch`, I should be able to define 
`schemaToSchemaCmd :: Schema -> Command sch` that uses it.

I was not able to think of a much simpler way of doing it than the following.
The issue is how to map `:+` constructor. I want to use recursion to do that and 
for this it is helpful to have unique constructor. Hence helper type `AnySchema`.
A possible simplification would be to define DSL Command type as a coproduct of DSL 
instructions (`SetSchema`, `Add`, `Get`, and `Quit`).  This should simplify recursive 
definition for `SetSchema`, potentially removing the need for a helper type but it would
deviate from Idris version I am trying to mimic.  

> {-| this is the existential type that could also be named SomeSchema.
>    It is the reification type.
> -}
> data AnySchema (sch :: Schema) where
>            MkAnySchema :: SSchema asch -> AnySchema sch
>
> toAnySchema :: Schema -> AnySchema sch
> toAnySchema SString = MkAnySchema SSString
> toAnySchema SInt = MkAnySchema SSInt
> toAnySchema (s1 :+ s2) = 
>        case toAnySchema s1 of
>          MkAnySchema s1' -> case toAnySchema s2 of 
>            MkAnySchema s2' ->
>              MkAnySchema (s1' `SSCons` s2') 
> 
> toSetSchemaCommand :: AnySchema sch -> Command sch
> toSetSchemaCommand (MkAnySchema x) = SetSchema x
>
> schemaToSchemaCmd :: Schema -> Command sch 
> schemaToSchemaCmd  = toSetSchemaCommand . toAnySchema

For datastore I still need to use a GADT (regular records will not do).
Also, Idris can simply use `schema store` on the typelevel so there is 
no need to parametrize DataStore with schema in Idris. In haskell I need that
to implement `addToStore`

> data DataStore (sch :: Schema) where
>    MkDataStore :: SSchema sc -> SNat n -> Vect n (SchemaType sc) -> DataStore sc
>
> {- helper methods used with DataStore -}
> 
> {-| This one maps to just schema in Idris which is overloaded name -}
> getSchema :: DataStore sch -> SSchema sch 
> getSchema (MkDataStore sch _ _) = sch
>
> {-| it would be more elegant to return something like UnknownNat, but Int will do -}
> size :: DataStore sch -> UnknownNat
> size (MkDataStore _ size _) = sNatToUnknownNat size
>
> display :: SSchema sch -> SchemaType sch -> ByteString
> display SSString item = item
> display SSInt item =  CH8.pack . show $ item
> display (SSCons sch1 sch2) (item1, item2) = display sch1 item1 <> " " <> display sch2 item2 

Instead of implementing Fin type (which I plan to do later) getEntry
is coded directly in not as type safe way:

> {-| getvelem is total because at some point vector will reduce to Nil 
>     returning Just value only if 0 index is encountered during recursion
> -}
> getvelem :: Int -> Vect n a -> Maybe a
> getvelem _ Nil = Nothing
> getvelem 0 (x ::: _) = Just x
> getvelem i (_ ::: xs) = getvelem (i - 1) xs
>
> retrieve :: Int -> DataStore sch -> Maybe (SchemaType sch)
> retrieve pos (MkDataStore _ _ vect) = getvelem pos vect
> 
> getEntry :: Int -> DataStore sch -> Maybe ByteString 
> getEntry pos store@(MkDataStore ss _ vect)  = 
>        if pos < 0
>        then Just ("Out of range") 
>        else case retrieve pos store of
>           Nothing -> Just "Out of range"
>           Just rec  -> Just (display ss rec)
>
> setSchema :: DataStore asch -> SSchema sch -> Maybe (DataStore sch)
> setSchema store schema = case size store of
>           UZ -> Just (MkDataStore schema SZ Nil)
>           _  -> Nothing 

One thing that Idris makes easier is defining of locally scoped `where` functions.
To make these work in Haskell I cannot just use dependently typed variables that are
already in scope. 

> {-| This one is also more complicated compared to Idris -}
> addToStore :: DataStore sc -> SchemaType sc -> DataStore sc
> addToStore (MkDataStore schema size elems) newitem
>            = MkDataStore schema (SS size) (addToData schema newitem size elems)
>    where
>      -- I had to bring type level schema and size evidence to make it work
>      -- Couldn't match type ‘n’ with ‘(n + 1) - 1’ when using Part2.Sec6_2_1 definitions
>      addToData ::  SSchema sc -> SchemaType sc -> SNat oldsize -> Vect oldsize (SchemaType sc) -> Vect ('S oldsize) (SchemaType sc)
>      addToData schema newitem SZ Nil = newitem ::: Nil
>      addToData schema newitem (SS n) (item ::: items) = item ::: addToData schema newitem n items


__Parsers__

Added these to mimic my primitive Idris parser based on attoparsec

> optional :: Parser a -> Parser (Maybe a)
> optional p = option Nothing (Just <$> p)
>
> spaces :: Parser [Char]
> spaces = many1 space
>
> between :: Parser a -> Parser b -> Parser ByteString
> between from to = do
>         fx <- from
>         chars <- manyTill anyChar to
>         return $ CH8.pack chars
>
> parseAll :: Parser a -> ByteString -> Either String a
> parseAll p str = parseOnly (p <* endOfInput) str

The following parsers map directly to Idris code

> sstring :: Parser Schema 
> sstring =  string "String" *> pure SString
>
> sint :: Parser Schema
> sint = string "Int" *> pure SInt
>
> scolumn :: Parser Schema
> scolumn = sstring <|> sint
>
> schemaBody :: Parser Schema 
> schemaBody = do  
>      col  <- scolumn
>      _    <- optional spaces
>      rest <- optional schemaBody
>      case rest of
>         Nothing ->  pure col
>         Just rest -> pure (col :+ rest)
>
> schema :: Parser Schema 
> schema = string "schema" *> spaces *> schemaBody
>
> schemaTypeBody :: SSchema sch -> Parser (SchemaType sch)
> schemaTypeBody SSString = between (char '"') (char '"')
> schemaTypeBody SSInt = decimal
> schemaTypeBody (schemal `SSCons` schemar) = do
>                 parsed1 <- schemaTypeBody schemal
>                 _    <- spaces
>                 parsed2 <- schemaTypeBody schemar
>                 return (parsed1, parsed2)
>
> schemaType :: SSchema sch -> Parser (SchemaType sch)
> schemaType sch = string "add" *> spaces *> schemaTypeBody sch

And the main adjustment in the `command` parser is the use of the polymorphic
`schemaToSchemaCmd` function:

> command :: SSchema sc -> Parser (Command sc)
> command sc = schemaToSchemaCmd <$> schema <|>
>              (string "quit" *> pure Quit) <|>
>              (string "get") *> spaces *> (Get <$> decimal) <|>
>              (Add <$> schemaType sc)

In Idris, DataStore is just a Type, to keep things strongly typed I had enhanced
it to accept schema as type variable.  I still need to have just a plain type to 
implement `processInput`.

> data UnknownDataStore where
>   MkUnknownStore :: DataStore sc -> UnknownDataStore
>
> processInput :: UnknownDataStore -> ByteString -> Maybe (ByteString, UnknownDataStore)
> processInput (MkUnknownStore store) input 
>           =  let ss = getSchema store
>              in case parseAll (command ss) input of
>                  Left msg -> Just ("Invalid command: " <> CH8.pack msg, MkUnknownStore store)
>                  Right (Add item) ->
>                     Just ("ID " <> CH8.pack ( show (unknownNatToInteger . size $ store)), MkUnknownStore $ addToStore store item)
>                  Right (Get pos) -> (\s -> (s, MkUnknownStore store)) <$> getEntry pos store
>                  Right (SetSchema schema') -> case setSchema store schema' of
>                         Nothing -> Just ("Can't update schema", MkUnknownStore store)
>                         Just store' -> Just ("OK", MkUnknownStore store')
>                  Right Quit -> Nothing
> 

Cloned from Idris `replWith` (it is somewhat less flexible, prints and reads whole lines): 

> replWith :: a -> ByteString -> (a -> ByteString -> Maybe (ByteString, a)) -> IO ()
> replWith acc prompt onInput = do 
>                 CH8.putStr prompt
>                 x <- B.getLine
>                 case onInput acc x of
>                      Just (out, acc') -> do CH8.putStrLn out
>                                             replWith acc' prompt onInput
>                      Nothing -> pure ()
>
> initDs :: DataStore 'SString
> initDs = MkDataStore SSString SZ Nil
>
> testDs :: DataStore ('SInt :+ 'SString)
> testDs = MkDataStore (SSInt `SSCons` SSString) SZ Nil
>
> sec6_3 :: IO ()
> sec6_3 = replWith (MkUnknownStore initDs) "Command: " processInput

ghci
```
*Part2.Sec6_3> sec6_3
Command: schema Int String
OK
Command: add 99 "Red balloons"
ID 0
Command: add 76 "Trombones"
ID 1
Command: get 1
76 Trombones
Command: quit
*Part2.Sec6_3> 
```

Conclusions
-----------
Idris is nice!