{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "diskimage-builder";
  version = "3.7.0";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "105rrr56mg1sx763ggd8k5hfw18dicd4y9cz8446xwh19pw37q63";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [
    pbr
    pyyaml
    stevedore
    flake8
    networkx
  ];
}
