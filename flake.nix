{
  description = "kwguo's standalone Home Manager configuration";

  inputs = {
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

  outputs = { nixpkgs, home-manager, zen-browser, ... }:
    let
      mkHome = system: module: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [ module ];
        extraSpecialArgs = { inherit zen-browser; };
      };
    in {
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
