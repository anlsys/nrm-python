{-|
Module      : Nrm.Types.Topology.Core
Copyright   : (c) UChicago Argonne, 2019
License     : BSD3
Maintainer  : fre@freux.fr
-}
module Nrm.Types.Topology.Core
  ( Core (..)
  )
where

import Data.Aeson
import Data.MessagePack
import Protolude

-- | Record containing all information about a CPU Core.
data Core = Core
  deriving (Show, Generic, MessagePack, ToJSON, FromJSON)