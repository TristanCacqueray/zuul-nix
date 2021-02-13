{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "APScheduler";
  version = "3.7.0";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "0shcj1ygfqpz51dbwd1cw3aiqyibcddiahmh4xqx01z144jpzaqw";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [ setuptools_scm six tzlocal ];
}
