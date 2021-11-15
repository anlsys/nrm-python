{ pkgs ?  import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/20.03.tar.gz") {}
, nrm-core-pkgs ? import (builtins.fetchTarball "https://github.com/anlsys/nrm-core/archive/refs/tags/v0.7.0.tar.gz") {}
}:
pkgs // rec {
  nrm-core = nrm-core-pkgs.nrm-core;
  libnrm = pkgs.callPackage ./nix/libnrm.nix;
  nrm-python = pkgs.callPackage ./nix/nrm-python.nix {
    inherit nrm-core;
  };
}
