{ config, lib, ... }:
let
  nixpkgs = import ./nixpkgs.nix;
  zuul = (import ./zuul.nix {
    which = nixpkgs.which;
    python3Packages = nixpkgs.python38Packages;
  });
  nodepool =
    (import ./nodepool.nix { python3Packages = nixpkgs.python38Packages; });

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

  setupScript = ''
    #!/bin/bash
    export HOME=/root
    mkdir -p /var/lib/zuul/.ssh /var/lib/zuul-worker/.ssh /var/lib/nodepool/.ssh /var/git/zuul-config
    ${nixpkgs.openssh}/bin/ssh-keygen -t rsa -N "" -f /var/lib/zuul/.ssh/id_rsa || :
    ${nixpkgs.openssh}/bin/ssh-keygen -t rsa -N "" -f /var/lib/nodepool/.ssh/id_rsa || :
    cp /var/lib/nodepool/.ssh/id_rsa.pub /var/lib/zuul-worker/.ssh/authorized_keys
    chown -R zuul /var/lib/zuul
    chown -R zuul-worker /var/lib/zuul-worker
    chown -R nodepool /var/lib/nodepool
    chmod 0700 /var/lib/{zuul,zuul-worker,nodepool}/.ssh
    chmod 0600 /var/lib/zuul-worker/.ssh/authorized_keys
    ${nixpkgs.git}/bin/git config --global user.name "John Doe"
    ${nixpkgs.git}/bin/git config --global user.email "john@localhost"
    pushd /var/git/zuul-config
      ${nixpkgs.git}/bin/git init . || :
      cp /etc/zuul/config.yaml .zuul.yaml
      cp /etc/zuul/job.yaml job.yaml
      ${nixpkgs.git}/bin/git add .zuul.yaml job.yaml
      ${nixpkgs.git}/bin/git commit -m"Init zuul-config" || :
      echo "Zuul is ready to run!"
    popd
  '';

  zuul-project-config = ''
    - pipeline:
        name: periodic
        post-review: true
        description: Jobs in this queue are triggered every minute.
        manager: independent
        precedence: low
        trigger:
          timer:
            - time: '* * * * *'
        success:
          sqlreporter:
        failure:
          sqlreporter:

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
        periodic:
          jobs:
            - zuul-job
  '';

  zuul-job = ''
    - hosts: localhost
      tasks:
        - name: List working directory
          command: ls -al {{ ansible_user_dir }}
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

    [connection sqlreporter]
    driver=sql
    dburi=postgresql://postgres:mypassword@127.0.0.1:5432/zuul

    [connection git]
    driver=git
    baseurl=git://localhost:9418/
  '';

  init-pg = ''
    ALTER USER postgres WITH PASSWORD 'mypassword';
    CREATE DATABASE zuul;
    GRANT ALL PRIVILEGES ON DATABASE zuul TO postgres;
  '';

  zuul-tenant = ''
    - tenant:
        name: default
        source:
          git:
            config-projects:
              - zuul-config
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
  services.zookeeper.enable = true;
  services.gitDaemon.enable = true;
  services.gitDaemon.basePath = "/var/git";
  services.gitDaemon.exportAll = true;
  #  services.gerrit.serverId = "f6993d9c-6de6-4d33-be20-c81f4d182eed";
  #  services.gerrit.enable = true;

  users.users.zuul = mkUser "zuul";
  users.users.zuul-worker = mkUser "zuul-worker";
  users.users.nodepool = mkUser "nodepool";

  # zuul services
  systemd.services.nodepool-launcher =
    mkSystemd "nodepool" "launcher" "${nodepool}/bin/nodepool-launcher -d" [ ];
  systemd.services.zuul-scheduler =
    mkSystemd "zuul" "scheduler" "${zuul}/bin/zuul-scheduler -f" [ ];
  systemd.services.zuul-merger =
    mkSystemd "zuul" "merger" "${zuul}/bin/zuul-merger -f" [
      nixpkgs.git
      nixpkgs.openssh
    ];
  systemd.services.zuul-executor =
    mkSystemd "zuul" "executor" "${zuul}/bin/zuul-executor -f" [
      nixpkgs.git
      nixpkgs.openssh
    ];
  systemd.services.zuul-web =
    mkSystemd "zuul" "web" "${zuul}/bin/zuul-web -f" [ ];

  # configuration service
  systemd.services.zuul-setup = {
    script = setupScript;
    wantedBy = [ "multi-user.target" ];
  };

  # configuration
  environment.etc."zuul/zuul.conf".text = zuul-conf;
  environment.etc."zuul/main.yaml".text = zuul-tenant;
  environment.etc."zuul/config.yaml".text = zuul-project-config;
  environment.etc."zuul/job.yaml".text = zuul-job;
  environment.etc."nodepool/nodepool.yaml".text = nodepool-conf;

  environment.systemPackages = with nixpkgs; [ nodepool zuul htop git ];

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
  '';
  system.stateVersion = "20.09";
}
