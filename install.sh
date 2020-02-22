#!/bin/bash

stow alacritty fish git skhd tmux vim yabai

bash ./macos/macos.sh

stow vscode --target="$HOME/Library/Application Support/Code/User/"
