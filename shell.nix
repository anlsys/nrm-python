# development shell, includes aml dependencies and dev-related helpers
{ pkgs ? import ./. { } }:
with pkgs;
mkShell {
  inputsFrom = [ nrm-core nrm-python ];
  nativeBuildInputs = [ ];
  buildInputs = [
    python3Packages.poetry
    python3Packages.flake8
    hwloc
    linuxPackages.perf
  ];
  shellHook = let pwd = builtins.toPath ./.;
  in ''
    export NRMSO=${nrm-core}/lib/ghc-8.6.5/libnrm-core.so
    export PYNRMSO=${nrm-core}/lib/ghc-8.6.5/libnrm-core-python.so
    export PYTHONPATH=${pwd}:$PYTHONPATH
    export PATH=${pwd}/bin:$PATH
  '';
}
