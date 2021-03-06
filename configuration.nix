{ config, lib, ... }:
let
  # Set to false to actually run ansible
  disable-ansible = true;

  nixpkgs = import ./nixpkgs.nix;
  pythonPackages = nixpkgs.python38Packages;
  python = nixpkgs.buildEnv {
    name = "python-setuptools";
    paths = [
      (nixpkgs.python38.withPackages
        (ps: with ps; [ setuptools paho-mqtt requests ]))
    ];
  };
  benchmark = nixpkgs.writeScriptBin "benchmark" (''
    #!${python}/bin/python
  '' + builtins.readFile ./benchmark.py);

  zuul = (import ./zuul.nix {
    which = nixpkgs.which;
    python3Packages = pythonPackages;
  });
  nodepool = (import ./nodepool.nix { python3Packages = pythonPackages; });
  zuul-gateway =
    (import ./zuul-gateway.nix { python3Packages = pythonPackages; });

  mkSystemd = user: name: exec: path:
    let prog = user + "-" + name;
    in {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "zuul-setup.service" ];
      description = "Start " + prog + " service.";
      enable = true;
      path = path;
      serviceConfig = {
        Type = "simple";
        User = user;
        ExecStart = exec;
      };
    };

  mkUser = user: {
    isNormalUser = true;
    home = "/var/lib/" + user;
    description = user + " service account";
  };

  install-ansible = if disable-ansible then ''
    cat << EOF > /var/ansible/$version/bin/$(basename $tool)
    #!/bin/sh
    exit 0
    EOF
    chmod +x /var/ansible/$version/bin/$(basename $tool)
  '' else
    "ln -sf $tool /var/ansible/$version/bin/";

  setupScript = ''
    #!/bin/bash
    export HOME=/root
    mkdir -p /var/lib/zuul/.ssh /var/lib/zuul-worker/.ssh /var/lib/nodepool/.ssh /var/git/zuul-config
    ${nixpkgs.openssh}/bin/ssh-keygen -t rsa -N "" -f /var/lib/zuul/.ssh/id_rsa || :
    ${nixpkgs.openssh}/bin/ssh-keygen -t rsa -N "" -f /var/lib/nodepool/.ssh/id_rsa || :
    cp /var/lib/nodepool/.ssh/id_rsa.pub /var/lib/zuul-worker/.ssh/authorized_keys
    cat /var/lib/zuul/.ssh/id_rsa.pub >> /var/lib/zuul-worker/.ssh/authorized_keys
    chown -R zuul /var/lib/zuul
    chown -R zuul-worker /var/lib/zuul-worker
    chown -R nodepool /var/lib/nodepool
    chmod 0700 /var/lib/{zuul,zuul-worker,nodepool}/.ssh
    chmod 0600 /var/lib/zuul-worker/.ssh/authorized_keys

    echo "Fixup bwrap usage"
    ln -sf /run/current-system/sw/lib /
    ln -sf /run/current-system/sw/sbin /
    touch /etc/ld.so.cache
    ln -s ${nixpkgs.tzdata}/share/zoneinfo/UTC /etc/localtime

    echo "Setup zuul-config"
    ${nixpkgs.git}/bin/git config --global user.name "John Doe"
    ${nixpkgs.git}/bin/git config --global user.email "john@localhost"
    pushd /var/git/zuul-config
      ${nixpkgs.git}/bin/git init . || :
      cp /etc/zuul/config.yaml .zuul.yaml
      cp /etc/zuul/job.yaml job.yaml
      ${nixpkgs.git}/bin/git add .zuul.yaml job.yaml
      ${nixpkgs.git}/bin/git commit -m"Init zuul-config" || :
    popd

    echo "Setup fake zuul ansible"
    for version in 2.8 2.9; do
      mkdir -p /var/ansible/$version/bin
      for tool in $(ls ${nixpkgs.ansible_2_9}/bin/*); do
          ${install-ansible}
      done
      ln -sf ${nixpkgs.ansible_2_9}/lib/ /var/ansible/$version/
      ln -sf ${python}/bin/python /var/ansible/$version/bin/
      echo home = ./bin/ > /var/ansible/$version/pyvenv.cfg
      echo include-system-site-packages = true >> /var/ansible/$version/pyvenv.cfg
    done

    echo "Zuul is ready to run!"
  '';

  zuul-project-config = ''
    - pipeline:
        name: check
        manager: independent
        trigger:
          virtual:
            - event: pg_pull_request
              action:
                - opened
        start:
          mqtt:
            topic: "zuul/"
        success:
          sqlreporter:
          mqtt:
            topic: "zuul/"
        failure:
          sqlreporter:
          mqtt:
            topic: "zuul/"

    - job:
        name: zuul-job
        description: Minimal working job
        parent: null
        nodeset:
          nodes:
            - name: local
              label: local
        run: job.yaml

    - project:
        name: gateway
        check:
          jobs:
            - zuul-job
  '';

  zuul-job = ''
    - hosts: all
      tasks:
        - name: List working directory
          command: /run/current-system/sw/bin/ls -la
  '';

  zuul-conf = ''
    [gearman]
    server=127.0.0.1

    [zookeeper]
    hosts=127.0.0.1:2181

    [gearman_server]
    start=true

    [scheduler]
    tenant_config=/etc/zuul/main.yaml

    [statsd]
    server=localhost

    [executor]
    manage_ansible=false
    ansible_root=/var/ansible
    trusted_ro_paths=/nix
    untrusted_ro_paths=/nix
    load_multiplier=10.0

    [connection sqlreporter]
    driver=sql
    dburi=postgresql://postgres:mypassword@127.0.0.1:5432/zuul

    [connection mqtt]
    driver=mqtt
    server=localhost
    user=zuul
    password=secret

    [connection git]
    driver=git
    baseurl=git://localhost:9418/

    [connection virtual]
    driver=pagure
    server=localhost:5000
    baseurl=http://localhost:5000
  '';

  zuul-tenant = ''
    - tenant:
        name: default
        source:
          git:
            config-projects:
              - zuul-config
          virtual:
            untrusted-projects:
              - gateway
  '';

  nodepool-conf = ''
    zookeeper-servers:
    - host: localhost
      port: 2181

    labels:
      - name: local

    providers:
      - name: static-provider
        driver: static
        pools:
          - name: main
            nodes:
              - name: localhost
                labels: local
                username: zuul-worker
                max-parallel-jobs: 42
                host-key-checking: false
                python-path: ${python}/bin/python
  '';

in {
  imports = [
    # ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/vda";

  networking.hostName = "zuul-integration";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  services.postgresql.enable = true;
  services.postgresql.enableTCPIP = true;
  services.postgresql.authentication = nixpkgs.lib.mkOverride 10 ''
    local all all trust
    host all all 127.0.0.1/32 trust
  '';
  services.postgresql.ensureDatabases = [ "zuul" ];
  services.zookeeper.enable = true;
  services.gitDaemon.enable = true;
  services.gitDaemon.basePath = "/var/git";
  services.gitDaemon.exportAll = true;
  #  services.gerrit.serverId = "f6993d9c-6de6-4d33-be20-c81f4d182eed";
  #  services.gerrit.enable = true;

  # mqtt server
  services.mosquitto.enable = true;
  services.mosquitto.users.zuul.password = "secret";
  services.mosquitto.users.zuul.acl = [ "topic readwrite zuul/#" ];
  services.mosquitto.allowAnonymous = true;
  # mqtt client
  systemd.services.mosquitto_sub = {
    wantedBy = [ "multi-user.target" ];
    after = [ "mosquitto.service" ];
    description = "An mqtt client to dump event";
    enable = true;
    serviceConfig.Type = "simple";
    serviceConfig.ExecStart =
      "${nixpkgs.mosquitto}/bin/mosquitto_sub -t '#' -u zuul";
  };

  users.users.zuul = mkUser "zuul";
  users.users.zuul-worker = mkUser "zuul-worker";
  users.users.nodepool = mkUser "nodepool";

  # zuul services
  systemd.services.nodepool-launcher =
    mkSystemd "nodepool" "launcher" "${nodepool}/bin/nodepool-launcher -d" [ ];
  systemd.services.zuul-scheduler =
    mkSystemd "zuul" "scheduler" "${zuul}/bin/zuul-scheduler -df" [ ];
  systemd.services.zuul-merger =
    mkSystemd "zuul" "merger" "${zuul}/bin/zuul-merger -df" [
      nixpkgs.git
      nixpkgs.openssh
    ];
  systemd.services.zuul-executor =
    mkSystemd "zuul" "executor" "${zuul}/bin/zuul-executor -df" [
      nixpkgs.git
      nixpkgs.openssh
      nixpkgs.bubblewrap
    ];
  systemd.services.zuul-web =
    mkSystemd "zuul" "web" "${zuul}/bin/zuul-web -f" [ ];

  # configuration service
  systemd.services.zuul-setup = {
    script = setupScript;
    before = [
      "zuul-scheduler.service"
      "nodepool-launcher.service"
      "zuul-merger.service"
      "zuul-executor.service"
      "zuul-web.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
  };
  systemd.services.zuul-gateway = {
    wantedBy = [ "multi-user.target" ];
    description = "A service to inject zuul event";
    enable = true;
    serviceConfig.Type = "simple";
    serviceConfig.ExecStart = "${zuul-gateway}/bin/zuul-gateway";
  };

  # configuration
  environment.etc."zuul/zuul.conf".text = zuul-conf;
  environment.etc."zuul/main.yaml".text = zuul-tenant;
  environment.etc."zuul/config.yaml".text = zuul-project-config;
  environment.etc."zuul/job.yaml".text = zuul-job;
  environment.etc."nodepool/nodepool.yaml".text = nodepool-conf;

  environment.systemPackages = with nixpkgs; [
    nodepool
    zuul
    htop
    git
    benchmark
  ];

  users.mutableUsers = false;
  users.users.root.password = "";
  services.openssh.extraConfig = ''
    PermitEmptyPasswords yes
  '';
  services.getty.helpLine = ''
    Welcome to the zuul-integration vm.
    Log in as "root" with an empty password.
    If you are connect via serial console:
    Type Ctrl-a c to switch to the qemu console
    and `quit` to stop the VM.

    Once logged in, type `benchmark`.
  '';
  system.stateVersion = "20.09";
}
