.PHONY: nixos home

# Resolve paths relative to this Makefile, regardless of the working directory.
DOTFILES := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

nixos:
	sudo nixos-rebuild switch -I "nixos-config=$(DOTFILES)/nixos/configuration.nix"

home:
	home-manager switch --flake "$(DOTFILES)#kwguo"
