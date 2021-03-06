let tags = [ "nix", "kvm" ]

let baseJob =
        λ(stage : Text)
      → λ(script : Text)
      → { stage = stage, tags = tags, script = script }

let mkJob =
        λ(stage : Text)
      → λ(target : Text)
      → baseJob stage ("nix-shell -p gnumake --run 'make " ++ target ++ "'")

let mkNix =
        λ(stage : Text)
      → λ(target : Text)
      → baseJob "build" ("nix-build -A " ++ target ++ " --no-build-output")

let mkS = mkJob "source"

let mkB = mkJob "build"

let mkT = mkJob "test"

let mkNixB = mkNix "build"

in  { stages = [ "source", "build", "test", "deploy" ]
    , nix/hsnrm-bin = mkNixB "haskellPackages.hsnrm-bin"
    , nix/hsnrm = mkNixB "haskellPackages.hsnrm"
    , nix/pynrm = mkNixB "pythonPackages.pynrm"
    , nix/libnrm = mkNixB "libnrm"
    , nix/stream = mkNixB "stream"
    , tests/kvm = mkT "tests-kvm"
    , tests/pyupstream = mkT "tests-pyupstream"
    , tests/apps = mkT "app-tests"
    , tests/rapl = mkT "tests-rapl" ⫽ { tags = [ "chimera" ] }
    , tests/perf = mkT "tests-perf" ⫽ { tags = [ "chimera" ] }
    , examples = mkT "examples"
    , libnrm/autotools = mkB "libnrm/autotools"
    , hsnrm/all = mkB "hsnrm/all"
    , resources = mkS "resources"
    , shellcheck = mkS "shellcheck"
    , nixfmt = mkS "nixfmt"
    , dhall-format = mkS "dhall-format"
    , libnrm/clang-format = mkS "libnrm/clang-format"
    , pynrm/black = mkS "pynrm/black"
    , hsnrm/ormolu = mkS "hsnrm/ormolu"
    , hsnrm/hlint = mkS "hsnrm/hlint"
    , hsnrm/shellcheck = mkS "hsnrm/shellcheck"
    , hsnrm-/dhall-format = mkS "hsnrm/dhall-format"
    , readthedocs =
        { stage = "deploy"
        , tags = tags
        , only = [ "master" ]
        , script =
          [ "echo \"token=\$RTD_TOKEN\""
          , "nix run nixpkgs.curl -c curl --fail -X POST -d \"token=\$RTD_TOKEN\" readthedocs.org/api/v2/webhook/hnrm/104604/"
          ]
        }
    }
