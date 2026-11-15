{ config, pkgs, ... }:

let
  homeRouterAdvertisesUnroutableIPv6 = true;
  xboxControllerOverBluetooth = true;
in
{
  imports = [
    ./hardware-configuration.nix
    ./grub.nix
    (import ../applications.nix).nixos
    (import ../vpn/vpn.nix).nixos
    (import ../file-manager/file-manager.nix).nixos
    ./desktop.nix
    ./login.nix
    ./iphone-webcam.nix
    ./user.nix
    ./nas.nix
  ];

  services.nas.enable = true;

  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "kwguo-nixos";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  networking.enableIPv6 = !homeRouterAdvertisesUnroutableIPv6;
  networking.firewall.enable = true;
  time.timeZone = "Asia/Taipei";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.fish.enable = true;

  users.users.${config.user.name} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  services.tailscale.enable = true;
  services.usbmuxd.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  programs.mosh.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Experimental = true;
      FastConnectable = true;
    };
  };

  hardware.xpadneo.enable = xboxControllerOverBluetooth;

  security.polkit.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  environment.systemPackages = with pkgs; [
    git
    curl
  ];

  fonts.packages = with pkgs; [
    dejavu_fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  system.stateVersion = "26.05";
}
