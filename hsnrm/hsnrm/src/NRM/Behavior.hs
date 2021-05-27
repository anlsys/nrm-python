-- |
-- Module      : NRM.Behavior
-- Copyright   : (c) UChicago Argonne, 2019
-- License     : BSD3
-- Maintainer  : fre@freux.fr
module NRM.Behavior
  ( -- * external interface
    behavior,

    -- * internal dispatching
    nrm,
    nrmDownstreamEvent,
    doControl,
    commonSP,
    injectDownstreamVars,
    mayRep,
    respondContent,
  )
where

import CPD.Core as CPD
import CPD.Utils as CPD
import CPD.Values as CPD
import Control.Applicative
import qualified Control.Exception.Enclosed as EE
import Control.Lens hiding (_Unwrapped, _Wrapped, to)
import Control.Monad.Trans.RWS.Lazy (RWST)
import Data.Generics.Labels ()
import Data.Generics.Wrapped
import qualified Data.Map as M
import LensMap.Core as LensMap
import qualified NRM.CPD as NRMCPD
import NRM.Control
import NRM.Messaging
import NRM.Sensors as Sensors
import NRM.State
import NRM.Types.Actuator as A
import NRM.Types.Behavior
import NRM.Types.Cmd
import NRM.Types.CmdID as CmdID
import NRM.Types.Configuration as Cfg
import NRM.Types.Controller as Controller
import qualified NRM.Types.DownstreamClient as DC
import NRM.Types.DownstreamCmdID as DCmID
import NRM.Types.DownstreamThreadID as DTID
import NRM.Types.Manifest as Manifest
import qualified NRM.Types.Messaging.DownstreamEvent as DEvent
import qualified NRM.Types.Messaging.UpstreamPub as UPub
import qualified NRM.Types.Messaging.UpstreamRep as URep
import qualified NRM.Types.Messaging.UpstreamReq as UReq
import NRM.Types.NRM
import NRM.Types.Process as Process
import NRM.Types.Sensor as Sensor
import qualified NRM.Types.Slice as Ct
import NRM.Types.State
import qualified NRM.Types.Units as U
import NRM.Types.UpstreamClient
import Protolude hiding (Map, log)

-- | External interface for NRM behavior, without RWS monad
behavior ::
  Cfg.Cfg ->
  NRMState ->
  U.Time ->
  NRMEvent ->
  IO (NRMState, [Behavior])
behavior cfg st time event = execNRM (nrm time event) cfg st

