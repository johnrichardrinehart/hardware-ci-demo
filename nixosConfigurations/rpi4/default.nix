{
  lib,
  modulesPath,
  pkgs,
  ...
}:

let
  rock5c-power-cycle = pkgs.writeShellApplication {
    name = "rock5c-power-cycle";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libgpiod
    ];
    text = ''
      gpioset --chip gpiochip0 --toggle 8s,0 17=0
      sleep 2
      gpioset --chip gpiochip0 --toggle 500ms,0 17=0
    '';
  };
in
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image-aarch64.nix" ];

  networking.hostName = "rpi4-ci";

  # Use the upstream Raspberry Pi 4 kernel and mini-UART console.
  boot.kernelPackages = pkgs.linuxPackages_rpi4;
  boot.kernelParams = lib.mkForce [
    "8250.nr_uarts=1"
    "earlycon"
    "console=ttyS0,115200"
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
  sdImage.compressImage = false;

  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };
  services.udev.extraRules = ''
    SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
  '';
  users.groups.gpio = { };
  users.users.demo.extraGroups = [
    "dialout"
    "gpio"
  ];
  environment.systemPackages = lib.mkOverride 40 [
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.libgpiod
    rock5c-power-cycle
    pkgs.systemd
    pkgs.tio
    pkgs.util-linux
  ];
}
