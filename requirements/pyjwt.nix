{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "PyJWT";
  version = "2.0.1";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "1xwvysyamnp07zxbkcm83kg383nk1gam1kgf4ppq2ggkw430mix5";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages;
    [

    ];
}
