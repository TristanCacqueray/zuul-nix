{ python3Packages }:

python3Packages.buildPythonApplication rec {
  pname = "zuul-gateway";
  version = "0.1.0";
  src = builtins.fetchGit {
    url = "https://pagure.io/software-factory/zuul-gateway.git";
    ref = "master";
    rev = "c00396ab21a3af88a3dcdf28920478eada1b472a";
  };
  doCheck = false;
  propagatedBuildInputs = with python3Packages; [ flask requests ];
}
