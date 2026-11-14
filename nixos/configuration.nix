{ config, pkgs, ... }:

{
  # Generated for the installed system after the target disk is mounted.
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

  # Enable on this machine after creating nixos/nas/secrets.yaml.
  services.nas.enable = true;

  hardware.cpu.intel.updateMicrocode = true;

  networking.hostName = "kwguo-nixos";
  # NetworkManager and VPN-aware DNS are configured by vpn/vpn.nix.
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  # The home router advertises IPv6 prefixes but does not route IPv6 to the
  # internet, so anything that tries IPv6 first stalls until it times out.
  # Tailscale keeps working over its IPv4 (100.x) addresses.
  networking.enableIPv6 = false;
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

  services.tailscale.enable = true;
  services.usbmuxd.enable = true;

  # Moshi connects over SSH, then starts mosh-server for roaming sessions.
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

  # Controlled from the Quickshell dashboard's Bluetooth tab; Quickshell also runs the pairing agent.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      # Report headset battery levels and allow fast reconnects.
      Experimental = true;
      FastConnectable = true;
    };
  };

  # The in-kernel hid-microsoft driver rejects the Xbox One S controller's
  # Bluetooth HID descriptor, so the pad connects but creates no input device.
  hardware.xpadneo.enable = true;

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
  ];

  fonts.packages = with pkgs; [
    dejavu_fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
