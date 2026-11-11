{
  description = "kwguo's standalone Home Manager configuration";

  inputs = {
    # Upstream has no flake. Pin release archives as non-flake inputs.
    # Update all three release URLs together, then run nix flake update.
    pi-bolt-linux-x64 = {
      url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v1.2.0/pi-bolt-linux-x64-baseline.tar.gz";
      flake = false;
    };
    pi-bolt-linux-arm64 = {
      url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v1.2.0/pi-bolt-linux-arm64.tar.gz";
      flake = false;
    };
    pi-bolt-darwin-arm64 = {
      url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v1.2.0/pi-bolt-darwin-arm64.tar.gz";
      flake = false;
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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
      packages.x86_64-linux.pi-bolt = import ./pi-bolt/package.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        inherit inputs;
      };
      packages.aarch64-linux.pi-bolt = import ./pi-bolt/package.nix {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        inherit inputs;
      };
      packages.aarch64-darwin.pi-bolt = import ./pi-bolt/package.nix {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        inherit inputs;
      };

      packages.x86_64-linux.eagle = import ./eagle/package.nix {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };

      packages.x86_64-linux.nexon-launcher = import ./nexon/package.nix {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };

      homeConfigurations = {
        # Compatibility alias for the original NixOS VM.
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
