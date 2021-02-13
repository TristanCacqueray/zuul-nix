{ nixpkgs ? import ./nixpkgs.nix }:

let
  zuul = nixpkgs.callPackage ./zuul.nix {
    python3Packages = nixpkgs.python38Packages;
    which = nixpkgs.which;
  };
  shell = nixpkgs.mkShell { nativeBuildInputs = [ zuul ]; };
in if nixpkgs.lib.inNixShell then shell else zuul
