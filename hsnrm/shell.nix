with import ./. { };

haskellPackages.shellFor {
  packages = p: [ haskellPackages.hsnrm haskellPackages.hsnrm-extra ];
  withHoogle = true;
  buildInputs = [
    haskellPackages.ghcid
    dhall
    dhall-to-cabal
    cabal2nix
    ormolu
    hlint
    pandoc
    cabal-install
  ];
  shellHook = ''
    export LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive
    export LANG=en_US.UTF-8
  '';
}