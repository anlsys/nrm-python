{-|
Module      : Nrm.Types.Topology
Copyright   : (c) UChicago Argonne, 2019
License     : BSD3
Maintainer  : fre@freux.fr
-}
module Nrm.Types.Topology
  ( CoreID (..)
  , Core (..)
  , PUID (..)
  , PU (..)
  , PackageID (..)
  , Package (..)
  , Topology (..)
  , IdFromString (..)
  , ToHwlocType (..)
  )
where

import Data.Aeson
import Data.Either
import qualified Data.Map as DM
import Data.MessagePack
import Protolude
import Refined
import Refined.Orphan.Aeson ()
import Prelude (String, fail)

-- | Nnm's internal statically typed topology representation
data Topology
  = Topology
      { puIDs :: DM.Map PUID PU
      , coreIDs :: DM.Map CoreID Core
      , packageIDs :: DM.Map PackageID Package
      }
  deriving (Show, Generic, MessagePack, ToJSON, FromJSON)

-- | A Package OS identifier.
newtype PackageID = PackageID (Refined NonNegative Int)
  deriving (Eq, Ord, Show, Generic, FromJSONKey, ToJSONKey, ToJSON, FromJSON)

-- | Record containing all information about a CPU Package.
data Package = Package
  deriving (Show, Generic, MessagePack, ToJSON, FromJSON)

-- | A CPU Core OS identifier.
newtype CoreID = CoreID (Refined Positive Int)
  deriving (Show, Eq, Ord, Generic, ToJSONKey, ToJSON, FromJSON, FromJSONKey)

-- | Record containing all information about a CPU Core.
data Core = Core
  deriving (Show, Generic, MessagePack, ToJSON, FromJSON)

-- | A Processing Unit OS identifier.
newtype PUID = PUID (Refined NonNegative Int)
  deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON, ToJSONKey, FromJSONKey)

-- | Record containing all information about a processing unit.
data PU = PU
  deriving (Show, Generic, MessagePack, ToJSON, FromJSON)

-- | reading from hwloc XML data
class IdFromString a where

  idFromString :: String -> Maybe a

-- | translating to hwloc XML "type" field.
class ToHwlocType a where

  getType :: Proxy a -> Text

instance IdFromString CoreID where

  idFromString s = CoreID <$> readMaybe ("Refined " <> s)

instance IdFromString PUID where

  idFromString s = PUID <$> readMaybe ("Refined " <> s)

instance IdFromString PackageID where

  idFromString s = PackageID <$> readMaybe ("Refined " <> s)

instance ToHwlocType PUID where

  getType _ = "PU"

instance ToHwlocType CoreID where

  getType _ = "Core"

instance ToHwlocType PackageID where

  getType _ = "Package"

-- MessagePack instances
instance MessagePack PackageID where

  toObject (PackageID x) = toObject (unrefine x)

  fromObject x =
    (fromObject x <&> refine) >>= \case
      Right r -> return $ PackageID r
      Left _ -> fail "Couldn't refine PackageID during MsgPack conversion"

instance MessagePack PUID where

  toObject (PUID x) = toObject (unrefine x)

  fromObject x =
    (fromObject x <&> refine) >>= \case
      Right r -> return $ PUID r
      Left _ -> fail "Couldn't refine PackageID during MsgPack conversion"

instance MessagePack CoreID where

  toObject (CoreID x) = toObject (unrefine x)

  fromObject x =
    (fromObject x <&> refine) >>= \case
      Right r -> return $ CoreID r
      Left _ -> fail "Couldn't refine PackageID during MsgPack conversion"
