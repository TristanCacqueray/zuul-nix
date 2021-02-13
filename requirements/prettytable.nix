{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "prettytable";
  version = "0.7.2";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "1ndckiniasacfqcdafzs04plskrcigk7vxprr2y34jmpkpf60m1d";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages;
    [

    ];
}
