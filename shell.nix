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
  shellHook = ''
    export NRMSO=${nrm-core}/bin/nrm.so
    export PYNRMSO=${nrm-core}/bin/pynrm.so
    export PYTHONPATH=.:$PYTHONPATH
  '';
}
