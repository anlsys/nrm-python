{-|
Module      : Nrm.Optparse.Client
Copyright   : (c) UChicago Argonne, 2019
License     : BSD3
Maintainer  : fre@freux.fr
-}
module Nrm.Optparse.Client
  ( opts
  )
where

import qualified Data.ByteString as B
  ( getContents
  )
import Dhall
import Nrm.Types.Container
import Nrm.Types.Manifest
import qualified Nrm.Types.Manifest.Dhall as D
import qualified Nrm.Types.Manifest.Yaml as Y
import Nrm.Types.Messaging.UpstreamReq
import Options.Applicative
import Protolude
import System.Directory
import System.Environment
import System.FilePath.Posix
import Text.Editor
import qualified Prelude
  ( print
  )

data RunCfg
  = RunCfg
      { stdinType :: SourceType
      , edit :: Bool
      , inputfile :: Maybe Text
      , containerName :: Maybe Text
      , cmd :: Text
      , runargs :: [Text]
      }

runParser :: Parser RunCfg
runParser =
  RunCfg <$>
    flag
      Dhall
      Yaml
      ( long "yaml" <> short 'y' <>
        help
          "Assume stdin to be yaml instead of dhall."
      ) <*>
    flag
      False
      True
      (long "edit" <> short 'e' <> help "Edit manifest yaml in $EDITOR before running the NRM client.") <*>
    optional
      ( strOption
        ( long "manifest" <>
          metavar "MANIFEST" <>
          help
            "Input manifest with .yml/.yaml/.dh/.dhall extension. Leave void for stdin (dhall) input."
        )
      ) <*>
    optional
      ( strOption
        ( long "container" <> short 'c' <>
          metavar "containerName" <>
          help
            "Container name/UUID"
        )
      ) <*>
    strArgument
      ( metavar "cmd" <>
        help
          "Command name"
      ) <*>
    some
      ( strArgument
        ( metavar "arg" <>
          help
            "Command arguments"
        )
      )

killParser :: Parser Text
killParser =
  strArgument
    ( metavar "container" <>
      help
        "Name/UUID of the container to kill"
    )

setpowerParser :: Parser Text
setpowerParser =
  strArgument
    ( metavar "powerlimit" <>
      help
        "Power limit to set"
    )

opts :: Parser (IO Req)
opts =
  hsubparser $
    command "run"
      ( info (run <$> runParser) $
        progDesc "Run the application via NRM"
      ) <>
    command "kill"
      ( info (return <$> (Kill . KillRequest <$> killParser)) $
        progDesc "Kill container"
      ) <>
    command
      "setpower"
      ( info (return <$> (SetPower . SetPowerRequest <$> setpowerParser)) $
        progDesc "Set power limit"
      ) <>
    command
      "list"
      (info (return <$> pure List) $ progDesc "List existing containers") <>
    help
      "Choice of operation."

data SourceType = Dhall | Yaml
  deriving (Eq)

data FinallySource = NoExt | FinallyFile SourceType Text | FinallyStdin SourceType

ext :: SourceType -> Maybe Text -> FinallySource
ext _ (Just fn)
  | xt `elem` [".dh", ".dhall"] = FinallyFile Dhall fn
  | xt `elem` [".yml", ".yaml"] = FinallyFile Yaml fn
  | otherwise = NoExt
  where
    xt = takeExtension $ toS fn
ext st Nothing = FinallyStdin st

load :: RunCfg -> IO Manifest
load RunCfg {..} =
  (if edit then editing else return) =<< case ext stdinType inputfile of
    (FinallyFile Dhall filename) ->
      detailed $
        D.inputManifest =<<
        toS <$>
        makeAbsolute (toS filename)
    (FinallyFile Yaml filename) ->
      Y.decodeManifestFile =<< toS <$> makeAbsolute (toS filename)
    (FinallyStdin Yaml) ->
      B.getContents <&> Y.decodeManifest >>= \case
        Left e -> Prelude.print e >> die "yaml parsing exception."
        Right manifest -> return manifest
    (FinallyStdin Dhall) -> B.getContents >>= D.inputManifest . toS
    NoExt ->
      die
        ( "couldn't figure out extension for input file. " <>
          "Please use something in {.yml,.yaml,.dh,.dhall} ."
        )

editing :: Manifest -> IO Manifest
editing c =
  runUserEditorDWIM yt (Y.encodeManifest c) <&> Y.decodeManifest >>= \case
    Left e -> Prelude.print e >> die "yaml parsing exception."
    Right manifest -> return manifest
  where
    yt = mkTemplate "yaml"

run :: RunCfg -> IO Req
run rc = do
  manifest <- load rc
  cn <-
    case containerName rc of
      Nothing -> fromMaybe (panic "Couldn't generate next container UUID") <$> nextContainerUUID
      Just n -> return $ Name n
  env <- fmap (\(x, y) -> (toS x, toS y)) <$> getEnvironment
  return $ Run $ RunRequest
    { manifest = manifest
    , path = cmd rc
    , args = runargs rc
    , runcontainer_uuid = cn
    , environ = env
    }

{-containerName :: Maybe Text-}
{-cmd :: Text-}
{-args :: [Text]-}

{-printY :: ManifestLocationCfg -> IO Manifest-}
{-printY c = do-}
{-manifest <- load c-}
{-putText . toS . Y.encodeManifest $ manifest-}
{-return manifest-}