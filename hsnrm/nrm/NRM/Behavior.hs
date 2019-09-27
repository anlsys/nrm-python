{-|
Module      : NRM.Behavior
Copyright   : (c) UChicago Argonne, 2019
License     : BSD3
Maintainer  : fre@freux.fr
-}
module NRM.Behavior
  ( -- * NRM's core logic.
    behavior
  , -- * The Event specification
    NRMEvent (..)
  , -- * The Behavior specification
    Behavior (..)
  , CmdStatus (..)
  )
where

import qualified CPD.Core as CPD
import qualified CPD.Utils as CPD
import qualified CPD.Values as CPD
import Control.Lens hiding (to)
import Data.Generics.Product
import Data.MessagePack
import qualified NRM.CPD as NRMCPD
import qualified NRM.Classes.Messaging as M
import NRM.Sensors
import NRM.State
import NRM.Types.Cmd
import qualified NRM.Types.Configuration as Cfg
import qualified NRM.Types.DownstreamCmd as DC
import NRM.Types.LMap as LM
import qualified NRM.Types.Manifest as Manifest
import qualified NRM.Types.Messaging.DownstreamEvent as DEvent
import qualified NRM.Types.Messaging.UpstreamPub as UPub
import qualified NRM.Types.Messaging.UpstreamRep as URep
import qualified NRM.Types.Messaging.UpstreamReq as UReq
import NRM.Types.Process as Process
import qualified NRM.Types.Sensor as Sensor
import qualified NRM.Types.Slice as Ct
import NRM.Types.State
import qualified NRM.Types.Units as U
import qualified NRM.Types.UpstreamClient as UC
import Protolude

-- | The Behavior datatype describes an event from the runtime on which to react.
data NRMEvent
  = -- | A Request was received on the Upstream API.
    Req UC.UpstreamClientID UReq.Req
  | -- | Registering a child process.
    RegisterCmd CmdID CmdStatus
  | -- | Event from the application side.
    DownstreamEvent DC.DownstreamCmdID DEvent.Event
  | -- | Stdin/stdout data from the app side.
    DoOutput CmdID URep.OutputType Text
  | -- | Child death event
    ChildDied ProcessID ExitCode
  | -- | Sensor callback
    DoSensor
  | -- | Control loop calback
    DoControl
  | -- | Shutting down the daemon
    DoShutdown

-- | The Launch status of a command, for registration.
data CmdStatus
  = -- | In case the command to start a child succeeded, mark it as registered and provide its PID.
    Launched ProcessID
  | -- | In case the command to start a child failed.
    NotLaunched
  deriving (Generic, MessagePack)

-- | The Behavior datatype encodes a behavior to be executed by the NRM runtime.
data Behavior
  = -- | The No-Op
    NoBehavior
  | -- | Log a message
    Log Text
  | -- | Reply to an upstream client.
    Rep UC.UpstreamClientID URep.Rep
  | -- | Publish messages on upstream
    Pub [UPub.Pub]
  | -- | Start a child process
    StartChild CmdID Command Arguments Env
  | -- | Kill children processes and send some messages back upstream.
    KillChildren [CmdID] [(UC.UpstreamClientID, URep.Rep)]
  | -- | Pop one child process and may send a message back upstream.
    ClearChild CmdID (Maybe (UC.UpstreamClientID, URep.Rep))
  deriving (Show, Generic)

mayRep :: Cmd -> URep.Rep -> Behavior
mayRep c rep = case (upstreamClientID . cmdCore) c of
  Just ucID -> Rep ucID rep
  Nothing -> Log "This command does not have a registered upstream client."

