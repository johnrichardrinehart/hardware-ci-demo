{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardwareCiDemo.tetris;
in
{
  options.hardwareCiDemo.tetris.enable = lib.mkEnableOption "the terminal Tetris game";

  config = {
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
    };
    networking.hostName = "x86-ci";
    environment.systemPackages = lib.mkIf cfg.enable (lib.mkForce [ pkgs.vitetris ]);
  };
}
