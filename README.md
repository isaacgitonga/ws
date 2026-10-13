# ws

Open code workspaces by name instead of navigating the file system.

```sh
ws core        # open core in VS Code
ws             # fuzzy-pick a workspace
ws add         # register the current directory
```

Built for my own setup (bash/zsh + VS Code + fzf). See [SPEC.md](SPEC.md) for full behavior.

## Install

1. Clone this repo.
2. Make the script executable and put it on your `PATH`:

   ```bash
   chmod +x bin/ws
   ln -s ~/DevStudio/projects/ws/bin/ws ~/.local/bin/ws
   ```

   This needs `~/.local/bin` on your `PATH`.
3. Requires `fzf` (for the picker) and VS Code's `code` command on your `PATH`.
4. Optionally copy `workspaces.example` to `~/.config/ws/workspaces` as a starting point.

Coming in Phase 2: a zsh wrapper (`ws.zsh`, sourced from `~/.zshrc`) that adds `ws cd` and tab completion.

## Status

Work in progress. I'm building it to learn shell scripting.
