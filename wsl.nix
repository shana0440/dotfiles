# WSL Home Manager profile: shared CLI tools, no desktop modules.
{ ... }:

{
  imports = [ ./common.nix ];

  home.homeDirectory = "/home/kwguo";
}
