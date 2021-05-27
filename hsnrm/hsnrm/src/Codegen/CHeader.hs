{-# LANGUAGE ScopedTypeVariables #-}

-- |
-- Module      : Codegen.CHeader
-- Copyright   : (c) 2019, UChicago Argonne, LLC.
-- License     : MIT
-- Maintainer  : fre@freux.fr
module Codegen.CHeader
  ( toCHeader,
  )
where

{-import Data.JSON.Schema.Generator as G-}

import Data.Aeson as A
import Data.Aeson.Types as AT
import qualified Data.HashMap.Strict as H
import qualified Data.JSON.Schema as S
import Data.String (fromString)
import Data.Text (replace, toUpper)
import qualified Data.Vector as V (fromList)
import qualified NRM.Classes.Messaging as M
import Protolude hiding (Any)

toCHeader :: (M.NRMMessage a) => Proxy a -> Text
toCHeader = replld . repd . toHeader . goToplevel . M.messageSchema
  where
    repd = Data.Text.replace "\\\"%d\\\"" "%d"
    replld = Data.Text.replace "\\\"%lld\\\"" "%lld"

-- | takes a list of (msgtype, json object) in to #define printf format string
-- to add to a C header.
--
-- Because this generator is only used on the downstreamEvent schema, we bypass
-- the difficulty of the top-level object and only expect to receive the schema
-- matching the part that is message type specific.
toHeader :: [(Text, AT.Value)] -> Text
toHeader h =
  mconcat . intersperse "\n" $
    h <&> \(msgname, khl) ->
      "#define NRM_"
        <> toUpper msgname
        <> "_FORMAT "
        <> show
          ( A.encode
              ( AT.Object $
                  H.fromList
                    [ ("timestamp", "%lld"),
                      ("info", AT.Object $ H.singleton msgname khl)
                    ]
              )
          )

-- | Convert a JSON schema into an Aeson JSON object were all the values
-- required in a message are replaced by their C printf encoding.
--
-- With special logic to bypass the top-level object of the downstreamEvent
-- schema: an object with exactly two fields (timestamp, info) that needs to
-- disappear from the result. Since info is a Choice and all the other objects
-- only have one field, the bypass is pretty straightforward
goToplevel :: S.Schema -> [(Text, AT.Value)]
goToplevel (S.Object [_, (S.Field _ _ content)]) = goToplevel content
goToplevel (S.Choice schemas) = mconcat $ goToplevel <$> schemas
goToplevel (S.Object [(S.Field key _ content)]) = [(key, go content)]
goToplevel s = panic . fromString $ "schema first level malformed: " ++ show s

go :: S.Schema -> AT.Value
go (S.Tuple schemas) = AT.Array (V.fromList $ go <$> schemas)
go (S.Object fields) = AT.Object . H.fromList $
  fields <&> \(S.Field key _ content) -> (key, go content)
go (S.Value _) = "%s"
go (S.Number _) = AT.String "%d"
go s = panic . fromString $ "error: unallowed in message format: " ++ show s
