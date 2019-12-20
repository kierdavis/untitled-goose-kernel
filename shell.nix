with import ./default.nix;

nixpkgs.mkShell {
  buildInputs = [
    rustc
    cargo
    cargo-xbuild
  ];
}
