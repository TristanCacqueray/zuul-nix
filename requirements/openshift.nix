{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "openshift";
  version = "0.11.2";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "1z3sq6gsg2kq10lgg6v5wrbm2q99xrnv42hmzpq00dd8hhy0s2qi";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [
    setuptools_scm
    jinja2
    (import ./kubernetes.nix { inherit python3Packages; })
    six
    ruamel_yaml
    (import ./python-string-utils.nix { inherit python3Packages; })
  ];
}
