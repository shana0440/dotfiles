# Single source for the NixOS username.
{ lib, ... }:

{
  options.user.name = lib.mkOption {
    type = lib.types.str;
    description = "Primary user account name.";
  };

  config = {
    user.name = "kwguo";
  };
}
