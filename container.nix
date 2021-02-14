{ nixpkgs ? import ./nixpkgs.nix }:
let
  zuul = nixpkgs.callPackage ./zuul.nix {
    python3Packages = nixpkgs.python38Packages;
    which = nixpkgs.which;
  };
in nixpkgs.dockerTools.buildLayeredImage {
  name = "zuul";
  contents = [zuul];
}