-- | The behavior function contains the main logic of the NRM daemon. It changes the state and
-- produces an associated behavior to be executed by the runtime. This contains the slice
-- management logic, the sensor callback logic, the control loop callback logic.
behavior :: Cfg.Cfg -> NRMState -> NRMEvent -> IO (NRMState, Behavior)
behavior _ st (DoOutput cmdID outputType content) =
  return . swap $ st &
    _cmdID cmdID
      \case
        Nothing -> (Log "No such command was found in the NRM state.", Nothing)
        Just c ->
          case content of
            _ -> (respondContent content c cmdID outputType, Nothing)
            "" ->
              let newPstate = case outputType of
                    URep.StdoutOutput -> (processState c) {stdoutFinished = True}
                    URep.StderrOutput -> (processState c) {stderrFinished = True}
               in isDone newPstate & \case
                    Just exc -> case removeCmd (KCmdID cmdID) st of
                      Just (_, _, _, _, st') ->
                        ( st'
                        , mayRep c (URep.RepCmdEnded $ URep.CmdEnded exc)
                        )
                      Nothing -> panic "Internal NRM state management error."
                    Nothing ->
                      ( NoBehavior
                      , st & _cmdID cmdID %~
                        (<&> field @"processState" .~ newPstate)
                      )
behavior _ st (RegisterCmd cmdID cmdstatus) = case cmdstatus of
  NotLaunched ->
    return $ fromMaybe (st, NoBehavior) $
      registerFailed cmdID st >>= \(st', _, _, cmdCore) ->
      upstreamClientID cmdCore <&> \x ->
        (st', Rep x (URep.RepStartFailure URep.StartFailure))
  Launched pid ->
    mayLog st $
      registerLaunched cmdID pid st <&> \(st', sliceID, maybeClientID) ->
      fromMaybe (st', NoBehavior) $
        maybeClientID <&> \clientID ->
        ( st'
        , Rep clientID (URep.RepStart (URep.Start sliceID cmdID))
        )
behavior c st (Req clientid msg) = case msg of
  UReq.ReqCPD _ ->
    return
      ( st
      , Rep clientid
        ( URep.RepCPD $
          URep.CPD
            (NRMCPD.toCPD st)
        )
      )
  UReq.ReqSliceList _ ->
    return
      ( st
      , Rep clientid
        ( URep.RepList $
          URep.SliceList
            (LM.toList (slices st))
        )
      )
  UReq.ReqGetState _ ->
    return (st, Rep clientid (URep.RepGetState (URep.GetState st)))
  UReq.ReqGetConfig _ ->
    return (st, Rep clientid (URep.RepGetConfig (URep.GetConfig c)))
  UReq.ReqRun UReq.Run {..} -> do
    cmdID <- nextCmdID <&> fromMaybe (panic "couldn't generate next cmd id")
    let (runCmd, runArgs) =
          (cmd spec, args spec) &
            ( if Manifest.perfwrapper (Manifest.app manifest) /=
              Manifest.PerfwrapperDisabled
            then wrapCmd (Cfg.argo_perf_wrapper c)
            else identity
            )
    return
      ( registerAwaiting cmdID
          ( mkCmd spec manifest
            ( if detachCmd
            then Nothing
            else Just clientid
            )
          )
          runSliceID .
          createSlice runSliceID $
          st
      , StartChild cmdID runCmd runArgs
        (env spec <> Env [("NRM_cmdID", toText cmdID)])
      )
  UReq.ReqKillSlice UReq.KillSlice {..} -> do
    let (maybeSlice, st') = removeSlice killSliceID st
    return
      ( st'
      , fromMaybe (Rep clientid $ URep.RepNoSuchSlice URep.NoSuchSlice)
        ( maybeSlice <&> \slice ->
          KillChildren (LM.keys $ Ct.cmds slice) $
            (clientid, URep.RepSliceKilled (URep.SliceKilled killSliceID)) :
            catMaybes
              ( (upstreamClientID . cmdCore <$> LM.elems (Ct.cmds slice)) <&>
                fmap (,URep.RepThisCmdKilled URep.ThisCmdKilled)
              )
        )
      )
  UReq.ReqSetPower _ -> return (st, NoBehavior)
  UReq.ReqKillCmd UReq.KillCmd {..} ->
    return $ fromMaybe (st, Rep clientid (URep.RepNoSuchCmd URep.NoSuchCmd)) $
      removeCmd (KCmdID killCmdID) st <&> \(info, _, cmd, sliceID, st') ->
      ( st'
      , KillChildren [killCmdID] $
        ( clientid
        , case info of
          CmdRemoved -> URep.RepCmdKilled (URep.CmdKilled killCmdID)
          SliceRemoved -> URep.RepSliceKilled (URep.SliceKilled sliceID)
        ) :
        maybe [] (\x -> [(x, URep.RepThisCmdKilled URep.ThisCmdKilled)]) (upstreamClientID . cmdCore $ cmd)
      )
behavior _ st (ChildDied pid exitcode) =
  return $
    lookupProcess pid st & \case
    Just (cmdID, cmd, sliceID, slice) ->
      let newPstate = (processState cmd) {ended = Just exitcode}
       in case isDone newPstate of
            Just _ -> case removeCmd (KProcessID pid) st of
              Just (_, _, _, _, st') ->
                ( st'
                , ClearChild cmdID
                  ( (,URep.RepCmdEnded (URep.CmdEnded exitcode)) <$>
                    (upstreamClientID . cmdCore $ cmd)
                  )
                )
              Nothing -> (st, panic "Error during command removal from NRM state")
            Nothing ->
              ( insertSlice sliceID
                  (Ct.insertCmd cmdID cmd {processState = newPstate} slice)
                  st
              , NoBehavior
              )
    Nothing -> (st, Log "No such PID in NRM's state.")
behavior _ st DoSensor = return (st, NoBehavior)
behavior _ st DoControl = return (st, NoBehavior)
behavior _ st DoShutdown = return (st, NoBehavior)
behavior cfg st (DownstreamEvent clientid msg) = case msg of
  DEvent.ThreadProgress _ _ -> return (st, Log "unimplemented")
  DEvent.ThreadPhaseContext _ _ -> return (st, Log "unimplemented")
  DEvent.ThreadPause _ -> return (st, Log "unimplemented")
  DEvent.ThreadPhasePause _ -> return (st, Log "unimplemented")
  DEvent.CmdPerformance DEvent.CmdHeader {..} DEvent.Performance {..} ->
    return $
      passiveSensorBehavior cfg st (DC.toSensorID clientid)
        (U.fromOps perf & fromIntegral) & \case
      Nothing ->
        registerDownstreamCmdClient cmdID clientid st <&>
          (,Log "downstream cmd client registered.") &
          fromMaybe (st, Log "no such Cmd")
      Just x ->
        x & _2 %~ \toPublish ->
          Pub $ toPublish :
            ( lookupCmd cmdID st & \case
              Nothing -> []
              Just (_cmd, sliceID, _slice) ->
                [ UPub.PubPerformance $ UPub.Performance
                    { UPub.perf = perf
                    , UPub.perfSliceID = sliceID
                    }
                ]
            )
  DEvent.CmdPause DEvent.CmdHeader {..} ->
    return $ fromMaybe (st, Log "No corresponding command for this downstream cmd 'pause' request.") $
      unRegisterDownstreamCmdClient cmdID clientid st <&>
      (,Log "downstream cmd client un-registered.")

-- | The sensitive unpacking that has to be pattern-matched on the python side.
-- These toObject/fromObject functions do not correspond to each other and the instance
-- just exists for passing the behavior to the python runtime.
instance MessagePack Behavior where

  toObject NoBehavior = toObject ("noop" :: Text)
  toObject (Log msg) = toObject ("log" :: Text, msg)
  toObject (Pub msgs) = toObject ("publish" :: Text, M.encodeT <$> msgs)
  toObject (Rep clientid msg) =
    toObject ("reply" :: Text, clientid, M.encodeT msg)
  toObject (StartChild cmdID cmd args env) =
    toObject ("cmd" :: Text, cmdID, cmd, args, env)
  toObject (KillChildren cmdIDs reps) =
    toObject
      ( "kill" :: Text
      , cmdIDs
      , (\(clientid, msg) -> (clientid, M.encodeT msg)) <$> reps
      )
  toObject (ClearChild cmdID maybeRep) =
    toObject
      ( "pop" :: Text
      , cmdID
      , (\(clientid, msg) -> (clientid, M.encodeT msg)) <$> Protolude.toList maybeRep
      )

  fromObject x = to <$> gFromObject x

mayLog :: NRMState -> Either Text (NRMState, Behavior) -> IO (NRMState, Behavior)
mayLog st =
  return . \case
    Left e -> (st, Log e)
    Right x -> x

passiveSensorBehavior
  :: Cfg.Cfg
  -> NRMState
  -> CPD.SensorID
  -> Double
  -> Maybe (NRMState, UPub.Pub)
passiveSensorBehavior _cfg st sensorID value =
  lookupPassiveSensor sensorID st & \case
    Nothing -> Nothing
    Just Sensor.PassiveSensor {..} ->
      CPD.measure (cpd st) value sensorID & \case
        CPD.Measured m -> Just (st, UPub.PubMeasurements (CPD.Measurements [m]))
        CPD.NoSuchSensor -> panic "NRM bug: Internal CPD/NRMState coherency error"
        CPD.AdjustProblem r p ->
          Just
            ( adjustSensorRange
                sensorID
                r $
                st {cpd = p}
            , UPub.PubCPD p
            )

respondContent :: Text -> Cmd -> CmdID -> URep.OutputType -> Behavior
respondContent content cmd cmdID outputType =
  mayRep cmd $
    outputType & \case
    URep.StdoutOutput ->
      URep.RepStdout $ URep.Stdout
        { URep.stdoutCmdID = cmdID
        , stdoutPayload = content
        }
    URep.StderrOutput ->
      URep.RepStderr $ URep.Stderr
        { URep.stderrCmdID = cmdID
        , stderrPayload = content
        }
