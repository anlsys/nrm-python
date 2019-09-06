{-# OPTIONS_GHC -fno-warn-orphans #-}
{-|
Module      : NRM.Manifest.Examples
Copyright   : (c) 2019, UChicago Argonne, LLC.
License     : BSD3
Maintainer  : fre@freux.fr
-}
module NRM.Manifest.Examples
  (
  )
where

import Data.Default
import Data.Map
import NRM.Classes.Examples
import NRM.Types.Manifest
import NRM.Types.Units as U

instance Examples Manifest where

  examples =
    fromList
      [ ( "perfwrap"
        , def
          { app = def {perfwrapper = Perfwrapper {perfFreq = U.hz 1}}
          }
        )
      ]
