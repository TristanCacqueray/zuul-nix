{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "openstacksdk";
  version = "0.53.0";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "00kl8bm4cibnrwx0hjlzi4jla2shb7zsdphhaljxn5y3nfkz401m";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [
    pbr
    pyyaml
    appdirs
    requestsexceptions
    jsonpatch
    (import ./os-service-types.nix { inherit python3Packages; })
    (import ./keystoneauth1.nix { inherit python3Packages; })
    munch
    decorator
    jmespath
    iso8601
    netifaces
    dogpile_cache
    cryptography
  ];
}
