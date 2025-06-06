{ config, pkgs, ... }:

{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  boot = {
    growPartition = true;
    kernelParams = [ "console=ttyS0" ];
    loader.grub.device = "/dev/vda";
    loader.timeout = 0;
  };
}
