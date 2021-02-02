{-# LANGUAGE DerivingVia #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

-- |
-- Module      : NRM.Types.Cmd
-- Copyright   : (c) UChicago Argonne, 2019
-- License     : BSD3
-- Maintainer  : fre@freux.fr
module NRM.Types.Cmd
  ( Cmd (..),
    mkCmd,
    CmdCore (..),
    CmdSpec (..),
    mkCmdSpec,
    registerPID,
    TaskID (..),
    Command (..),
    Arg (..),
    Env (..),
    wrapCmd,
    addDownstreamCmdClient,
    addDownstreamThreadClient,
  )
where

import Control.Lens
import qualified Data.Aeson as A
import Data.Coerce
import Data.Generics.Labels ()
import Data.JSON.Schema
import Data.Map as M
import Data.MessagePack
import Data.String (IsString (..))
import Dhall hiding (field)
import LensMap.Core
import NRM.Classes.Messaging
import NRM.Orphans.ExitCode ()
import NRM.Orphans.UUID ()
import NRM.Types.Actuator
import NRM.Types.CmdID
import NRM.Types.DownstreamCmd
import NRM.Types.DownstreamCmdID
import NRM.Types.DownstreamThread
import NRM.Types.DownstreamThreadID
import NRM.Types.Manifest as Manifest
import qualified NRM.Types.Manifest as Ma
import NRM.Types.MemBuffer as MemBuffer
import NRM.Types.Process
import NRM.Types.Sensor
import NRM.Types.Units
import qualified NRM.Types.UpstreamClient as UC
import Protolude
import System.Process.Typed

data CmdSpec
  = CmdSpec
      { cmd :: Command,
        args :: [Arg],
        env :: Env
      }
  deriving (Show, Generic, MessagePack)
  deriving (JSONSchema, A.ToJSON, A.FromJSON) via GenericJSON CmdSpec

mkCmdSpec :: Text -> [Text] -> [(Text, Text)] -> CmdSpec
mkCmdSpec command arguments environment = CmdSpec
  { cmd = Command command,
    args = Arg <$> arguments,
    env = Env $ M.fromList environment
  }

data CmdCore
  = CmdCore
      { cmdPath :: Command,
        arguments :: [Arg],
        upstreamClientID :: Maybe UC.UpstreamClientID,
        manifest :: Manifest
      }
  deriving (Show, Generic, MessagePack)
  deriving (JSONSchema, A.ToJSON, A.FromJSON) via GenericJSON CmdCore

data Cmd
  = Cmd
      { cmdCore :: CmdCore,
        pid :: ProcessID,
        processState :: ProcessState,
        downstreamCmds :: M.Map DownstreamCmdID DownstreamCmd,
        downstreamThreads :: M.Map DownstreamThreadID DownstreamThread,
        appActuators :: Map Text Ma.AppActuator
      }
  deriving (Show, Generic, MessagePack)
  deriving (JSONSchema, A.ToJSON, A.FromJSON) via GenericJSON Cmd

mkCmd :: CmdSpec -> Manifest -> Maybe UC.UpstreamClientID -> CmdCore
mkCmd s manifest clientID = CmdCore
  { cmdPath = cmd s,
    arguments = args s,
    upstreamClientID = clientID,
    manifest = manifest
  }

registerPID :: CmdCore -> ProcessID -> Cmd
registerPID c pid = Cmd
  { cmdCore = c,
    processState = blankState,
    downstreamCmds = M.empty,
    downstreamThreads = M.empty,
    pid = pid,
    appActuators =
      fromList . fmap (\(AppActuatorKV v k) -> (k, v)) $
        c & manifest & app & Ma.actuators
  }

addDownstreamCmdClient ::
  Cmd ->
  DownstreamCmdID ->
  Maybe Cmd
addDownstreamCmdClient c downstreamCmdClientID =
  c ^. #cmdCore . #manifest . #app . #perfwrapper & \case
    Nothing -> Nothing
    (Just (Perfwrapper perfFreq perfLimit)) ->
      Just $
        c
          & #downstreamCmds
          . at downstreamCmdClientID ?~ DownstreamCmd
            { maxValue = Operations (fromInteger perfLimit),
              ratelimit = toFrequency perfFreq,
              dtLastReferenceMeasurements = MemBuffer.empty,
              lastRead = Nothing
            }

addDownstreamThreadClient ::
  Cmd ->
  DownstreamThreadID ->
  Cmd
addDownstreamThreadClient c downstreamThreadClientID =
  c & #downstreamThreads . at downstreamThreadClientID ?~ DownstreamThread
    { maxValue = 1 & progress,
      ratelimit = c ^. #cmdCore . #manifest . #app . #instrumentation
        & \case
          Just (Manifest.Instrumentation ratelimit) -> toFrequency ratelimit
          Nothing -> 1 & hz,
      dtLastReferenceMeasurements = MemBuffer.empty,
      lastRead = Nothing
    }

-- | newtype wrapper for an argument.
newtype Arg = Arg Text
  deriving (Show, Generic, MessagePack)
  deriving (JSONSchema, A.ToJSON, A.FromJSON, IsString) via Text

-- | newtype wrapper for a command name.
newtype Command = Command Text
  deriving (Show, Eq, Generic, MessagePack)
  deriving (JSONSchema, A.ToJSON, A.FromJSON, IsString, Interpret, Inject) via Text

-- | newtype wrapper for environment variables.
newtype Env = Env {fromEnv :: M.Map Text Text}
  deriving (Show, Generic, MessagePack)
  deriving (JSONSchema, A.ToJSON, A.FromJSON) via GenericJSON Env
  deriving (Semigroup, Monoid) via M.Map Text Text

-- | @wrapCmd command args (command',args')@ builds the wrapped command
-- @command@ @args@ @command'@ @args'@.
wrapCmd :: Command -> [Arg] -> (Command, [Arg]) -> (Command, [Arg])
wrapCmd c options (Command a, as) = (c, options <> [Arg a] <> as)

instance HasLensMap (CmdID, Cmd) ActiveSensorKey ActiveSensor where
  lenses (_cmdID, cmd) =
    (addPath (_2 . #downstreamCmds) <$> lenses (downstreamCmds cmd))
      <> (addPath (_2 . #downstreamThreads) <$> lenses (downstreamThreads cmd))

instance HasLensMap (CmdID, Cmd) ActuatorKey Actuator where
  lenses (_cmdID, cmd) =
    (addPath (_2 . #appActuators) <$> lenses (appActuators cmd))

instance HasLensMap (Text, AppActuator) ActuatorKey Actuator where
  lenses (t, _) =
    M.singleton
      (CmdActuatorKey t)
      ( ScopedLens
          ( _2
              . lens getter setter
          )
      )
    where
      getter :: Ma.AppActuator -> Actuator
      getter (coerce -> extraActuator) = Actuator
        { actions = Ma.actions extraActuator,
          referenceAction = Ma.referenceAction extraActuator,
          go = \value ->
            runProcess_ $
              System.Process.Typed.proc
                (toS $ Ma.actuatorBinary extraActuator)
                ((toS <$> Ma.actuatorArguments extraActuator) <> [show value])
        }
      setter :: Ma.AppActuator -> Actuator -> Ma.AppActuator
      setter oldExtraActuator actuator = coerce $
        oldExtraActuator &~ do
          #referenceAction .= NRM.Types.Actuator.referenceAction actuator
          #actions .= NRM.Types.Actuator.actions actuator
