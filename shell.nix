with import ./default.nix;

nixpkgs.mkShell {
  buildInputs = [
    cargo
  ];
}
