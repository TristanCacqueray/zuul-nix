{ python3Packages }:

python3Packages.buildPythonApplication rec {
  pname = "nodepool";
  # A fake v4 version until upstream do the release
  version = "4.0.0";
  PBR_VERSION = version;
  src = builtins.fetchGit {
    url = "https://opendev.org/zuul/nodepool.git";
    ref = "master";
    rev = "3d9914ab22b2205d9a70b4499e5e35a1a0cf6ed0";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [
    pbr
    six
    pyyaml
    paramiko
    python-daemon
    paste
    extras
    statsd
    (import ./requirements/prettytable.nix { inherit python3Packages; })
    (import ./requirements/openstacksdk.nix { inherit python3Packages; })
    (import ./requirements/diskimage-builder.nix { inherit python3Packages; })
    voluptuous
    kazoo
    webob
    (import ./requirements/openshift.nix { inherit python3Packages; })
    boto3
    google_api_python_client
    azure-mgmt-compute
    azure-mgmt-network
    azure-mgmt-resource
    urllib3
  ];
}
