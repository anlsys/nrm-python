{ stdenv, src, resources, autoreconfHook, fetchgit, zeromq, gfortran, pkgconfig
, openmpi, llvmPackages, hsnrm }:
stdenv.mkDerivation {
  inherit src;
  name = "libnrm";
  nativeBuildInputs = [ autoreconfHook pkgconfig openmpi ];
  buildInputs = [ zeromq gfortran openmpi llvmPackages.openmp ];

  configureFlags =
    [ "--enable-pmpi" "CC=mpicc" "FC=mpifort" "CFLAGS=-fopenmp" ];
  preBuild = ''
    rm src/nrm_messaging.h
    cp ${resources}/share/nrm/nrm_messaging.h src/
  '';
}
