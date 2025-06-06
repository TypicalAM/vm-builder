{
  description = "VM image flake using standard config";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      guestConfigFile = pkgs.writeText "config-for-image.nix" ''
        { config, pkgs, lib, ... }: {
          imports = [
            ./boot-config.nix
            ./machine-config.nix
            <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
          ];
        }
      '';

      evaluated = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./boot-config.nix
          ./machine-config.nix
          <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
        ];
      };

      emulationPackageNames = [
        "SDL2_image"
        "alsa-lib"
        "alsa-topology-conf"
        "alsa-ucm-conf"
        "appstream"
        "ayatana-ido"
        "bluez"
        "busybox"
        "canokey-qemu"
        "capstone"
        "cdparanoia"
        "celt"
        "chromaprint"
        "cjson"
        "dtc"
        "e2fsprogs"
        "ell"
        "faad2"
        "fdk_aac"
        "ffado"
        "ffmpeg-headless"
        "flite"
        "fluidsynth"
        "freepats"
        "game-music-emu"
        "gfxstream"
        "glibmm"
        "gnum4"
        "graphene"
        "gsm"
        "gssdp"
        "gtk4"
        "gupnp"
        "gupnp-igd"
        "jq"
        "lcevcdec"
        "ldacbt"
        "libadwaita"
        "libajantv2"
        "libao"
        "libass"
        "libavc1394"
        "libayatana-appindicator"
        "libayatana-indicator"
        "libbluray"
        "libbs2b"
        "libcacard"
        "libcamera"
        "libcanberra"
        "libconfig"
        "libdbusmenu-gtk3"
        "libdc1394"
        "libdecor"
        "libdrm"
        "libdv"
        "libdvdcss"
        "libdvdnav"
        "libdvdread"
        "libebur128"
        "libfreeaptx"
        "libgudev"
        "libical"
        "libiec61883"
        "libiscsi"
        "libjack2"
        "liblc3"
        "libmad"
        "libmodplug"
        "libmysofa"
        "libnice"
        "libopenmpt"
        "libraw1394"
        "librist"
        "libsamplerate"
        "libssh"
        "libtheora"
        "liburing"
        "libva"
        "libva-minimal"
        "libvpx"
        "libxmlb"
        "libyaml"
        "lilv"
        "lkl"
        "lrdf"
        "lttng-ust"
        "mbedtls"
        "mpg123"
        "neon"
        "nspr"
        "nss"
        "openfec"
        "openh264"
        "opusfile"
        "orc"
        "parted"
        "pipewire"
        "qemu-utils"
        "roc-toolkit"
        "rtmpdump"
        "rutabaga_gfx"
        "e2fsprogs"
        "file"
        "gnu-config"
        "gnumake"
        "jq"
        "patchelf"
        "qemu"
        "snappy"
        "spice"
        "stdenv"
        "updateAutotoolsGnuConfigScriptsHook"
        "usbredir"
        "util-linux"
        "vde2"
        "virglrenderer"
        "virtiofsd"
        "vte"
        "wolfssl"
      ];

      vmEmulationPackageList = pkgs.symlinkJoin {
        name = "packageSet";
        paths = map (name: pkgs.${name}) emulationPackageNames;
      };
    in {
      nixosConfigurations.default = evaluated;

      packages.${system} = {
        emulationPackages = vmEmulationPackageList;
        vmImage = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit lib;
          config = evaluated.config;
          configFile = guestConfigFile;
          pkgs = pkgs;
          format = "qcow2-compressed";
          diskSize = "20480";
          contents = [
            {
              source = ./boot-config.nix;
              target = "/etc/nixos/boot-config.nix";
              mode = "0644";
            }
            {
              source = ./machine-config.nix;
              target = "/etc/nixos/machine-config.nix";
              mode = "0644";
            }
          ];
        };
      };
    };
}
