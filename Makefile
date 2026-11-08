.PHONY: nixos nixos-update home home-linux home-mac home-wsl update encrypt decrypt re-encrypt

# Resolve paths relative to this Makefile, regardless of the working directory.
DOTFILES := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Bootstrap flakes even before Home Manager writes the user Nix configuration.
NIX_FLAGS = --extra-experimental-features "nix-command flakes"

# Select the host architecture using Nix's platform naming.
NIX_SYSTEM ?= $(shell nix $(NIX_FLAGS) eval --impure --raw --expr builtins.currentSystem)
NIX_ARCH = $(firstword $(subst -, ,$(NIX_SYSTEM)))

IS_WSL = $(shell if [ -n "$$WSL_DISTRO_NAME" ] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then printf true; else printf false; fi)

# Update the pinned nixpkgs snapshot; apply separately with make home.
update:
	nix $(NIX_FLAGS) flake update nixpkgs --flake "$(DOTFILES)"

nixos:
	sudo nixos-rebuild switch -I "nixos-config=$(DOTFILES)/nixos/configuration.nix"

# Update the root NixOS channel and switch to the rebuilt system.
nixos-update:
	sudo nixos-rebuild switch --upgrade -I "nixos-config=$(DOTFILES)/nixos/configuration.nix"

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
	home-manager $(NIX_FLAGS) switch --flake "$(DOTFILES)#$(or $(HOME_CONFIG),kwguo-$(NIX_ARCH)-linux)"

home-mac:
	home-manager $(NIX_FLAGS) switch --flake "$(DOTFILES)#$(or $(HOME_CONFIG),kwguo-$(NIX_ARCH)-darwin)"

home-wsl:
	home-manager $(NIX_FLAGS) switch --flake "$(DOTFILES)#$(or $(HOME_CONFIG),kwguo-$(NIX_ARCH)-linux-wsl)"

# Process every encrypted path registered in .sops.yaml.
encrypt decrypt re-encrypt:
	@set -eu; umask 077; cd "$(DOTFILES)"; \
	files=$$(yq -er '.files[]' .sops.yaml); \
	printf '%s\n' "$$files" | while IFS= read -r file; do \
		encrypted="$(DOTFILES)/$$file"; \
		if [ "$@" = re-encrypt ]; then sops --config .sops.yaml updatekeys --yes "$$encrypted"; continue; fi; \
		base="$${encrypted%.*}"; plaintext="$${base%.enc}.$${encrypted##*.}"; \
		if [ "$$plaintext" = "$$encrypted" ]; then echo "Expected an .enc filename: $$file" >&2; exit 1; fi; \
		if [ -f "$$plaintext" ]; then chmod 600 "$$plaintext"; fi; \
		case "$@" in \
			encrypt) sops --config .sops.yaml --filename-override "$$encrypted" --encrypt --output "$$encrypted" "$$plaintext" ;; \
			decrypt) sops --decrypt --output "$$plaintext" "$$encrypted" ;; \
		esac; \
	done
