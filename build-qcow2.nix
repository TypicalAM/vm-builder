{ config, lib, pkgs, system, ... }:

#let
  # evaled = import <nixpkgs/nixos> {
  #   inherit system;
  #   configuration = { config, pkgs, ... }: {
  #     # imports = [
  #     #   #<nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  #     #   #/tmp/machine-config.nix
  #     # ];
  #
  #
  #   };
  # };
  #
#in
{
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
        autoResize = true;
      };

      boot.growPartition = true;
      boot.kernelParams = [ "console=ttyS0" ];
      boot.loader.grub.device = "/dev/vda";
      boot.loader.timeout = 0;
  # imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix> ];
  #
  # system.build.qcow2 = import <nixpkgs/nixos/lib/make-disk-image.nix> {
  #   inherit lib;
  #   config = evaled.config;
  #   pkgs = import <nixpkgs> {
  #     inherit (pkgs) system;
  #   }; # ensure we use the regular qemu-kvm package
  #   diskSize = 8192;
  #   format = "qcow2";
  #   # configFile = pkgs.writeText "configuration.nix" "{ imports = [ /tmp/machine-config.nix ]; }";
  # };
}
