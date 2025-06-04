{
  description = "VM image flake using standard config";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      bootConfig = { ... }: {
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
      };

      evaluated = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          bootConfig
          /tmp/machine-config.nix
          <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
        ];
      };
    in {
      nixosConfigurations.default = evaluated;

      packages.${system}.vmImage =
        import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit lib;
          config = evaluated.config;
          pkgs = pkgs;
          format = "qcow2-compressed";
          diskSize = "20480M";
        };
    };
}
