# ws

Open code workspaces by name instead of navigating the file system.

```sh
ws blog        # open the 'blog' workspace in VS Code
ws -r blog     # open it in the current VS Code window
ws add         # register the current directory
ws             # fuzzy-pick a workspace (coming soon)
```

Built for my own setup (bash/zsh + VS Code + fzf). See [SPEC.md](SPEC.md) for full behavior.

## Install

1. Clone this repo wherever you like.
2. From the repo folder, make the script executable and symlink it into a directory on your `PATH`:

   ```bash
   chmod +x ws
   ln -s "$PWD/ws" ~/.local/bin/ws
   ```

   `~/.local/bin` is just an example. Any directory on your `PATH` works.
3. Requires VS Code's `code` command on your `PATH`, and `fzf` for the picker.
4. Optionally copy `registry.example` to `~/.config/ws/registry` as a starting point.

Coming in Phase 2: a zsh wrapper (`ws.zsh`, sourced from `~/.zshrc`) that adds `ws cd` and tab completion.

## Status

Work in progress. I'm building it to learn shell scripting.
