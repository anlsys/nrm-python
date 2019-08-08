{-# LANGUAGE QuasiQuotes #-}

{-|
Module      : Nrm.Codegen
Copyright   : (c) 2019, UChicago Argonne, LLC.
License     : BSD3
Maintainer  : fre@freux.fr
-}
module Nrm.Codegen
  ( main
  , upstreamPubSchema
  , upstreamReqSchema
  , upstreamRepSchema
  , downstreamEventSchema
  , libnrmHeader
  )
where

import Codegen.CHeader
import Codegen.Dhall
import Codegen.Schema (generatePretty)
import Data.Default
import Dhall
import qualified Dhall.Core as Dhall
import qualified Dhall.Lint as Lint
import qualified Dhall.Parser
import qualified Dhall.TypeCheck as Dhall
import NeatInterpolation
import qualified Nrm.Types.Configuration as CI (Cfg)
import qualified Nrm.Types.Configuration.Yaml as CI (encodeCfg)
import qualified Nrm.Types.Manifest as MI (Manifest)
import qualified Nrm.Types.Manifest.Yaml as MI (encodeManifest)
import Nrm.Types.Messaging.DownstreamEvent
import Nrm.Types.Messaging.UpstreamPub
import Nrm.Types.Messaging.UpstreamRep
import Nrm.Types.Messaging.UpstreamReq
import Protolude hiding (Rep)
import System.Directory

-- | The main code generation binary.
main :: IO ()
main = do
  putText "Codegen: LibNRM C headers."
  putText $ "  Writing libnrm header to " <> toS headerFile
  writeFile (toS headerFile) $ toS (licenseC <> libnrmHeader)
  putText "Codegen: JSON schemas"
  verboseWriteSchema "upstreamPub" upstreamPubSchema
  verboseWriteSchema "upstreamRep" upstreamRepSchema
  verboseWriteSchema "upstreamReq" upstreamReqSchema
  verboseWriteSchema "downstreamEvent" downstreamEventSchema
  generateDefaultConfigurations
  where
    headerFile = prefix <> "/nrm_messaging.h"
    verboseWriteSchema desc sch = do
      putText $ toS ("  Writing schema for " <> toS desc <> " to " <> fp)
      writeFile (toS fp) sch
      where
        fp = prefix <> desc <> ".json"

-- | The upstream Request schema.
upstreamReqSchema :: Text
upstreamReqSchema = generatePretty (Proxy :: Proxy Req)

-- | The upstream Reply schema.
upstreamRepSchema :: Text
upstreamRepSchema = generatePretty (Proxy :: Proxy Rep)

-- | The upstream Pub schema.
upstreamPubSchema :: Text
upstreamPubSchema = generatePretty (Proxy :: Proxy Pub)

-- | The downstream Event schema.
downstreamEventSchema :: Text
downstreamEventSchema = generatePretty (Proxy :: Proxy Event)

-- | The libnrm C header.
libnrmHeader :: Text
libnrmHeader = toHeader $ toCHeader (Proxy :: Proxy Event)

-- | A license for C headers.
licenseC :: Text
licenseC =
  [text|
    /*******************************************************************************
     * Copyright 2019 UChicago Argonne, LLC.
     * (c.f. AUTHORS, LICENSE)
     *
     * SPDX-License-Identifier: BSD-3-Clause
    *******************************************************************************/

    /*
     *
     *    this file is auto-generated by nrm, modifications will be erased.
     *
    */

  |]

-- | A license for Yaml files
licenseYaml :: Text
licenseYaml =
  [text|
    # ******************************************************************************
    #  Copyright 2019 UChicago Argonne, LLC.
    #  (c.f. AUTHORS, LICENSE)
    #
    #  SPDX-License-Identifier: BSD-3-Clause
    # ******************************************************************************

    #
    #
    #     this file is auto-generated by nrm, modifications will be erased.
    #
    #

  |]

-- | A license for Dhall files
licenseDhall :: Text
licenseDhall =
  [text|
    -- ******************************************************************************
    --  Copyright 2019 UChicago Argonne, LLC.
    --  (c.f. AUTHORS, LICENSE)
    --
    --  SPDX-License-Identifier: BSD-3-Clause
    -- ******************************************************************************
    --
    --
    --
    --     this file is auto-generated by nrm, modifications will be erased.
    --
    --

  |]

data KnownType
  = Cfg
  | Manifest
  deriving (Bounded, Enum, Eq, Ord, Read, Show)

dhallType :: KnownType -> Dhall.Expr Dhall.Parser.Src a
dhallType =
  fmap Dhall.absurd <$> \case
    Cfg -> Dhall.expected (Dhall.auto :: Dhall.Type CI.Cfg)
    Manifest -> Dhall.expected (Dhall.auto :: Dhall.Type MI.Manifest)

yamlType :: KnownType -> ByteString
yamlType Cfg = CI.encodeCfg (def :: CI.Cfg)
yamlType Manifest = MI.encodeManifest (def :: MI.Manifest)

sandwich :: Semigroup a => a -> a -> a -> a
sandwich a b x = a <> x <> b

prefix :: FilePath
prefix = "../resources/"

yamlFile :: KnownType -> FilePath
yamlFile = sandwich "yaml/" ".yaml" . show

defaultFile :: KnownType -> FilePath
defaultFile = sandwich "defaults/" ".dhall" . show

typeFile :: KnownType -> FilePath
typeFile = sandwich "types/" ".dhall" . show

getDefault :: KnownType -> Dhall.Expr Dhall.Parser.Src b
getDefault x =
  Dhall.absurd <$> case x of
    Cfg -> embed (injectWith defaultInterpretOptions) (def :: CI.Cfg)
    Manifest -> embed (injectWith defaultInterpretOptions) (def :: MI.Manifest)

generateDefaultConfigurations :: IO ()
generateDefaultConfigurations = do
  putText "Codegen: Dhall types."
  for_ [minBound .. maxBound] $ \t -> do
    let dest = prefix <> typeFile t
    putText $ "  Writing type for " <> show t <> " to " <> toS dest
    createDirectoryIfMissing True (takeDirectory dest)
    writeOutput licenseDhall dest (dhallType t)
  putText "Codegen: Dhall defaults."
  for_ [minBound .. maxBound] $ \defaultType -> do
    let dest = prefix <> defaultFile defaultType
    putStrLn $ "  Writing default for " <> show defaultType <> " to " <> dest <> "."
    createDirectoryIfMissing True (takeDirectory dest)
    writeOutput licenseDhall dest (Lint.lint $ getDefault defaultType)
  putText "Codegen: YAMl example files."
  for_ [minBound .. maxBound] $ \t -> do
    let yaml = yamlType t
        dest = prefix <> yamlFile t
    putText $ "  Writing yaml for " <> show t <> " to " <> toS dest
    createDirectoryIfMissing True (takeDirectory dest)
    writeFile dest $ licenseYaml <> toS yaml
