{ configuration, system ? builtins.currentSystem }:

rec {
  vmConfig = (import <nixpkgs/nixos/lib/eval-config.nix> {
    inherit system;
    modules = [
      configuration
      <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
      ({ config, pkgs, ... }: {
        virtualisation = {
          memorySize = 8192;
          diskSize = 10000;
          cores = 8;
        };
      })
    ];
  }).config;
  vmSystem = vmConfig.system.build.toplevel;
  vm = vmConfig.system.build.vm;
}
