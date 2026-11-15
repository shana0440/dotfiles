{ lib }:

watchedFile: shaderStorePath: lib.hm.dag.entryAfter [ "linkGeneration" ] ''
  target="${watchedFile}"
  run mkdir -p "$(dirname "$target")"
  if [ -L "$target" ]; then run rm "$target"; fi
  if [ "$(cat "$target" 2>/dev/null)" != "${shaderStorePath}" ]; then
    run sh -c 'printf "%s\n" "$1" > "$2"' _ "${shaderStorePath}" "$target"
  fi
''
