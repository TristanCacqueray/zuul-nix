{ python3Packages, which }:

python3Packages.buildPythonApplication rec {
  pname = "zuul";
  # A fake v4 version until upstream do the release
  version = "4.0.0";
  PBR_VERSION = version;
  src = builtins.fetchGit {
    url = "https://opendev.org/zuul/zuul.git";
    ref = "master";
    rev = "a397a9a02753a96fe5a04f2b89b7896a2bc8b9a4";

  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [
    pbr
    pathspec
    virtualenv
    which
    dateutil
    github3_py
    pyyaml
    paramiko
    GitPython
    python-daemon
    extras
    statsd
    voluptuous
    psycopg2
    (import ./requirements/prettytable.nix { inherit python3Packages; })
    Babel
    netaddr
    kazoo
    sqlalchemy
    alembic
    cryptography
    cachecontrol
    cachetools
    (import ./requirements/pyjwt.nix { inherit python3Packages; })
    iso8601
    psutil
    fb-re2
    paho-mqtt
    cherrypy
    ws4py
    routes
    jsonpath_rw
    urllib3
    cheroot
    elasticsearch
    (import ./requirements/gear.nix { inherit python3Packages; })
    (import ./requirements/apscheduler.nix { inherit python3Packages; })
  ];
  nativeBuildInputs = [ which ];
  #  buildInputs = with python3Packages; [ pbr pathspec ];
}
