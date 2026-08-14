{ lib, pkgs, ... }:

let
  x86Pkgs = import pkgs.path { system = "x86_64-linux"; };
in
{
  # U-Boot cannot start this kernel on the AArch64 ROCK 5C.
  boot.kernelPackages = lib.mkForce (
    pkgs.linuxPackages.extend (
      _: _: {
        kernel = x86Pkgs.linuxPackages.kernel;
        # Keep the system platform AArch64 so runtime activation succeeds.
        inherit (pkgs) stdenv;
      }
    )
  );
  boot.loader.timeout = 15;
}
