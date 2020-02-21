{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

-- |
-- Module      : NRM.Control
-- Copyright   : (c) UChicago Argonne, 2019
-- License     : BSD3
-- Maintainer  : fre@freux.fr
module NRM.Control
  ( banditCartesianProductControl,
    ControlM,
  )
where

import CPD.Core
import CPD.Integrated
import CPD.Utils
import CPD.Values
import Control.Lens hiding ((...))
import Data.Generics.Product
import Data.List.NonEmpty as NE
import Data.Map.Merge.Lazy
import HBandit.BwCR as BwCR
import HBandit.Class
import HBandit.Exp4R as Exp4R
import HBandit.Types as BT
import HBandit.Util
import LMap.Map as LM
import NRM.Types.Configuration as Cfg
import NRM.Types.Controller
import NRM.Types.MemBuffer as MemBuffer
import NRM.Types.Messaging.UpstreamPub as UPub
import NRM.Types.NRM
import NRM.Types.Units
import NeatInterpolation
import Numeric.Interval
import Protolude hiding (Map, log, to)
import Refined hiding (NonEmpty)
import Refined.Unsafe
import System.Random

-- | Zoomed NRM monad. Can still `behave` and `ask`.
type ControlM a = App Controller a

-- |  basic control strategy - uses a bandit with a cartesian product
-- of admissible actuator actions as the the decision space.
banditCartesianProductControl ::
  ControlCfg ->
  Problem ->
  Input ->
  Maybe [Action] ->
  ControlM Decision
banditCartesianProductControl ccfg cpd (Reconfigure t) _ = do
  pub (UPub.PubCPD t cpd)
  minTime <- use $ field @"integrator" . field @"minimumControlInterval"
  field @"integrator" .= initIntegrator t minTime (LM.keys $ sensors cpd)
  case (CPD.Core.objectives cpd, LM.toList (actuators cpd)) of
    ([], _) -> reset
    (_, l) -> nonEmpty l & \case
      Nothing -> reset
      Just actus -> mkActions actus (hint ccfg) & \case
        Nothing ->
          let h = show $ hint ccfg
              avail = show actus
              c = show $ allActions actus
           in logInfo
                [text|
               Control reset: No actions resulted from appliyng hint.
               `hint` is:
                  $h
               full cartesian set in intersection:
                  $c
               `actus` is:
                  $avail
              )
            |]
                >> reset
        Just availableActions -> do
          logInfo "control: bandit initialization"
          g <- liftIO getStdGen
          (b, aInitial) <- learnCfg ccfg & \case
            Contextual (CtxCfg hrizon) -> do
              -- per terminology of sun wen
              let riskThreshold :: ZeroOne Double
                  riskThreshold = fromMaybe BT.zero $ do
                    (threshold, expression) <- cpd ^? (field @"constraints" . folded)
                    r <- evalRange (range <$> sensors cpd) expression
                    hush . refine $ (threshold - inf r) / width r
              let b =
                    initCtx
                      ( Exp4RCfg
                          { expertsCfg = mkExperts availableActions,
                            constraintCfg = riskThreshold,
                            horizonCfg = unsafeRefine hrizon,
                            as = availableActions
                          }
                      )
              let ((a, g'), s') = runState (stepCtx g Nothing ()) b
              liftIO $ setStdGen g'
              return (Contextual s', a)
            Lagrange _ -> do
              let (b, a, g') = initPFMAB g (Arms availableActions) & _1 %~ Lagrange
              liftIO $ setStdGen g'
              return (b, a)
            Knapsack (BwCR.T gamma) -> do
              let (b, a, g') = initBwCR g (BwCRHyper gamma (Arms availableActions) ([BT.zero] ... [BT.one]) []) & _1 %~ Knapsack
              liftIO $ setStdGen g'
              return (b, a)
            Random (UniformCfg seed) -> do
              let (b, a, g') = initUniform (maybe g (\(Seed s) -> mkStdGen s) seed) availableActions & _1 %~ Random
              liftIO $ setStdGen g'
              return (b, a)
          field @"bandit" .= Just b
          field @"armstats" .= LM.empty
          return $ Decision aInitial InitialDecision
  where
    reset = do
      logInfo "control: reset"
      field @"bandit" .= Nothing
      field @"bufferedMeasurements" .= Nothing
      field @"referenceMeasurements" .= (sensors cpd $> MemBuffer.empty)
      refine 0 & \case
        Left _ -> logError "refinement failed in banditCartesianProductControl" >> doNothing
        Right v -> do
          field @"referenceMeasurementCounter" .= v
          doNothing
banditCartesianProductControl ccfg cpd (NoEvent t) mRefActions =
  tryControlStep ccfg cpd t mRefActions
banditCartesianProductControl ccfg cpd (Event t ms) mRefActions = do
  forM_ ms $ \m@(Measurement sensorID sensorValue sensorTime) -> do
    log $ "Processing measurement " <> show m
    field @"integrator" %= \(Integrator tlast delta measuredM) ->
      Integrator
        tlast
        delta
        ( measuredM
            & ix sensorID
              %~ measureValue (tlast + delta) (sensorTime, sensorValue)
        )
  tryControlStep ccfg cpd t mRefActions

intersect :: Eq a => [a] -> [a] -> [a]
intersect [] _ = []
intersect (x : xs) l
  | Protolude.elem x l = x : xs `intersect` l
  | otherwise = xs `intersect` l

intersectNE :: Eq a => NonEmpty a -> NonEmpty a -> Maybe (NonEmpty a)
intersectNE (NE.toList -> x) (NE.toList -> y) = nonEmpty (x `intersect` y)

mkActions :: NonEmpty (ActuatorID, Actuator) -> Hint -> Maybe (NonEmpty [Action])
mkActions actuators = \case
  Full -> Just allA
  (Only as) -> intersectNE allA as
  where
    allA = allActions actuators

allActions :: NonEmpty (ActuatorID, Actuator) -> NonEmpty [Action]
allActions actuators = cartesianProduct $ actuators <&> actuatorToActions

actuatorToActions :: (ActuatorID, Actuator) -> [Action]
actuatorToActions (actuatorID, a) = Action actuatorID <$> actions a

mkExperts :: NonEmpty [Action] -> NonEmpty (ObliviousRep [Action])
mkExperts arms = arms <&> \arm ->
  ObliviousRep
    ( arms
        <&> \focusedArm ->
          ( if arm == focusedArm then BT.one else BT.zero,
            focusedArm
          )
    )

tryControlStep ::
  ControlCfg ->
  Problem ->
  Time ->
  Maybe [Action] ->
  ControlM Decision
tryControlStep ccfg cpd t mRefActions = case CPD.Core.objectives cpd of
  [] -> doNothing
  os -> wrappedCStep ccfg os (CPD.Core.constraints cpd) (sensors cpd <&> range) t mRefActions

wrappedCStep ::
  ControlCfg ->
  [(ZeroOne Double, OExpr)] ->
  [(Double, OExpr)] ->
  Map SensorID (Interval Double) ->
  Time ->
  Maybe [Action] ->
  ControlM Decision
wrappedCStep cc stepObjectives stepConstraints sensorRanges t mRefActions = do
  logInfo "control: squeeze attempt"
  use (field @"integrator" . field @"measured") <&> squeeze t >>= \case
    Nothing -> logInfo "control: integrator squeeze failure" >> doNothing
    Just (measurements, newMeasured) -> do
      -- squeeze was successfull: setting the new integrator state
      logInfo "control: integrator squeeze success"
      field @"integrator" . field @"measured" .= newMeasured
      -- acquiring fields
      counter <- use $ field @"referenceMeasurementCounter"
      bufM <- use (field @"bufferedMeasurements")
      refM <- use $ field @"referenceMeasurements"
      let maxCounter = referenceMeasurementRoundInterval cc
      -- helper bindings
      let controlStep = stepFromSqueezed stepObjectives stepConstraints sensorRanges
      let innerStep = controlStep measurements
      refineLog (unrefine counter + 1) $ \counterValue ->
        case mRefActions of
          Nothing -> innerStep
          Just refActions -> do
            field @"referenceMeasurementCounter" .= counterValue
            -- define a ControlM monad value for starting the buffering
            let startBuffering = do
                  logInfo "control: meta control - starting reference measurement step"
                  -- reset the counter
                  field @"referenceMeasurementCounter" .= unsafeRefine 0
                  -- put the current measurements in "bufferedMeasurements"
                  field @"bufferedMeasurements" ?= measurements
                  -- take the reference actions
                  return $ Decision refActions ReferenceMeasurementDecision
            if unrefine counterValue <= unrefine maxCounter
              then case bufM of
                Nothing -> do
                  logInfo "control: inner control"
                  -- we perform the inner control step if no reference measurements
                  -- exist and otherwise run reference measurements.
                  LM.toList refM & \case
                    [] -> startBuffering
                    _ -> innerStep
                Just buffered -> do
                  -- we need to conclude this reference measurement mechanism
                  logInfo $
                    "control: meta control - concluding reference"
                      <> " measurement step, resuming inner control"
                  -- put the measurements that were just done in referenceMeasurements
                  field @"referenceMeasurements" %= enqueueAll measurements
                  -- clear the buffered measurements
                  field @"bufferedMeasurements" .= Nothing
                  -- feed the buffered measurements to the bandit
                  controlStep buffered
              else startBuffering
  where
    refineLog ::
      Predicate p x => x -> (Refined p x -> ControlM Decision) -> ControlM Decision
    refineLog v m = refine v & \case
      Left _ -> do
        logError "refinement failed in wrappedCStep"
        doNothing
      Right r -> m r

stepFromSqueezed ::
  [(ZeroOne Double, OExpr)] ->
  [(Double, OExpr)] ->
  Map SensorID (Interval Double) ->
  Map SensorID Double ->
  ControlM Decision
stepFromSqueezed stepObjectives stepConstraints sensorRanges measurements = do
  logInfo "in inner control"
  refMeasurements <- use (field @"referenceMeasurements") <&> fmap MemBuffer.avgBuffer
  let evaluatedObjectives :: [(ZeroOne Double, Maybe Double, Maybe (Interval Double))]
      evaluatedObjectives = stepObjectives <&> \(w, v) ->
        (w, evalNum measurements refMeasurements v, evalRange sensorRanges v)
      normalizedObjectives :: Maybe [(ZeroOne Double, ZeroOne Double)]
      normalizedObjectives =
        sequence $
          evaluatedObjectives <&> \case
            (w, Just v, Just r) -> normalize (v - inf r) (width r) <&> (w,)
            _ -> Nothing
      evaluatedConstraints :: Maybe [(Double, Double, Interval Double)]
      evaluatedConstraints = sequence $
        stepConstraints <&> \(interv, c) -> (interv,,) <$> evalNum measurements refMeasurements c <*> evalRange sensorRanges c
  (normalizedObjectives, evaluatedConstraints) & \case
    (Just robjs, Just rconstr) -> do
      logInfo
        ( "aggregated measurement computed with: \n sensors:"
            <> show sensorRanges
            <> "\n sensor values:"
            <> show measurements
            <> "\n refined objectives:"
            <> show robjs
            <> "\n refined constraints:"
            <> show rconstr
        )
      use (field @"bandit") >>= \case
        Nothing -> doNothing
        Just bandit -> do
          g <- liftIO getStdGen
          let hco = hardConstrainedObjective robjs rconstr
          (a, g', computedReward) <-
            bandit & \case
              Contextual b -> do
                let ((a, g'), s') =
                      runState
                        ( stepCtx
                            g
                            ( Just
                                ( Feedback
                                    (fst $ fromMaybe (panic "no objective in inner stepFromSqueezed") $ Protolude.head robjs)
                                    (maybe BT.zero unsafeRefine (Protolude.head rconstr <&> \(_, v, r) -> (v - inf r) / width r))
                                )
                            )
                            ()
                        )
                        b
                field @"bandit" ?= Contextual s'
                return (a, g', hco)
              Random b -> do
                let ((a, g'), s') = runState (stepUniform g) b
                field @"bandit" ?= Random s'
                return (a, g', hco)
              Knapsack b -> do
                let ((a, g'), s') = runState (stepBwCR g ((snd <$> robjs) <> [])) b
                field @"bandit" ?= Knapsack s'
                return (a, g', hco)
              Lagrange b -> do
                logInfo $ "computed Hard Constrained Objective of :" <> show hco
                --step :: (RandomGen g, MonadState b m) => g -> l -> m (a, g)
                let ((a, g'), s') = runState (stepPFMAB g hco) b
                field @"bandit" ?= Lagrange s'
                return (a, g', hco)
          use (field @"lastA") >>= \case
            Nothing -> return ()
            Just a' ->
              field @"armstats"
                %= ( \stats ->
                       lookup a' stats & \case
                         Nothing -> LM.insert a' (Armstat 1 (unrefine hco) (unrefine . snd <$> robjs) (rconstr <&> \(_, v, _) -> v) measurements refMeasurements) stats
                         Just (Armstat visits previousReward previousObjs previousConstraints previousMeasurements previousRefs) ->
                           LM.insert
                             a'
                             ( Armstat
                                 (visits + 1)
                                 (updateOnlineStat visits previousReward (unrefine hco))
                                 (updateOnlineStats visits previousObjs (unrefine . snd <$> robjs))
                                 (updateOnlineStats visits previousConstraints (rconstr <&> \(_, v, _) -> v))
                                 (updateOnlineStatLM visits previousMeasurements measurements)
                                 (updateOnlineStatLM visits previousRefs refMeasurements)
                             )
                             stats
                   )
          field @"lastA" .= Just a
          liftIO $ setStdGen g'
          return $
            Decision
              a
              ( InnerDecision
                  (ConstraintValue . (\(_, v, _) -> v) <$> rconstr)
                  (ObjectiveValue . unrefine . snd <$> robjs)
                  computedReward
                  evaluatedObjectives
                  robjs
                  rconstr
              )
    _ -> do
      logInfo $
        "controller failed a refinement step:"
          <> "\n stepObjectives: "
          <> show stepObjectives
          <> "\n stepConstraints: "
          <> show stepConstraints
          <> "\n sensorRanges: "
          <> show sensorRanges
          <> "\n measurements: "
          <> show measurements
          <> "\n refMeasurements: "
          <> show refMeasurements
          <> "\n normalizedObjectives: "
          <> show normalizedObjectives
          <> "\n evaluatedConstraints: "
          <> show evaluatedConstraints
          <> "\n evaluatedObjectives: "
          <> show evaluatedObjectives
      doNothing

updateOnlineStatLM ::
  Int ->
  Map SensorID Double ->
  Map SensorID Double ->
  Map SensorID Double
updateOnlineStatLM i (LM.toDataMap -> m) (LM.toDataMap -> mNew) =
  LM.fromDataMap $ merge dropMissing dropMissing (zipWithAMatched f) m mNew
  where
    f _ old new = pure $ updateOnlineStat i old new

updateOnlineStats :: Int -> [Double] -> [Double] -> [Double]
updateOnlineStats i = Protolude.zipWith $
  \xOld xNew -> ((xOld * fromIntegral i) + xNew) / fromIntegral (i + 1)

updateOnlineStat :: Int -> Double -> Double -> Double
updateOnlineStat i xOld xNew = ((xOld * fromIntegral i) + xNew) / fromIntegral (i + 1)

hardConstrainedObjective ::
  [(ZeroOne Double, ZeroOne Double)] ->
  [(Double, Double, Interval Double)] ->
  ZeroOne Double
hardConstrainedObjective robjs rconstr =
  if allConstraintsMet
    then normalizedSum robjs
    else BT.one
  where
    allConstraintsMet = all (\(threshold, v, _) -> v < threshold) rconstr

doNothing :: ControlM Decision
doNothing = return DoNothing

sampleUniform :: StdGen -> NonEmpty a -> (a, StdGen)
sampleUniform g as = sampleWL ((BT.one,) <$> as) g

initUniform :: StdGen -> Protolude.NonEmpty a -> (Uniform a, a, StdGen)
initUniform g as = (Uniform (Protolude.toList as), a, g')
  where
    (a, g') = sampleUniform g as

stepUniform :: (MonadState (Uniform a) m) => StdGen -> m (a, StdGen)
stepUniform g = get <&> \(Uniform (nonEmpty -> as)) -> as & \case
  Nothing -> panic "Control.hs: trying to sample from empty action list."
  Just nas -> sampleUniform g nas

-- | Cartesian product of nonempty lists
cartesianProduct :: NonEmpty [Action] -> NonEmpty [Action]
cartesianProduct = NE.fromList . cartesianProduct' . NE.toList

-- | Cartesian product of lists. Basically `sequence` with special treatment of
-- corner cases.
cartesianProduct' :: [[Action]] -> [[Action]]
cartesianProduct' [] = []
cartesianProduct' [[]] = []
cartesianProduct' s = sequence s
