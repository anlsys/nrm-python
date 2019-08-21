{-# LANGUAGE ScopedTypeVariables #-}

{-|
Module      : Nrm.Classes.Messaging
Copyright   : (c) UChicago Argonne, 2019
License     : BSD3
Maintainer  : fre@freux.fr
-}
module Nrm.Classes.Messaging
  ( NrmMessage (..)
  )
where

import qualified Data.Aeson as A
import qualified Data.Aeson.Types as AT (parseMaybe)
import qualified Data.JSON.Schema.Generic as SG
import Data.JSON.Schema.Types (Schema)
import Generics.Deriving.ConNames (ConNames)
import Data.Aeson.Encode.Pretty as AP (encodePretty)
import qualified Generics.Generic.Aeson as AG
import Generics.Generic.IsEnum (GIsEnum)
import Protolude

class
  (Generic b, SG.GJSONSchema (Rep b), AG.GfromJson (Rep b), AG.GtoJson (Rep b), GIsEnum (Rep b), ConNames (Rep b))
  => NrmMessage a b
    | a -> b where

  {-# MINIMAL fromJ, toJ #-}

  fromJ :: b -> a

  toJ :: a -> b

  encodePretty :: a -> ByteString
  encodePretty = toS . AP.encodePretty . AG.gtoJson . toJ

  encode :: a -> ByteString
  encode = toS . A.encode . AG.gtoJson . toJ

  decode :: ByteString -> Maybe a
  decode = fmap fromJ . AT.parseMaybe AG.gparseJson <=< A.decodeStrict

  decodeT :: Text -> Maybe a
  decodeT = fmap fromJ . AT.parseMaybe AG.gparseJson <=< A.decodeStrict . toS

  encodeT :: a -> Text
  encodeT = toS . A.encode . AG.gtoJson . toJ

  schema :: Proxy a -> Schema
  schema (Proxy :: Proxy a) = SG.gSchema (Proxy :: Proxy b)
