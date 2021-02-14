{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "python-string-utils";
  version = "1.0.0";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "1jy0z9b04ihlxccnwp50ahxpz01zn348sh03lv04fxph0c5hdyfw";
  };
  doCheck = false;
}
