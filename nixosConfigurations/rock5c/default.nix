{ rock5cNixos, ... }:

{
  imports = [
    rock5cNixos.nixosModules.rock5c
    rock5cNixos.nixosModules.rock5c-base
  ];

  networking.hostName = "rock5c-ci";
  rock5c.enable = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
}
