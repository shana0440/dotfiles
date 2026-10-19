{ config, pkgs, ... }:

{
  # Generated for the installed system after the target disk is mounted.
  imports = [
    ./hardware-configuration.nix
    ./applications.nix
    ./desktop.nix
    ./user.nix
  ];

  # This VM currently boots in legacy BIOS mode.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking.hostName = config.user.name;
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  time.timeZone = "Asia/Taipei";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.fish.enable = true;

  users.users.${config.user.name} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" ];
    # Set the password interactively during installation.
  };

  services.openssh.enable = false;

  security.polkit.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  virtualisation.vmware.guest.enable = true;

  # The VM has 4 GiB RAM; swap provides headroom during desktop use.
  swapDevices = [ { device = "/swapfile"; size = 2048; } ];

  environment.systemPackages = with pkgs; [
    nodejs
  ];

  fonts.packages = with pkgs; [
    dejavu_fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
