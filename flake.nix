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
      hostPkgs = nixpkgs.legacyPackages.x86_64-linux;
      touying = hostPkgs.fetchzip {
        url = "https://packages.typst.org/preview/touying-0.7.4.tar.gz";
        hash = "sha256-fp/EL3OKBPehbbwyXR8o1UladQk//g9M+loWcWBdEv4=";
        stripRoot = false;
      };
      uniwarn = hostPkgs.fetchzip {
        url = "https://packages.typst.org/preview/uniwarn-0.1.1.tar.gz";
        hash = "sha256-sTGerNf9eBuuvl20yytfvQulfWiU5gtPZOB6GK0M0ho=";
        stripRoot = false;
      };
      typstPackagePath = hostPkgs.runCommand "hardware-ci-demo-typst-packages" { } ''
        mkdir -p "$out/preview/touying" "$out/preview/uniwarn"
        ln -s ${touying} "$out/preview/touying/0.7.4"
        ln -s ${uniwarn} "$out/preview/uniwarn/0.1.1"
      '';
      slideSources = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [ ./schematic.svg ./slides.typ ];
      };
      maxSdImageBytes = 4 * 1024 * 1024 * 1024;
      mkX86System = enableTetris: lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nixosConfigurations/default.nix
          ./nixosConfigurations/x86_64
          { hardwareCiDemo.tetris.enable = enableTetris; }
        ];
      };
      demoLoginEnabled = configuration:
        let
          cfg = configuration.config;
          demo = cfg.users.users.demo;
        in
        cfg.users.mutableUsers == false
        && demo.isNormalUser
        && demo.password == "demo"
        && cfg.services.openssh.enable
        && cfg.services.openssh.settings.PasswordAuthentication;
      sizeCheck = name: image:
        nixpkgs.legacyPackages.x86_64-linux.runCommand "${name}-under-4GiB" {
          inherit image;
        } ''
          image_size=$(stat --format=%s "$image")
          test "$image_size" -le ${toString maxSdImageBytes}
          touch "$out"
        '';
    in
    rec {
      nixosConfigurations = {
        rpi4 = lib.nixosSystem {
          inherit system;
          modules = [
            ./nixosConfigurations/default.nix
            ./nixosConfigurations/rpi4
          ];
        };

        rock5c = rockNixpkgs.lib.nixosSystem {
          inherit system;
          pkgs = import rockNixpkgs {
            inherit system;
            overlays = [ rock5c-nixos.overlays.default ];
          };
          specialArgs.rock5cNixos = rock5c-nixos;
          modules = [
            ./nixosConfigurations/default.nix
            ./nixosConfigurations/rock5c
          ];
        };

        x86_64-linux-minimal = mkX86System false;
        x86_64-linux-tetris = mkX86System true;
      };

      packages.x86_64-linux = {
        rpi4-sd-image = nixosConfigurations.rpi4.config.system.build.sdImage;
        rock5c-sd-image = nixosConfigurations.rock5c.config.system.build.sdImage;
        x86_64-linux-minimal = nixosConfigurations.x86_64-linux-minimal.config.system.build.toplevel;
        x86_64-linux-tetris = nixosConfigurations.x86_64-linux-tetris.config.system.build.toplevel;
        slides = hostPkgs.runCommand "hardware-ci-demo-slides.pdf" {
          nativeBuildInputs = [ hostPkgs.typst ];
        } ''
          typst compile \
            --format pdf \
            --root ${slideSources} \
            --package-path ${typstPackagePath} \
            --font-path ${lib.makeSearchPath "share/fonts" [ hostPkgs.fira hostPkgs.fira-math ]} \
            --ignore-system-fonts \
            ${slideSources}/slides.typ "$out"
        '';
      };

      checks.x86_64-linux = {
        rpi4-sd-image-under-4GiB = sizeCheck "rpi4-sd-image" packages.x86_64-linux.rpi4-sd-image;
        rock5c-sd-image-under-4GiB = sizeCheck "rock5c-sd-image" packages.x86_64-linux.rock5c-sd-image;
        slides = packages.x86_64-linux.slides;
        x86_64-linux-minimal =
          let
            configuration = nixosConfigurations.x86_64-linux-minimal;
            closure = packages.x86_64-linux.x86_64-linux-minimal;
            closureInfo = hostPkgs.closureInfo { rootPaths = [ closure ]; };
          in
          assert demoLoginEnabled configuration;
          hostPkgs.runCommand "x86_64-linux-minimal-without-tetris" { } ''
            test ! -e ${closure}/sw/bin/tetris
            ! grep -q -- '-vitetris-' ${closureInfo}/store-paths
            touch "$out"
          '';
        x86_64-linux-tetris =
          let
            configuration = nixosConfigurations.x86_64-linux-tetris;
            closure = packages.x86_64-linux.x86_64-linux-tetris;
            closureInfo = hostPkgs.closureInfo { rootPaths = [ closure ]; };
          in
          assert demoLoginEnabled configuration;
          hostPkgs.runCommand "x86_64-linux-tetris-command" { } ''
            test -x ${closure}/sw/bin/tetris
            grep -q -- '-vitetris-' ${closureInfo}/store-paths
            touch "$out"
          '';
      };

      devShells.x86_64-linux.default = hostPkgs.mkShell {
        packages = [ hostPkgs.fira hostPkgs.fira-math hostPkgs.typst ];
        TYPST_FONT_PATHS = lib.makeSearchPath "share/fonts" [ hostPkgs.fira hostPkgs.fira-math ];
        TYPST_PACKAGE_PATH = typstPackagePath;
      };
    };
}
