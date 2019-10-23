let prelude = ./dhall/dhall-to-cabal/prelude.dhall

let types = ./dhall/dhall-to-cabal/types.dhall

let common = ./dhall/common.dhall

in  \(ghcPath:Text)  -> \(ghcNumericVersion:Text) -> prelude.defaults.Package
    ⫽ { name =
          "hsnrm"
      , version =
          prelude.v "1.0.0"
      , author =
          "Valentin Reis"
      , build-type =
          Some types.BuildType.Simple
      , cabal-version =
          prelude.v "2.0"
      , category =
          "tools"
      , description =
          "The Node Resource Manager(NRM) is a linux daemon that enables dynamic resource optimization for improving the power/performance tradeoff of HPC applications."
      , executables =
          [ { executable =
                  λ(config : types.Config)
                →   prelude.defaults.Executable
                  ⫽ { main-is =
                        "Export.hs"
                    , build-depends =
                        [common.nobound "nrmlib", common.deps.base, common.deps.protolude]
                    , hs-source-dirs =
                        [ "bin" ]
                    }
                  ⫽ common.copts
                    [ "-Wmissed-specialisations"
                    , "-Wall-missed-specialisations"
                    , "-fPIC"
                    , "-shared"
                    , "-no-hs-main"
                    , "-dynamic"
            , "-lHSrts-ghc" ++ ghcNumericVersion
            , "-L" ++ ghcPath ++ "/lib/ghc-" ++ ghcNumericVersion ++ "/rts/"
                    ]
            , name =
                "nrm.so"
            }
          , { executable =
                  λ(config : types.Config)
                →   prelude.defaults.Executable
                  ⫽ { main-is =
                        "Hnrm.hs"
                    , build-depends =
                        [common.nobound "nrmlib"]
                    , hs-source-dirs =
                        [ "bin" ]
                    }
                  ⫽ common.copts [ "-main-is", "Hnrm" ]
            , name =
                "nrmstatic"
            }
          , { executable =
                  λ(config : types.Config)
                →   prelude.defaults.Executable
                  ⫽ { main-is =
                        "bin/Hnrm.hs"
                    , build-depends =
                        [ common.nobound "nrmlib" ]
                    }
                  ⫽ common.copts [ "-main-is", "Hnrm" ]
            , name =
                "nrm"
            }
          , { executable =
                  λ(config : types.Config)
                →   prelude.defaults.Executable
                  ⫽ { main-is =
                        "bin/Hnrmd.hs"
                    , build-depends =
                        [ common.nobound "nrmlib" ]
                    }
                  ⫽ common.copts [ "-main-is", "Hnrmd" ]
            , name =
                "fake-daemon"
            }
          , { executable =
                  λ(config : types.Config)
                →   prelude.defaults.Executable
                  ⫽ { main-is =
                        "bin/Codegen.hs"
                    , build-depends =
                        [ common.nobound "nrmlib" ]
                    }
                  ⫽ common.copts [ "-main-is", "Codegen" ]
            , name =
                "codegen"
            }
          ]
      , extra-source-files =
          [ "ChangeLog.md" ]
      , license =
          types.License.BSD3
      , license-files =
          [] : List Text
      , maintainer =
          "fre@freux.fr"
      , source-repos =
          [   prelude.defaults.SourceRepo
            ⫽ { type =
                  Some types.RepoType.Git
              , location =
                  Some "https://xgitlab.cels.anl.gov/vreis/hsnrm.git"
              }
          ]
      , synopsis =
          "hsnrm"
      }