# A pinned nixpkgs
let
  bootstrap = import <nixpkgs> { };
  src = bootstrap.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "2118cf551b9944cfdb929b8ea03556f097dd0381";
    sha256 = "0ajsxh1clbf3q643gi8v6b0i0nn358hak0f265j7c1lrsbxyw457";
  };

in import src { }
