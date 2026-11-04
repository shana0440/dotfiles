# Quickshell validation

- When the user requests Agent Workspace Linux testing, that request authorizes
  launching an isolated Quickshell instance there. Do not ask again. Keep its
  D-Bus session isolated and leave the user's desktop instance untouched.
- Otherwise, use the user's already-running Quickshell instance. Do not launch
  another instance or restart it unless the user explicitly asks.
- Validate changes by interacting with the actual desktop and capturing
  screenshots or screen recordings. Inspect the captured evidence yourself.
- Do not add automated tests, offscreen harnesses, fake services, or fixtures.
  Passing scripts, status queries, logs, and syntax checks are not proof that the
  UI works.
- Reproduce the reported workflow from its initial state, including transitions,
  rather than checking only the final state. Do not claim success if a required
  step is missing or fails in the recording.
- Give the user the evidence file path and state any remaining failures honestly.
