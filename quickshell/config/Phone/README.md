# Phone

`Super+K` slides up a phone for chatting with [mei](https://github.com/shana0440/mei);
press it again or click outside it to slide it away. It talks to the mei daemon
at `$MEI_HOME/state/mei.sock` (default `~/.local/share/mei`) and shows mei as
offline when the daemon is not running.

- **Attachments:** press `Ctrl+V` in the message box to attach a copied
  screenshot, image file, or screen recording, then send it with or without a
  caption. Mei receives the local file path.
- **Copying:** select message text with the mouse and press `Ctrl+C`.
- **Links:** links in mei's replies get a preview card, fetched by
  `link-preview` from public internet addresses only and cached for a week in
  `~/.cache/quickshell/link-previews`.
- **Settings:** tap mei's photo to change her photo, her name (saved with
  `mei config set character.name`), her character file (language and tone;
  `CHARACTER.md` unless `[character] file` points elsewhere), her schedules,
  and the chat background. Reset there to permanently delete her memory and
  chat history, after a confirmation.
