{ config, lib, ... }:
let
  nixpkgs = import ./nixpkgs.nix;
  zuul = (import ./zuul.nix {
    which = nixpkgs.which;
    python3Packages = nixpkgs.python38Packages;
  });
  nodepool =
    (import ./nodepool.nix { python3Packages = nixpkgs.python38Packages; });

  mkSystemd = user: name: args:
    let prog = user + "-" + name;
    in {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "Start " + prog + " service.";
      enable = false;
      serviceConfig = {
        Type = "simple";
        User = user;
        ExecStart = prog + args;
      };
    };
in {
  imports = [
    # ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/vda";

  networking.hostName = "vm1";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  services.postgresql.enable = true;
  services.zookeeper.enable = true;
  services.gerrit.serverId = "f6993d9c-6de6-4d33-be20-c81f4d182eed";
  services.gerrit.enable = true;

  # zuul services
  systemd.services.nodepool-launcher = mkSystemd "nodepool" "launcher" "-d";
  systemd.services.zuul-scheduler = mkSystemd "zuul" "scheduler" "-f";
  systemd.services.zuul-executor = mkSystemd "zuul" "executor" "-f";
  systemd.services.zuul-web = mkSystemd "zuul" "web" "-f";

  environment.systemPackages = with nixpkgs; [ nodepool zuul htop ];

  users.mutableUsers = false;
  users.users.root.password = "";
  services.openssh.extraConfig = ''
    PermitEmptyPasswords yes
  '';
  system.stateVersion = "20.09";
}
