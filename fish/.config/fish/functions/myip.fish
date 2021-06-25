function myip
  ifconfig | grep "inet " | tail -1 | cut -d " " -f 2 | tr -d "\n" | pbcopy
end
