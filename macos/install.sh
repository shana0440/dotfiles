#!/bin/bash

bash ./setup.sh

stow kitty fish git tmux vim

stow vscode --target="$HOME/Library/Application Support/Code/User/"
bash ./vscode/install-extensions.sh

bash ./appearance.sh
