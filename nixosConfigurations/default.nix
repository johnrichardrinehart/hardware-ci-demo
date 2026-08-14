{ lib, pkgs, ... }:

{
  networking = {
    useDHCP = lib.mkDefault true;
    firewall.allowedTCPPorts = [ 22 ];
  };
  documentation = {
    enable = false;
    doc.enable = false;
    man.enable = false;
  };
  environment.systemPackages = lib.mkForce [
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.systemd
    pkgs.util-linux
  ];
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  };
  hardware = {
    alsa.enable = false;
    enableAllHardware = lib.mkForce false;
  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      UsePAM = true;
    };
  };
  users = {
    mutableUsers = false;
    users.demo = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      password = "demo";
    };
  };
  system.stateVersion = "25.11";
}
