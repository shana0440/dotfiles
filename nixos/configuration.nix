{ config, pkgs, ... }:

{
  # Generated for the installed system after the target disk is mounted.
  imports = [
    ./hardware-configuration.nix
    (import ../applications.nix).nixos
    ./desktop.nix
    ./user.nix
  ];

  # UEFI boot; mount the chosen EFI system partition at /boot before installing.
  boot.loader.systemd-boot.enable = true;
  # Use the UEFI shell to identify the Windows ESP before adding its menu entry.
  boot.loader.systemd-boot.edk2-uefi-shell.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "kwguo-nixos";
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

  services.openssh = {
    enable = false;
    openFirewall = false;
  };

  security.polkit.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Compressed RAM swap; backing memory is allocated on demand.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  environment.systemPackages = with pkgs; [
    git
    curl
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
