{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "keystoneauth1";
  version = "4.3.0";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "1wb3a6aphajkzxwnha5qkkyr3ibl7ngmkzp379slsbh8iysmbyp3";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [
    pbr
    iso8601
    requests
    six
    stevedore
    (import ./os-service-types.nix { inherit python3Packages; })
  ];
}
