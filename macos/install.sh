#!/bin/bash

export PATH=$PATH:/opt/homebrew/bin

bash ./macos/setup.sh

stow --adopt kitty fish git tmux vim

stow vscode --target="$HOME/Library/Application Support/Code/User/"
bash ./vscode/install-extensions.sh

bash ./macos/appearance.sh

echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
