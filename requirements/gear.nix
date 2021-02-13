{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "gear";
  version = "0.15.1";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "0vgi42bbc4rqx01zz95gzp7zd0rh55vwa4lm8hl2ipdmi7skl1k8";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [
    pbr
    six
    python-daemon
    extras
  ];
}
