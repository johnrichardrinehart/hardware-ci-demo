{ lib, rock5cNixos, ... }:

let
  rootfsLabel = "ROCK5C_SD";
in
{
  imports = [
    rock5cNixos.nixosModules.rock5c
    rock5cNixos.nixosModules.rock5c-base
  ];

  networking.hostName = "rock5c-ci";
  rock5c = {
    enable = true;
    inherit rootfsLabel;
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/${rootfsLabel}";
    fsType = "ext4";
  };

  boot.kernelParams = lib.mkAfter [ "console=ttyS2,1500000n8" ];
  systemd.services."serial-getty@ttyS2" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };
}
