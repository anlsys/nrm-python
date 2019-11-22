-- |
-- Module      : NRM.State
-- Copyright   : (c) 2019, UChicago Argonne, LL
-- License     : BSD3
-- Maintainer  : fre@freux.fr
module NRM.State
  ( -- * Initial state
    initialState,

    -- * Creation/Registration
    createSlice,
    registerAwaiting,
    registerFailed,
    registerLaunched,
    --unRegisterDownstreamThreadClient,

    -- * Removal

    -- ** Command removal
    CmdKey (..),
    DeletionInfo (..),
    removeCmd,
  )
where

import Data.Map as DM
import LMap.Map as LM
import NRM.Node.Hwloc
import NRM.Node.Sysfs
import NRM.Node.Sysfs.Internal
import NRM.Slices.Dummy as CD
import NRM.Slices.Nodeos as CN
import NRM.Slices.Singularity as CS
import NRM.Types.Cmd
import NRM.Types.CmdID
import NRM.Types.Configuration as Cfg
import NRM.Types.Controller
import NRM.Types.Process
import NRM.Types.Slice
import NRM.Types.State
import NRM.Types.Topology
import NRM.Types.Topology.Package
import NRM.Types.Units
import NRM.Types.UpstreamClient
import Protolude

-- | Populate the initial NRMState.
initialState :: Cfg -> Time -> IO NRMState
initialState c time = do
  hwl <- getHwlocData
  let packages' =
        LM.fromList $
          (,Package {rapl = Nothing})
            <$> selectPackageIDs hwl
  packages <- raplCfg c & \case
    Nothing -> return packages'
    Just raplc -> getDefaultRAPLDirs (toS $ Cfg.raplPath raplc) <&> \case
      Just (RAPLDirs rapldirs) -> Protolude.foldl goRAPL packages' (LM.toList rapldirs)
      Nothing -> packages'
  return NRMState
    { controller = controlCfg c <&> \ccfg -> initialController time (minimumControlInterval ccfg) [],
      slices = LM.fromList [],
      pus = LM.fromList $ (,PU) <$> selectPUIDs hwl,
      cores = LM.fromList $ (,Core) <$> selectCoreIDs hwl,
      dummyRuntime =
        if dummy c
          then Just CD.emptyRuntime
          else Nothing,
      singularityRuntime =
        if singularity c
          then Just SingularityRuntime
          else Nothing,
      nodeosRuntime =
        if nodeos c
          then Just NodeosRuntime
          else Nothing,
      ..
    }
  where
    goRAPL ::
      LM.Map PackageID Package ->
      (PackageID, RAPLDir) ->
      LM.Map PackageID Package
    goRAPL m (pkgid, RAPLDir {..}) =
      LM.lookup pkgid m & \case
        Nothing -> m
        Just oldPackage -> LM.insert pkgid newPackage m
          where
            newPackage =
              oldPackage
                { rapl = Just $ Rapl
                    { frequency = hz 3,
                      raplPath = path,
                      max = maxEnergy,
                      discreteChoices = [uW 180, uW 200],
                      lastTime = Nothing
                    }
                }

-- | Removes a slice from the state
removeSlice :: SliceID -> NRMState -> (Maybe Slice, NRMState)
removeSlice sliceID st =
  ( LM.lookup sliceID (slices st),
    st {slices = LM.delete sliceID (slices st)}
  )

-- | Result annotation for command removal from the state.
data DeletionInfo
  = -- | If the slice was removed as a result of the command deletion
    SliceRemoved
  | -- | If the command was removed but the slice stayed.
    CmdRemoved

-- | Wrapper for the type of key to lookup commands on
data CmdKey
  = KCmdID CmdID
  | KProcessID ProcessID

-- | Removes a command from the state, and also removes the slice if it's
-- empty as a result.
removeCmd ::
  CmdKey ->
  NRMState ->
  Maybe (DeletionInfo, CmdID, Cmd, SliceID, NRMState)
removeCmd key st = case key of
  KCmdID cmdID ->
    DM.lookup cmdID (cmdIDMap st) <&> \(cmd, sliceID, slice) ->
      go cmdID cmd sliceID slice
  KProcessID pid ->
    DM.lookup pid (pidMap st) <&> \(cmdID, cmd, sliceID, slice) ->
      go cmdID cmd sliceID slice
  where
    go cmdID cmd sliceID slice =
      if length (cmds slice) == 1
        then (SliceRemoved, cmdID, cmd, sliceID, snd $ removeSlice sliceID st)
        else
          ( CmdRemoved,
            cmdID,
            cmd,
            sliceID,
            insertSlice
              sliceID
              (slice {cmds = LM.delete cmdID (cmds slice)})
              st
          )

-- | Registers a slice if not already tracked in the state, and returns the new state.
createSlice ::
  SliceID ->
  NRMState ->
  NRMState
createSlice sliceID st =
  case LM.lookup sliceID (slices st) of
    Nothing -> st {slices = slices'}
      where
        slices' = LM.insert sliceID emptySlice (slices st)
    Just _ -> st

-- | Registers an awaiting command in an existing slice
registerAwaiting ::
  CmdID ->
  CmdCore ->
  SliceID ->
  NRMState ->
  NRMState
registerAwaiting cmdID cmdValue sliceID st =
  st {slices = LM.update f sliceID (slices st)}
  where
    f c = Just $ c {awaiting = LM.insert cmdID cmdValue (awaiting c)}

{-{ awaiting = LM.delete cmdID (awaiting slice)-}
{-, cmds = LM.insert cmdID c (cmds slice)-}

-- | Turns an awaiting command to a launched one.
registerLaunched ::
  CmdID ->
  ProcessID ->
  NRMState ->
  Either Text (NRMState, SliceID, Maybe UpstreamClientID)
registerLaunched cmdID pid st =
  case DM.lookup cmdID (awaitingCmdIDMap st) of
    Nothing -> Left "No such awaiting command."
    Just (cmdCore, sliceID, slice) ->
      Right
        ( st
            { slices =
                LM.insert
                  sliceID
                  ( slice
                      { cmds =
                          LM.insert
                            cmdID
                            (registerPID cmdCore pid)
                            (cmds slice),
                        awaiting = LM.delete cmdID (awaiting slice)
                      }
                  )
                  (slices st)
            },
          sliceID,
          upstreamClientID cmdCore
        )

-- | Fails an awaiting command.
registerFailed ::
  CmdID ->
  NRMState ->
  Maybe (NRMState, SliceID, Slice, CmdCore)
registerFailed cmdID st =
  DM.lookup cmdID (awaitingCmdIDMap st) <&> \(cmdCore, sliceID, slice) ->
    ( st {slices = LM.update f sliceID (slices st)},
      sliceID,
      slice,
      cmdCore
    )
  where
    f c =
      if LM.null (cmds c)
        then Nothing
        else Just $ c {awaiting = LM.delete cmdID (awaiting c)}
