#!/bin/bash

while read EXTENSION
do
    echo "Install VSCode Extension: $EXTENSION"
    code --install-extension $EXTENSION --force
done < $HOME/dotfiles/vscode/extensions.txt
