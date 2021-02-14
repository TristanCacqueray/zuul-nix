{ nixpkgs ? import ./nixpkgs.nix }:

let
  zuul = nixpkgs.callPackage ./zuul.nix {
    python3Packages = nixpkgs.python38Packages;
    which = nixpkgs.which;
  };
  nodepool = nixpkgs.callPackage ./nodepool.nix {
    python3Packages = nixpkgs.python38Packages;
  };
  shell = nixpkgs.mkShell { nativeBuildInputs = [ zuul nodepool ]; };
in if nixpkgs.lib.inNixShell then shell else zuul
