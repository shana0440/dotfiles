#!/bin/bash

# Install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install \
  stow \
  git \
  fish \
  asdf \
  fzf \
  fd \
  the_silver_searcher \
  gh \
  jq \
  mycli pgcli \
  tmux \
  tldr

brew install --cask \
  kitty \
  firefox \
  fork \
  visual-studio-code \
  telegram
