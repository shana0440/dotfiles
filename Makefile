.PHONY: nixos home home-linux home-mac home-wsl

# Resolve paths relative to this Makefile, regardless of the working directory.
DOTFILES := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Select the host architecture using Nix's platform naming.
NIX_SYSTEM ?= $(shell nix eval --impure --raw --expr builtins.currentSystem)
NIX_ARCH = $(firstword $(subst -, ,$(NIX_SYSTEM)))

IS_WSL = $(shell if [ -n "$$WSL_DISTRO_NAME" ] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then printf true; else printf false; fi)

nixos:
	sudo nixos-rebuild switch -I "nixos-config=$(DOTFILES)/nixos/configuration.nix"

home:
	@if [ "$$(uname -s)" = Darwin ]; then \
		$(MAKE) home-mac; \
	elif [ "$$(uname -s)" = Linux ]; then \
		if [ "$(IS_WSL)" = true ]; then \
			$(MAKE) home-wsl; \
		else \
			$(MAKE) home-linux; \
		fi; \
	else \
		echo "Unsupported OS. Use home-linux, home-mac, or home-wsl explicitly." >&2; \
		exit 1; \
	fi

home-linux:
	home-manager switch --flake "$(DOTFILES)#$(or $(HOME_CONFIG),kwguo-$(NIX_ARCH)-linux)"

home-mac:
	home-manager switch --flake "$(DOTFILES)#$(or $(HOME_CONFIG),kwguo-$(NIX_ARCH)-darwin)"

home-wsl:
	home-manager switch --flake "$(DOTFILES)#$(or $(HOME_CONFIG),kwguo-$(NIX_ARCH)-linux-wsl)"
