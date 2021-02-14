{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "os-service-types";
  version = "1.7.0";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "0v4chwr5jykkvkv4w7iaaic7gb06j6ziw7xrjlwkcf92m2ch501i";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [ pbr ];
}