-- | The nrm function contains the main logic of the NRM daemon. It changes
-- the state and produces an associated behavior to be executed by the
-- runtime. This contains the slice management logic, the sensor callback
-- logic, the control loop callback logic. Works in the @NRM monad.
nrm :: U.Time -> NRMEvent -> NRM ()
nrm _callTime (DoOutput cmdID outputType content) =
  _cmdID cmdID `modifyL` \case
    Nothing -> do
      logError "No such command was found in the NRM state."
      return Nothing
    Just c -> case content of
      "" -> do
        let newPstate = case outputType of
              URep.StdoutOutput -> (processState c) {stdoutFinished = True}
              URep.StderrOutput -> (processState c) {stderrFinished = True}
        isDone newPstate & \case
          Just exc -> do
            behave $ mayRep c (URep.RepCmdEnded $ URep.CmdEnded exc)
            pub $ UPub.PubEnd cmdID
            return Nothing
          Nothing -> do
            log ("warning, empty content: " <> show content)
            return (Just (c & #processState .~ newPstate))
      _ -> do
        behave $ respondContent content c cmdID outputType
        return $ Just c
nrm _callTime (RegisterCmd cmdID cmdstatus) = do
  st <- get
  case cmdstatus of
    NotLaunched -> case registerFailed cmdID st of
      Just (st', _, _, cmdCore) -> case upstreamClientID cmdCore of
        Just ucid -> do
          put st'
          rep ucid $ URep.RepStartFailure URep.StartFailure
        Nothing -> pass
      Nothing -> pass
    Launched pid ->
      registerLaunched cmdID pid st & \case
        Left l -> log l
        Right (st', sliceID, maybeClientID) -> do
          put st'
          maybeClientID & \case
            Just clientID ->
              rep clientID . URep.RepStart $ URep.Start sliceID cmdID
            Nothing -> pass
nrm _callTime (Req clientid msg) =
  sendExceptionsUp clientid $ do
    st <- get
    c <- ask
    msg & \case
      UReq.ReqCPD _ ->
        rep clientid . URep.RepCPD $ NRMCPD.toCPD (controlCfg c) st
      UReq.ReqSliceList _ ->
        rep clientid . URep.RepList . URep.SliceList . M.toList $ slices st
      UReq.ReqGetState _ -> rep clientid $ URep.RepGetState st
      UReq.ReqGetConfig _ -> rep clientid . URep.RepGetConfig $ URep.GetConfig c
      UReq.ReqRun UReq.Run {..} -> do
        cmdID <-
          lift CmdID.nextCmdID
            <&> fromMaybe (panic "couldn't generate next cmd id")
        let (runCmd, runArgs) =
              (spec ^. #cmd, spec ^. #args) & case Manifest.perfwrapper (Manifest.app manifest) of
                Nothing -> identity
                (Just p@Manifest.Perfwrapper {}) ->
                  wrapCmd
                    (Command $ Cfg.perfwrapperPath c)
                    [ "-f",
                      Arg . show . U.fromHz
                        . Manifest.toFrequency
                        $ Manifest.perfFreq p
                    ]
        modify $
          registerAwaiting
            cmdID
            (mkCmd spec manifest (if detachCmd then Nothing else Just clientid))
            runSliceID
            . createSlice runSliceID
        behave . StartChild cmdID runCmd runArgs $
          injectDownstreamVars c manifest cmdID (spec ^. #env)
      UReq.ReqKillSlice UReq.KillSlice {..} ->
        _sliceID killSliceID `modifyL` \case
          Nothing -> do
            rep clientid $ URep.RepNoSuchSlice URep.NoSuchSlice
            return Nothing
          (Just slice) -> do
            behave . KillChildren (M.keys $ Ct.cmds slice) $
              (clientid, URep.RepSliceKilled (URep.SliceKilled killSliceID))
                : catMaybes
                  ( (upstreamClientID . cmdCore <$> M.elems (Ct.cmds slice))
                      <&> fmap (,URep.RepThisCmdKilled URep.ThisCmdKilled)
                  )
            return Nothing
      UReq.ReqActuate actions -> do
        cpd <- NRMCPD.toCPD <$> (ask <&> controlCfg) <*> pure st
        for_ actions $ \action@(Action actuatorID (CPD.DiscreteDouble value)) ->
          validateAction cpd action & \case
            UnknownActuator -> do
              log "NRM controller received an action request on a non-existent actuator"
              rep clientid (URep.RepActuate URep.NotActuated)
            InvalidAction -> do
              log "NRM controller received an action request on an invalid action"
              rep clientid (URep.RepActuate URep.NotActuated)
            ActionOk ->
              fromCPDKey actuatorID & \case
                Nothing -> log "couldn't decode actuatorID"
                Just aKey ->
                  M.lookup aKey (lenses st) & \case
                    Nothing -> log "NRM internal error: actuator not found, after CPD validation."
                    Just (ScopedLens l) -> do
                      liftIO $ go (st ^. l) value
                      log $ "NRM controller takes action:" <> show value <> " for actuator" <> show actuatorID
                      rep clientid (URep.RepActuate URep.Actuated)
      UReq.ReqKillCmd UReq.KillCmd {..} ->
        removeCmd (KCmdID killCmdID) st & \case
          Nothing -> rep clientid $ URep.RepNoSuchCmd URep.NoSuchCmd
          Just (info, _, cmd, sliceID, st') -> do
            put st'
            behave . KillChildren [killCmdID] $
              ( clientid,
                info & \case
                  CmdRemoved -> URep.RepCmdKilled (URep.CmdKilled killCmdID)
                  SliceRemoved -> URep.RepSliceKilled (URep.SliceKilled sliceID)
              )
                : maybe
                  []
                  (\x -> [(x, URep.RepThisCmdKilled URep.ThisCmdKilled)])
                  (upstreamClientID . cmdCore $ cmd)
nrm _callTime (ChildDied pid exitcode) = do
  st <- get
  lookupProcess pid st & \case
    Nothing -> log "No such PID in NRM's state."
    Just (cmdID, cmd, sliceID, slice) ->
      let newPstate = (processState cmd) {ended = Just exitcode}
       in isDone newPstate & \case
            Just _ ->
              removeCmd (KProcessID pid) st & \case
                Just (_, _, _, _, st') -> do
                  put st'
                  behave $
                    ClearChild
                      cmdID
                      ( (,URep.RepCmdEnded (URep.CmdEnded exitcode))
                          <$> (upstreamClientID . cmdCore $ cmd)
                      )
                  pub $ UPub.PubEnd cmdID
                Nothing -> log "Error during command removal from NRM state"
            Nothing ->
              put $
                st
                  & #slices
                    . at sliceID
                  ?~ (slice & #cmds . at cmdID ?~ cmd {processState = newPstate})
nrm callTime (DownstreamEvent clientid msg) =
  nrmDownstreamEvent callTime clientid msg
    <&> ( \case
            OOk m -> Event callTime [m]
            ONotFound -> NoEvent callTime
            ONoValue -> NoEvent callTime
            OAdjustment -> Reconfigure callTime
        )
    >>= doControl
nrm callTime DoControl = doControl (NoEvent callTime)
nrm callTime DoSensor = do
  st <- get
  (st', measurements) <- lift (foldM runSensor (st, Just []) (M.toList $ lenses st))
  put st'
  measurements & \case
    Just [] ->
      doControl (Event callTime [])
    Just ms ->
      pub (UPub.PubMeasurements callTime ms)
        >> doControl (Event callTime ms)
    Nothing -> doControl (Reconfigure callTime)
  where
    runSensor ::
      (NRMState, Maybe [CPD.Measurement]) -> -- snd = Nothing <=> cpd changed.
      (PassiveSensorKey, ScopedLens NRMState PassiveSensor) ->
      IO (NRMState, Maybe [CPD.Measurement])
    runSensor (s, ms) (k, ScopedLens l) = do
      (newSensor, maybeMeasurement) <- processPassiveSensor callTime (k, s ^. l)
      return (s & l .~ newSensor, (:) <$> maybeMeasurement <*> ms) -- somewhat elegant, all considered
nrm _callTime DoShutdown = pass

-- | doControl checks the integrator state and triggers a control iteration if NRM is ready.
doControl :: Controller.Input -> NRM ()
doControl input = do
  st <- get
  mccfg <- ask <&> controlCfg
  zoom (#controller . _Just) $ do
    logInfo ("Control input:" <> show input)
    mccfg & \case
      ControlOff -> pass
      ccfg@ControlCfg {} ->
        let cpd = NRMCPD.toCPD ccfg st
            mRefActions =
              if not (Protolude.null (CPD.constraints cpd))
                then Just $
                  ( M.toList (lenses st) ::
                      [(ActuatorKey, ScopedLens NRMState A.Actuator)]
                  )
                    <&> \(k, ScopedLens l) ->
                      CPD.Action
                        { actuatorID = toS k,
                          actuatorValue = CPD.DiscreteDouble $ st ^. l . #referenceAction
                        }
                else Nothing
         in banditCartesianProductControl ccfg cpd input mRefActions >>= \case
              DoNothing -> pass
              Decision actions decisionMeta -> do
                get >>= \ctrl -> pub (UPub.PubAction (getTime input) actions decisionMeta ctrl)
                forM_ actions $ \(Action actuatorID (CPD.DiscreteDouble discreteValue)) ->
                  fromCPDKey actuatorID & \case
                    Nothing -> log "couldn't decode actuatorID"
                    Just aKey ->
                      M.lookup aKey (lenses st) & \case
                        Nothing -> log "NRM internal error: actuator not found."
                        Just (ScopedLens l) -> do
                          liftIO $ go (st ^. l) discreteValue
                          log $
                            "NRM controller takes action:"
                              <> show discreteValue
                              <> " for actuator"
                              <> show actuatorID
  where
    getTime (Controller.Event t _) = t
    getTime (Controller.NoEvent t) = t
    getTime (Controller.Reconfigure t) = t

-- | Downstream event handler.
-- Downstream message are events related to the performance or behavior of an
-- application under control. This handler mostly deals with recording those
-- event as part of the monitoring and handling discovery of process start/exit
--
-- To ensure decent timings on the monitoring side, downstream events all
-- contain a timestamps in nanoseconds since the epoch.
nrmDownstreamEvent ::
  U.Time ->
  DC.DownstreamClientID ->
  DEvent.Event ->
  NRM (CommonOutcome CPD.Measurement)
nrmDownstreamEvent _callTime clientid (DEvent.Event timestamp info) =
  nrmDownstreamEventHandleInfo clientid (U.nanoS timestamp) info

-- | EventInfo handling, using lambda-case to do pattern matching
nrmDownstreamEventHandleInfo ::
  DC.DownstreamClientID ->
  U.Time ->
  DEvent.EventInfo ->
  NRM (CommonOutcome CPD.Measurement)
nrmDownstreamEventHandleInfo clientid timestamp = \case
  DEvent.CmdPerformance cmdID perf ->
    DCmID.fromText (toS clientid) & \case
      Nothing -> log "couldn't decode clientID to UUID" >> return ONotFound
      Just downstreamCmdID ->
        commonSP
          timestamp
          (Sensor.DownstreamCmdKey downstreamCmdID)
          (U.fromOps perf & fromIntegral)
          >>= \case
            ONoValue -> return ONoValue
            ONotFound ->
              zoom (_cmdID cmdID) $
                get >>= \case
                  Nothing -> do
                    log $
                      "No command was found in the NRM state for "
                        <> "the cmdID associatid with this cmdPerf message."
                    return ONotFound
                  Just c -> do
                    put $ addDownstreamCmdClient c downstreamCmdID
                    log "downstream thread registered."
                    return OAdjustment
            OAdjustment -> return OAdjustment
            OOk m ->
              pub (UPub.PubPerformance timestamp cmdID perf)
                >> return (OOk m)
  DEvent.ThreadProgress downstreamThreadID payload ->
    commonSP
      timestamp
      (Sensor.DownstreamThreadKey downstreamThreadID)
      (payload & U.fromProgress & fromIntegral)
      >>= \case
        ONoValue -> return ONoValue
        ONotFound ->
          zoom (_cmdID (cmdID downstreamThreadID)) $
            get >>= \case
              Nothing -> do
                log $
                  "No command was found in the NRM state for "
                    <> "this downstreamThreadID."
                return ONotFound
              Just c -> registerDTT c downstreamThreadID
        OAdjustment -> return OAdjustment
        OOk m ->
          pub (UPub.PubProgress timestamp downstreamThreadID payload)
            >> return (OOk m)
  DEvent.ThreadPhaseContext downstreamThreadID phaseContext ->
    commonSP
      timestamp
      (Sensor.DownstreamThreadKey downstreamThreadID)
      (DEvent.computetime phaseContext & fromIntegral)
      >>= \case
        ONoValue -> return ONoValue
        ONotFound ->
          zoom (_cmdID (cmdID downstreamThreadID)) $
            get >>= \case
              Nothing -> do
                log $
                  "No command was found in the NRM state for"
                    <> " this downstreamThreadID."
                return ONotFound
              Just c -> registerDTT c downstreamThreadID
        OAdjustment -> return OAdjustment
        OOk m -> do
          st <- get
          M.lookup (cmdID downstreamThreadID) (cmdIDMap st) & \case
            Nothing ->
              log "internal NRM state warning: phasecontext pub lookup failed"
                >> return (OOk m)
            Just (_, sliceID, _) ->
              pub
                ( UPub.PubPhaseContext
                    timestamp
                    downstreamThreadID
                    sliceID
                    phaseContext
                )
                >> return (OOk m)
  DEvent.CmdPause cmdID ->
    DCmID.fromText (toS clientid) & \case
      Nothing -> log "couldn't decode clientID to UUID" >> return ONotFound
      Just downstreamCmdID ->
        zoom (_cmdID cmdID) $
          get >>= \case
            Nothing -> do
              log $
                "No corresponding command for this downstream"
                  <> " cmd 'pause' request."
              return ONotFound
            Just c -> do
              put $
                Just
                  ( c
                      & #downstreamCmds
                        . at downstreamCmdID
                      .~ Nothing
                  )
              log "downstream cmd un-registered."
              return OAdjustment
  DEvent.ThreadPause downstreamThreadID ->
    zoom
      (_cmdID (cmdID downstreamThreadID))
      $ get >>= \case
        Nothing ->
          log
            ( "No corresponding command for this downstream thread 'pause'"
                <> " request."
            )
            >> return ONotFound
        Just c -> do
          put $
            Just
              ( c
                  & #downstreamThreads
                    . at downstreamThreadID
                  .~ Nothing
              )
          log "downstream thread un-registered."
          return ONotFound
  DEvent.ThreadPhasePause _ ->
    log "unimplemented ThreadPhasePause handler"
      >> return ONotFound
  where
    registerDTT ::
      Cmd ->
      DownstreamThreadID ->
      RWST Cfg [Behavior] (Maybe Cmd) IO (CommonOutcome a)
    registerDTT c dtid = do
      put . Just $ addDownstreamThreadClient c dtid
      log "downstream thread registered."
      return OAdjustment

data CommonOutcome a = OAdjustment | OOk a | ONotFound | ONoValue

commonSP ::
  U.Time ->
  ActiveSensorKey ->
  Double ->
  NRM (CommonOutcome Measurement)
commonSP callTime key value = do
  st <- get
  M.lookup key (lenses st :: LensMap NRMState ActiveSensorKey ActiveSensor) & \case
    Nothing -> return ONotFound
    Just (ScopedLens sl) -> do
      let (measurementOutput, newSensor) =
            postProcessSensor callTime key value (st ^. sl)
      put (st & sl .~ newSensor)
      measurementOutput & \case
        Sensors.NoMeasurement -> return ONoValue
        Sensors.Adjusted -> do
          logInfo "Out-of-range value received, sensor adjusted."
          return OAdjustment
        Sensors.Ok measurement -> do
          pub $ UPub.PubMeasurements callTime [measurement]
          return $ OOk measurement

mayRep :: Cmd -> URep.Rep -> Behavior
mayRep c rp =
  (upstreamClientID . cmdCore) c & \case
    Just ucID -> Rep ucID rp
    Nothing ->
      Log
        Error
        ( "This command does not have a registered"
            <> " upstream client."
        )

respondContent :: Text -> Cmd -> CmdID -> URep.OutputType -> Behavior
respondContent content cmd cmdID outputType =
  mayRep cmd $
    outputType & \case
      URep.StdoutOutput ->
        URep.RepStdout $ URep.Stdout cmdID content
      URep.StderrOutput ->
        URep.RepStderr $ URep.Stderr cmdID content

processPassiveSensor ::
  U.Time ->
  (PassiveSensorKey, PassiveSensor) ->
  IO (PassiveSensor, Maybe CPD.Measurement)
processPassiveSensor time (k, sensor) =
  perform sensor <&> \case
    Just value ->
      postProcessSensor time k value sensor & swap & _2 %~ \case
        Ok m -> Just m
        _ -> Nothing
    Nothing ->
      processPassiveSensorFailure sensor time & \case
        LegalFailure -> (sensor, Nothing)
        IllegalFailureRemediation sensor' -> (sensor', Nothing)

injectDownstreamVars :: Cfg -> Manifest -> CmdID -> Env -> Env
injectDownstreamVars c manifest cmdID =
  execState $ do
    _Unwrapped . at cmdIDEnvVar ?= CmdID.toText cmdID
    for_
      ( Manifest.toFrequency
          <$> (manifest ^.. #app . #instrumentation . _Just . #ratelimit)
      )
      modifyRatelimitLens
    for_ (c ^. #libnrmPath) modifyLDPreloadLens
  where
    modifyRatelimitLens :: U.Frequency -> State Env ()
    modifyRatelimitLens ratelim =
      _Unwrapped . at ratelimitEnvVar
        ?= (show . (floor :: Double -> Int)) (U.fromHz ratelim)
    modifyLDPreloadLens :: Text -> State Env ()
    modifyLDPreloadLens path =
      _Unwrapped . at "LD_PRELOAD" %= \case
        Nothing -> Just path
        Just x -> Just $ x <> " " <> path

-- | very permissive
modifyL ::
  (MonadState s m) =>
  LensLike (Control.Applicative.WrappedMonad m) s s a b ->
  (a -> m b) ->
  m ()
l `modifyL` f = get >>= mapMOf l f >>= put

sendExceptionsUp :: UpstreamClientID -> NRM () -> NRM ()
sendExceptionsUp clientid nrmMonad =
  exceptionLess nrmMonad >>= \case
    Left content -> do
      logError content
      rep clientid (URep.RepException content)
    Right _ -> pass

exceptionLess :: NRM a -> NRM (Either Text a)
exceptionLess io = EE.catchAny (Right <$> io) $ return . Left . show
