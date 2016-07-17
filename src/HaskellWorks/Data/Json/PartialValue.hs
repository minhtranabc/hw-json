{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE InstanceSigs          #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TupleSections         #-}

module HaskellWorks.Data.Json.PartialValue
  ( JsonPartialValue(..)
  , JsonPartialValueAt(..)
  ) where

import           Control.Arrow
import qualified Data.Attoparsec.ByteString.Char8             as ABC
import qualified Data.ByteString                              as BS
import           HaskellWorks.Data.Json.Succinct.PartialIndex
import           HaskellWorks.Data.Json.Value.Internal

data JsonPartialValue
  = JsonPartialString String
  | JsonPartialNumber Double
  | JsonPartialObject [(String, JsonPartialValue)]
  | JsonPartialArray [JsonPartialValue]
  | JsonPartialBool Bool
  | JsonPartialNull
  | JsonPartialError String
  deriving (Eq, Show)

class JsonPartialValueAt a where
  jsonPartialJsonValueAt :: a -> JsonPartialValue

asString :: JsonPartialValue -> String
asString pjv = case pjv of
  JsonPartialString s -> s
  _                   -> ""

instance JsonPartialValueAt JsonPartialIndex where
  jsonPartialJsonValueAt i = case i of
    JsonPartialIndexString s  -> case ABC.parse parseJsonString s of
      ABC.Fail    {}          -> JsonPartialError ("Invalid string: '" ++ show (BS.take 20 s) ++ "...'")
      ABC.Partial _           -> JsonPartialError "Unexpected end of string"
      ABC.Done    _ r         -> JsonPartialString r
    JsonPartialIndexNumber s  -> case ABC.parse ABC.rational s of
      ABC.Fail    {}    -> JsonPartialError ("Invalid number: '" ++ show (BS.take 20 s) ++ "...'")
      ABC.Partial f     -> case f " " of
        ABC.Fail    {}    -> JsonPartialError ("Invalid number: '" ++ show (BS.take 20 s) ++ "...'")
        ABC.Partial _     -> JsonPartialError "Unexpected end of number"
        ABC.Done    _ r   -> JsonPartialNumber r
      ABC.Done    _ r   -> JsonPartialNumber r
    JsonPartialIndexObject  fs -> JsonPartialObject (map ((asString . parseString) *** jsonPartialJsonValueAt) fs)
    JsonPartialIndexArray   es -> JsonPartialArray (map jsonPartialJsonValueAt es)
    JsonPartialIndexBool    v  -> JsonPartialBool v
    JsonPartialIndexNull       -> JsonPartialNull
    JsonPartialIndexError s    -> JsonPartialError s
    where parseString bs = case ABC.parse parseJsonString bs of
            ABC.Fail    {}  -> JsonPartialError ("Invalid field: '" ++ show (BS.take 20 bs) ++ "...'")
            ABC.Partial _   -> JsonPartialError "Unexpected end of field"
            ABC.Done    _ s -> JsonPartialString s
