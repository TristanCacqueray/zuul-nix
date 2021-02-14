{ python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "kubernetes";
  version = "11.0.0";
  src = python3Packages.fetchPypi {
    inherit pname version;
    sha256 = "0c04ap6dd2wsi0ysb4gpixf5mvdxb7w82ix3wf3smihvn3w7490s";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [
    certifi
    six
    python-dateutil
    setuptools
    pyyaml
    google_auth
    websocket_client
    requests
    requests_oauthlib
    urllib3
  ];
}
