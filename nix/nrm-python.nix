{ stdenv, python3Packages, hwloc, linuxPackages, nrm-core }:
python3Packages.buildPythonPackage {
  src = ../.;
  name = "nrm-python";
  buildInputs = [ nrm-core ];
  propagatedBuildInputs = [
    nrm-core
    linuxPackages.perf
    python3Packages.tornado
    python3Packages.pyzmq
    python3Packages.pyyaml
    python3Packages.jsonschema
    python3Packages.msgpack
    python3Packages.warlock
  ];
  preBuild = ''
    substituteInPlace bin/nrmd \
      --replace "os.environ[\"NRMSO\"]" \"${nrm-core}/lib/ghc-8.6.5/libnrm-core.so\"
    substituteInPlace nrm/tooling.py \
      --replace "os.environ.get(\"PYNRMSO\")" \"${nrm-core}/lib/ghc-8.6.5/libnrm-core-python.so\" '';
}
