{-|
Module      : Nrm.Types.NrmState
Copyright   : (c) UChicago Argonne, 2019
License     : BSD3
Maintainer  : fre@freux.fr
-}
module Nrm.Types.NrmState
  ( NrmState (..)
  )
where

import Data.Aeson
import Data.JSON.Schema
import Data.MessagePack
import Nrm.Containers.Dummy
import Nrm.Containers.Nodeos
import Nrm.Containers.Singularity
import Nrm.Types.Container
import Nrm.Types.Topology
import Protolude

data NrmState
  = NrmState
      { topo :: Topology
      , containers :: Map ContainerID Container
      , dummyRuntime :: Maybe DummyRuntime
      , singularityRuntime :: Maybe SingularityRuntime
      , nodeosRuntime :: Maybe NodeosRuntime
      }
  deriving (Show, Generic, MessagePack, ToJSON, FromJSON)

instance JSONSchema NrmState where

  schema _ = schema (Proxy :: Proxy Text)
