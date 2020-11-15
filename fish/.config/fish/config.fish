if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c fisher
end

alias gst='git status'
alias glas='git log --all --date-order --decorate --graph --oneline'

set -x FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
source /usr/local/opt/asdf/asdf.fish

set -x PATH $HOME/flutter/bin $PATH
set -x PATH $HOME/.pub-cache/bin $PATH
set -x PATH (yarn global bin) $PATH
set -x PATH $HOME/go/go1.15.3/bin $PATH
set -x GOPATH $HOME/go $HOME/Codes/u-job

set -x PATH $GOPATH/bin $PATH
