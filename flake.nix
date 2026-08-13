{
  description = "Minimal NixOS SD-card closures for the hardware CI demo";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    rock5c-nixos = {
      url = "github:johnrichardrinehart/rock5c-nixos";
      # This revision exports ubootRock5ModelC, which the board module needs.
      inputs.nixpkgs.url = "github:nixos/nixpkgs/b098de5018e6e38e7150e75d5be6cb636d6bec7a";
    };
  };

  outputs =
    { nixpkgs, rock5c-nixos, ... }:
    let
      lib = nixpkgs.lib;
      rockNixpkgs = rock5c-nixos.inputs.nixpkgs;
      system = "aarch64-linux";
      maxSdImageBytes = 4 * 1024 * 1024 * 1024;
      sizeCheck = name: image:
        nixpkgs.legacyPackages.x86_64-linux.runCommand "${name}-under-4GiB" {
          inherit image;
        } ''
          image_size=$(stat --format=%s "$image")
          test "$image_size" -le ${toString maxSdImageBytes}
          touch "$out"
        '';
      base = hostname: { lib, pkgs, ... }: {
        networking.hostName = hostname;
        networking.useDHCP = lib.mkDefault true;
        documentation.enable = false;
        documentation.doc.enable = false;
        environment.systemPackages = lib.mkForce [
          pkgs.bashInteractive
          pkgs.coreutils
          pkgs.systemd
          pkgs.util-linux
        ];
        documentation.man.enable = false;
        i18n.defaultLocale = "en_US.UTF-8";
        i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
        hardware.alsa.enable = false;
        hardware.enableAllHardware = lib.mkForce false;
        networking.firewall.allowedTCPPorts = [ 22 ];
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = true;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
            UsePAM = true;
          };
        };
        users.mutableUsers = false;
        users.users.demo = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          password = "demo";
        };
        system.stateVersion = "25.11";
      };
    in
    rec {
      nixosConfigurations = {
        rpi4 = lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            (base "rpi4-ci")
            ({ pkgs, ... }:
            let
              rock5c-power-cycle = pkgs.writeShellApplication {
                name = "rock5c-power-cycle";
                runtimeInputs = [ pkgs.coreutils pkgs.libgpiod ];
                text = ''
                  gpioset --chip gpiochip0 --toggle 8s,0 17=0
                  sleep 2
                  gpioset --chip gpiochip0 --toggle 500ms,0 17=0
                '';
              };
            in
            {
              # Use the upstream Raspberry Pi 4 kernel and mini-UART console.
              boot.kernelPackages = pkgs.linuxPackages_rpi4;
              boot.kernelParams = lib.mkForce [
                "8250.nr_uarts=2"
                "earlycon"
                "console=ttyS1,115200"
                "console=tty1"
              ];
              # Keep the mini-UART clock fixed for the GPIO serial console.
              sdImage.populateFirmwareCommands = lib.mkAfter ''
                chmod u+w firmware/config.txt
                cat >> firmware/config.txt <<'EOF'
                [all]
                core_freq=250
                core_freq_min=250
                EOF
              '';
              systemd.services."serial-getty@ttyS1" = {
                enable = true;
                wantedBy = [ "getty.target" ];
              };
              services.udev.extraRules = ''
                SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
              '';
              users.groups.gpio = { };
              users.users.demo.extraGroups = [ "dialout" "gpio" ];
              environment.systemPackages = lib.mkOverride 40 [
                pkgs.bashInteractive
                pkgs.coreutils
                pkgs.libgpiod
                rock5c-power-cycle
                pkgs.systemd
                pkgs.tio
                pkgs.util-linux
              ];
              sdImage.compressImage = false;
            })
          ];
        };

        rock5c = rockNixpkgs.lib.nixosSystem {
          inherit system;
          pkgs = import rockNixpkgs {
            inherit system;
            overlays = [ rock5c-nixos.overlays.default ];
          };
          modules = [
            rock5c-nixos.nixosModules.rock5c
            rock5c-nixos.nixosModules.rock5c-base
            (base "rock5c-ci")
            {
              rock5c.enable = true;
              fileSystems."/" = {
                device = "/dev/disk/by-label/NIXOS_SD";
                fsType = "ext4";
              };
            }
          ];
        };
      };

      packages.x86_64-linux = {
        rpi4-sd-image = nixosConfigurations.rpi4.config.system.build.sdImage;
        rock5c-sd-image = nixosConfigurations.rock5c.config.system.build.sdImage;
      };

      checks.x86_64-linux = {
        rpi4-sd-image-under-4GiB = sizeCheck "rpi4-sd-image" packages.x86_64-linux.rpi4-sd-image;
        rock5c-sd-image-under-4GiB = sizeCheck "rock5c-sd-image" packages.x86_64-linux.rock5c-sd-image;
      };
    };
}
