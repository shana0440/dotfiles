# Dotfiles

Nix configuration for a Hyprland + Quickshell desktop on NixOS, with the same
shell, Git, Neovim, and tmux setup on macOS and WSL.

# Code

- This codebase is yours: you decide how it is built, and you maintain it
  from now on.
- Let code explain itself instead of using comments.
- Give every feature commands an agent can run to read and change it: a CLI,
  or a Quickshell IPC target with a `state` function. List new commands and
  IPC targets in `mei/skills/desktop/SKILL.md`.

# Documentation

- Write for a new user of the repo, not as notes to yourself: no reasoning,
  history, test results, or details of this machine.
- Keep documents short.
- Say each thing in one document only; link to it from others instead of
  repeating it.
- Write instructions as what to do: "Do this", in place of "Don't do that".

# Verification

- Verify by running the real thing and recording it, in place of unit tests.
- After installing a new application, launch it in a headless Agent Workspace
  Linux desktop and record it for the user to review.
- After changing the Quickshell UI, record the changed workflow in an isolated
  session (see `quickshell/AGENTS.md`) for the user to review.
- Keep everything made for review or debugging in `.agents/`: scenario
  scripts, recordings, screenshots, and logs.

# Commit

- One concern per commit.
- The message is one imperative sentence that says what the commit adds or
  changes, in the style of conventional commits. Add a body only when the
  reason is not obvious from the diff.
- A fix to something an earlier step built gets its own commit, before the
  commits of the current step.
