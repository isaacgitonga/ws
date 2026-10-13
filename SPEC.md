# ws — specification

`ws` opens code workspaces by name, so you never navigate the file system to get to a project.

## Architecture

Two parts, built in two phases:

1. **`bin/ws` (Phase 1):** a **bash** script that does all the real work: reading the registry, opening VS Code, adding and removing entries, and the picker. It's installed on your `PATH` as `ws`, typically by symlinking it into `~/.local/bin`.
2. **`ws.zsh` (Phase 2):** a small **zsh wrapper function**, sourced from `~/.zshrc`, that adds the things a script can't do: changing the current shell's directory and zsh tab completion. It asks the script for a path (`ws path <name>`) and `cd`s there. Every other command passes straight through to the script.

Why the split: a script runs as a child process, and a child process can't change its parent shell's directory. Only a function running inside your shell can. zoxide uses the same design.

Phase 1 stands on its own: `ws` is fully useful without the wrapper. You just won't have `cd` yet.

## The registry

- **Location:** `~/.config/ws/workspaces`. If the `WS_REGISTRY` environment variable is set, use that path instead (handy for testing against a throwaway file).
- **Format:** one workspace per line, as `name  path`, separated by whitespace.
- **Blank lines and lines starting with `#`** are ignored.
- **Names** are unique, contain no spaces, and are lowercase by convention.
- **Paths** may start with `~`. A path can be a folder or a `.code-workspace` file.
- **If the file doesn't exist,** create it (and its parent directory) empty on first use rather than erroring.

```text
# work
core     ~/DevStudio/core
atlas    ~/DevStudio/atlas
```

## Phase 1: `bin/ws` commands

| Command | Behavior |
| --- | --- |
| `ws <name>` | Exact name match: open the path in VS Code (`code`). |
| `ws` | Fuzzy picker (fzf) showing name and path. Selecting one opens it. Pressing Esc does nothing and exits quietly. |
| `ws path <name>` | Print the workspace's absolute path (with `~` expanded) to stdout and nothing else. The Phase 2 wrapper is built on this. |
| `ws add [name]` | Register the current directory. The name defaults to the folder name. |
| `ws rm <name>` | Remove the entry from the registry. The folder itself is untouched. |
| `ws ls` | List every entry and flag paths that no longer exist. |
| `ws edit` | Open the registry file in VS Code. |
| `ws help` | Short usage text. |

## Phase 2: `ws.zsh` wrapper

| Command | Behavior |
| --- | --- |
| `ws <name>` | `cd` to the workspace (for a `.code-workspace` file, its folder), then let the script open VS Code. |
| `ws cd <name>` | `cd` only, without opening VS Code. |
| *anything else* | Passed through unchanged to the script. |

Plus zsh tab completion:

- After `ws`, Tab completes subcommands and workspace names.
- After `ws cd`, `ws rm` or `ws path`, Tab completes workspace names only.

The wrapper reaches the script with `command ws ...`, because a plain `ws` inside the function would call the function itself.

## Rules and edge cases

- **Reserved names:** `add`, `rm`, `ls`, `path`, `cd`, `edit` and `help` can't be workspace names. `ws add` rejects them.
- **Duplicate name on `add`:** refuse, and tell the user to `ws rm` first.
- **Duplicate path on `add`:** warn but allow it.
- **Unknown name:** print `ws: unknown workspace 'foo'` and point to `ws ls`.
- **Path no longer exists:** say so and suggest `ws rm <name>`. Don't open anything.
- **Missing dependency:** if `code` is missing, or `fzf` is missing when the picker is used, say exactly what's missing.
- **Output:** errors go to stderr, prefixed `ws:`. Normal output goes to stdout. For `ws path`, stdout must contain only the path, or nothing at all on error, because the wrapper captures it.
- **Exit codes:** return `0` on success and `1` on any error. Cancelling the picker returns `0`.

## Out of scope for v1

Groups of workspaces, per-project startup commands, other editors, a reuse-window option, and syncing between machines. Revisit these only after using v1 enough to miss them.

## Build order

Each step works on its own before you start the next.

**Phase 1: `bin/ws`**

- [ ] Skeleton: shebang, executable, symlinked onto `PATH`, `ws help` prints usage
- [ ] `ws path <name>`: look up a name in the registry
- [ ] `ws <name>`: open in VS Code (reuses the lookup from the previous step)
- [ ] `ws ls`
- [ ] `ws add [name]`
- [ ] `ws rm`, `ws edit`
- [ ] `ws` (the picker)
- [ ] Edge cases and error messages from the rules above, with ShellCheck clean

**Phase 2: `ws.zsh`**

- [ ] Wrapper function: `ws cd <name>` and cd-on-open, with everything else passed through
- [ ] zsh tab completion
