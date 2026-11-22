{
  description = "kwguo's standalone Home Manager configuration";

  inputs = {
    herdr-app-release = {
      url = "file+https://releases.herdr.dev/app/latest.json";
      flake = false;
    };
    herdr-core-release = {
      url = "file+https://releases.herdr.dev/core/latest.json";
      flake = false;
    };
    pi-bolt-linux-x64 = {
      url = "https://github.com/opensec-git/Pi-Bolt/releases/latest/download/pi-bolt-linux-x64-baseline.tar.gz";
      flake = false;
    };
    pi-bolt-linux-arm64 = {
      url = "https://github.com/opensec-git/Pi-Bolt/releases/latest/download/pi-bolt-linux-arm64.tar.gz";
      flake = false;
    };
    pi-bolt-darwin-arm64 = {
      url = "https://github.com/opensec-git/Pi-Bolt/releases/latest/download/pi-bolt-darwin-arm64.tar.gz";
      flake = false;
    };
    mei = {
      url = "github:shana0440/mei";
      flake = false;
    };
    eagle-linux = {
      url = "github:shana0440/Eagle-Linux";
      flake = false;
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";
    home-manager = {
      url = "https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, zen-browser, ... }@inputs:
    let
      mkHome = system: module: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [ module ];
        extraSpecialArgs = { inherit zen-browser inputs; };
      };
    in {
      packages = nixpkgs.lib.recursiveUpdate (nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ] (system: import ./agents/herdr/packages.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit inputs;
      })) {
        x86_64-linux.pi-bolt = import ./agents/pi-bolt/package.nix {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          inherit inputs;
        };
        aarch64-linux.pi-bolt = import ./agents/pi-bolt/package.nix {
          pkgs = nixpkgs.legacyPackages.aarch64-linux;
          inherit inputs;
        };
        aarch64-darwin.pi-bolt = import ./agents/pi-bolt/package.nix {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          inherit inputs;
        };

        x86_64-linux.eagle = (import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        }).callPackage "${inputs.eagle-linux}/default.nix" {
          enableAiSearch = false;
        };

        x86_64-linux.eagle-media-preview = nixpkgs.legacyPackages.x86_64-linux.callPackage ./eagle/media-preview.nix {
          inherit (inputs.self.packages.x86_64-linux) eagle;
        };

        x86_64-linux.nexon-launcher = import ./nexon/package.nix {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        };
      };

      homeConfigurations = {
        kwguo = mkHome "x86_64-linux" ./home.nix;

        "kwguo-x86_64-linux" = mkHome "x86_64-linux" ./home.nix;
        "kwguo-aarch64-linux" = mkHome "aarch64-linux" ./home.nix;
        "kwguo-x86_64-darwin" = mkHome "x86_64-darwin" ./macos.nix;
        "kwguo-aarch64-darwin" = mkHome "aarch64-darwin" ./macos.nix;

        "kwguo-x86_64-linux-wsl" = mkHome "x86_64-linux" ./wsl.nix;
        "kwguo-aarch64-linux-wsl" = mkHome "aarch64-linux" ./wsl.nix;
      };
    };
}
