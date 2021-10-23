#!/bin/bash

# Install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install \
  # symlink farm manager
  stow \
  # version control
  git \
  # shell
  fish \
  # language manager
  asdf \
  # fuzzy finder
  fzf \
  # better find
  fd \
  # code searching
  the_silver_searcher \
  # github cmd
  gh \
  # JSON processor
  jq \
  # database cli
  mycli pgcli \
  # terminal multiplexer
  tmux \
  # man pages
  tldr

brew install --cask \
  # terminal-emulator
  kitty \
  # browser
  firefox \
  # git GUI
  fork \
  # IDE
  visual-studio-code
