function ag_preview
  ag -l $argv | fzf --multi --color=dark --cycle --preview-window=up:70% --preview="ag --color $argv {+1}"
end
