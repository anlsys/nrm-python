{-# LANGUAGE DerivingVia #-}
{-# OPTIONS_GHC -fno-warn-partial-fields #-}

-- |
-- Module      : NRM.Types.Messaging.DownstreamEvent
-- Copyright   : (c) UChicago Argonne, 2019
-- License     : BSD3
-- Maintainer  : fre@freux.fr
--
-- This module implements NRM's Downstream messaging API, which is used
-- for reporting application performance and progress.
module NRM.Types.Messaging.DownstreamEvent
  ( Event (..),
    EventInfo (..),
    PhaseContext (..),
  )
where

import Data.Aeson
import Data.JSON.Schema
import Data.MessagePack
import NRM.Classes.Messaging
import NRM.Types.CmdID as CmdID
import NRM.Types.DownstreamThreadID
import NRM.Types.Units
import Protolude

-- | A downstream event is an event related to monitoring of an application. It
-- can be emitted by various means, including wrapping the application with our
-- perf-wrapper, using libnrm in an LD_PRELOAD, or directly by the application.
--
-- This is our most fragile message format, as it needs to be compatible across
-- Haskell, Python, C and Fortran. The json schema used to validate these
-- messages is generated directly from this type definition.
--
-- As the schema validator only accepts Objects at the top level, we use record
-- syntax exclusively to ensure proper schema generation and consistent
-- pack/unpack logic everywhere.
--
-- The resulting schema uses records as key:values, and value constructor names
-- as keys for embedded objects.
data Event
  = Event
      { timestamp :: Int64,
        info :: EventInfo
      }
  deriving (Generic, MessagePack, NRMMessage)
  deriving (JSONSchema, ToJSON, FromJSON) via GenericJSON Event

data EventInfo
  = -- | Performance wrapping operation count report.
    CmdPerformance
      { cmdID :: CmdID,
        perf :: Operations
      }
  | -- | Pausing performance wrapping operation reports.
    CmdPause
      { cmdID :: CmdID
      }
  | -- | Instrumented thread progress report.
    ThreadProgress
      { downstreamThreadID :: DownstreamThreadID,
        progress :: Progress
      }
  | -- | Pausing instrumented thread progress reports.
    ThreadPause
      { downstreamThreadID :: DownstreamThreadID
      }
  | -- | Preloaded MPI progress report.
    ThreadPhaseContext
      { downstreamThreadID :: DownstreamThreadID,
        phaseContext :: PhaseContext
      }
  | -- | Pausing preloaded MPI progress report.
    ThreadPhasePause
      { downstreamThreadID :: DownstreamThreadID
      }
  deriving (Generic, MessagePack)
  deriving (JSONSchema, ToJSON, FromJSON) via GenericJSON EventInfo

data PhaseContext
  = PhaseContext
      { cpu :: Int,
        aggregation :: Int,
        computetime :: Int,
        totaltime :: Int
      }
  deriving (Generic, Show, MessagePack)
  deriving (JSONSchema, ToJSON, FromJSON) via GenericJSON PhaseContext
