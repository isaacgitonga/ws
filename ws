#!/usr/bin/env bash

WS_REGISTRY="${WS_REGISTRY:-$HOME/.config/ws/registry}"

if [[ $# -lt 1 ]]; then
  printf "ws: Missing arguments.\nUsage: ws <command> [args...]\nSee 'ws --help' for more information.\n" >&2
  exit 1
fi

if [[ ! -f "$WS_REGISTRY" ]]; then
  mkdir -p "$(dirname "$WS_REGISTRY")" && touch "$WS_REGISTRY"
  printf "# ws registry — one workspace per line: name  path\n# Lines starting with '#' and blank lines are ignored.\n\n" >> "$WS_REGISTRY"
fi

commands=("add" "rem" "list" "edit" "clean" "rep")

names=()
paths=()

while read -r name path || [[ -n "$name" ]]; do
  [[ -z "$name" || "$name" == \#* ]] && continue

  names+=("$name")
  paths+=("$path")
done < "$WS_REGISTRY"

if [[ ${#names[@]} -eq 0 && ("$1" == "rem" || "$1" == "list") ]]; then
  printf "ws: Registry is empty. Please add a workspace first.\n" >&2
  exit 1
fi

get_path() {
  local path="$1"
  local file

  if [[ -z "$path" ]]; then
    path="$(pwd -P)"
  fi

  if [[ -f "$path" ]]; then
    file="$(basename "$path")"
    path="$(dirname "$path")"
  fi

  if [[ ! -d "$path" || ! -x "$path" ]]; then
    printf "ws: Path '%s' does not exist or is not an accessible directory.\n" "$path" >&2
    return 1
  fi

  path="$(cd "$path" && pwd -P)"

  [[ -n "$file" ]] && path="${path%/}/$file"

  if [[ "$path" == "$HOME" ]]; then
    path="~"
  elif [[ "$path" == "$HOME/"* ]]; then
    path="~${path#"$HOME"}"
    path="${path%/}"
  fi

  printf "%s\n" "$path"
}

expand_path() {
  local path="$1"

  if [[ "$path" == "~"* ]]; then
    path="${path/#\~/$HOME}"
  fi

  printf "%s\n" "$path"
}

cmd_add() {
  local name
  local path
  local args=$#

  case $args in
    0)
      path="$(get_path)" || exit 1; name="$(basename "$path")"

      if [[ $name == *"."* ]]; then
        name="${name%.*}"
      fi
    ;;
    1)
      if [[ -f "$1" || -d "$1" ]]; then
        path="$(get_path "$1")" || exit 1; name="$(basename "$path")"

        if [[ $name == *"."* ]]; then
          name="${name%.*}"
        fi
      else
        name="$1"; path="$(get_path)" || exit 1
      fi
      ;;
    2)
      if [[ $1 == "-n" ]]; then
        name="$2"; path="$(get_path)" || exit 1
      elif [[ $1 == "-p" ]]; then
        path="$(get_path "$2")" || exit 1; name="$(basename "$path")"

        if [[ $name == *"."* ]]; then
          name="${name%%.*}"
        fi
      else
        printf "ws: Invalid arguments for 'add' command.\nUsage: ws add -n <name> -p <path>\n" >&2
        exit 1
      fi
    ;;
    4)
      if [[ $1 == "-n" && $3 == "-p" ]]; then
        name="$2"; path="$(get_path "$4")" || exit 1
      elif [[ $1 == "-p" && $3 == "-n" ]]; then
        path="$(get_path "$2")" || exit 1; name="$4"
      else
        printf "ws: Invalid arguments for 'add' command.\nUsage: ws add -n <name> -p <path>\n" >&2
        exit 1
      fi
      ;;
    *)
      printf "ws: Invalid arguments for 'add' command.\nUsage: ws add -n <name> -p <path>\n" >&2
      exit 1
      ;;
  esac

  if [[ -z "$name" || -z "$path" ]]; then
    printf "ws: Missing arguments for 'add' command.\nUsage: ws add -n <name> -p <path>\n" >&2
    exit 1
  fi

  for command in "${commands[@]}"; do
    if [[ "$name" == "$command" ]]; then
      printf "ws: '%s' is reserved command name and cannot be used as a workspace name.\n" "$name" >&2
      exit 1
    fi
  done

  for workspace in "${names[@]}"; do
    if [[ "$workspace" == "$name" ]]; then
      printf "ws: Workspace name '%s' already exists.\n" "$name" >&2
      exit 1
    fi
  done

  if [[ "$name" == "#"* ]]; then
    printf "ws: Workspace name cannot start with '#'.\n" >&2
    exit 1
  fi

  if [[ "$name" == *[[:space:]]* ]]; then
    printf "ws: Workspace name cannot contain whitespace.\n" >&2
    exit 1
  fi

  for i in "${!paths[@]}"; do
    if [[ "${paths[i]}" == "$path" ]]; then
      printf "ws: Note that a workspace with a similar path '%s' already exists.\n" "$path" >&2
      printf "ws: Existing workspace name: '%s'\n" "${names[i]}" >&2
    fi
  done

  printf "%-30s %s\n" "$name" "$path" >> "$WS_REGISTRY"
  printf "ws: Workspace '%s' added successfully.\n" "$name" >&2
}

open() {
  local name
  local reuse
  local path

  if ! command -v code &>/dev/null; then
    printf "ws: VS Code is not installed or not in PATH.\n" >&2
    exit 1
  fi

  if [[ $# -eq 1 ]]; then
    name="$1"
  elif [[ $# -eq 2 ]]; then 
    if [[ "$1" == "-r" || "$1" == "--reuse" ]]; then
      reuse=true; name="$2"
    elif [[ "$2" == "-r" || "$2" == "--reuse" ]]; then
      reuse=true; name="$1"
    else
      printf "ws: Invalid arguments for opening a workspace.\nUsage: ws [-r] <name>\n" >&2
      exit 1
    fi
  else
    printf "ws: Invalid arguments for opening a workspace.\nUsage: ws [-r] <name>\n" >&2
    exit 1
  fi

  for i in "${!names[@]}"; do
    if [[ "${names[i]}" == "$name" ]]; then
      path="$(expand_path "${paths[i]}")"

      if [[ ! -d "$path" && ! -f "$path" ]]; then
        printf "ws: Path '%s' does not exist.\nws: Run 'ws rem %s' to remove.\n" "$path" "$name" >&2
        exit 1
      fi

      if [[ "$reuse" == true ]]; then
        code --reuse-window "$path"
      else
        code "$path"
      fi

      printf "ws: Workspace '%s' opened at '%s'.\n" "$name" "$path" >&2
      exit 0
    fi
  done

  printf "ws: Workspace '%s' not found.\n" "$name" >&2
  exit 1
}

cmd_path() {
  local name="$1"
  local path

  if [[ $# -ne 1 ]]; then
    printf "ws: Invalid number of arguments for 'path' command.\nUsage: ws path <name>\n" >&2
    exit 1
  fi

  if [[ -z "$name" ]]; then
    printf "ws: Missing workspace name for 'path' command.\nUsage: ws path <name>\n" >&2
    exit 1
  fi

  for i in "${!names[@]}"; do
    if [[ "${names[i]}" == "$name" ]]; then
      path="${paths[i]}"
    fi
  done 

  if [[ -z "$path" ]]; then
    printf "ws: Workspace '%s' does not exist or has no path. Consider removing.\n" "$name" >&2
    printf "ws: Run 'ws rem %s' to remove.\n" "$name" >&2
    exit 1
  fi

  path="$(expand_path "$path")"

  if [[ ! -d "$path" && ! -f "$path" ]]; then
    printf "ws: Path '%s'.\n\n" "$path" >&2
    printf "ws: Path does not exist in file system. Consider removing.\n" >&2
    printf "ws: Run 'ws rem %s' to remove.\n" "$name" >&2
    exit 1
  fi

  printf "%s\n" "$path"
  exit 0
}

cmd_rem() {
  local workspace="$1"
  local exists=false
  local name path

  if [[ $# -ne 1 || -z "$1" ]]; then
    printf "ws: Invalid number of arguments for 'rem' command.\nUsage: ws rem <name>\n" >&2
    exit 1
  fi

  for i in "${!names[@]}"; do
    [[ "${names[i]}" == "$workspace" ]] && exists=true
  done

  if ! $exists; then
    printf "ws: Workspace '%s' does not exist.\n" "$workspace" >&2
    exit 1
  fi

  temp_registry="$(mktemp -p "$(dirname "$WS_REGISTRY")" "$(basename "$WS_REGISTRY").tmp.XXXXXX")" || { printf "ws: Failed to remove workspace '%s'\n" "$workspace" >&2; exit 1; }
  trap 'rm -f "$temp_registry"' EXIT 

  while IFS= read -r line || [[ -n "$line" ]]; do
    read -r name path <<< "$line"

    if [[ "$line" != "#"* && "$workspace" == "$name" ]]; then
      continue 
    fi
    
    printf "%s\n" "$line" >> "$temp_registry"
  done < "$WS_REGISTRY"

  chmod --reference="$WS_REGISTRY" "$temp_registry" 2>/dev/null
  mv "$temp_registry" "$WS_REGISTRY"

  printf "ws: Workspace '%s' removed\n" "$workspace" >&2
  exit 0
}

cmd_list() {
  local name path full_path

  if [[ "$#" -ne 0 ]]; then
    printf "ws: Command 'list' does not require any arguments.\nUsage: ws list\n\n" >&2
    exit 1
  fi

  if [[ ${#names[@]} -eq 0 ]]; then
    printf "ws: No workspaces found.\nRun 'ws add -n <name> -p <path>' to add a workspace\n" >&2
    exit 1
  fi

  printf "\n" >&2

  for i in "${!names[@]}"; do
    name="${names[i]}"
    path="${paths[i]}"
    full_path="$(expand_path "$path")"

    if [[ ! -d "$full_path" && ! -f  "$full_path" ]]; then
      path="${path} (invalid path)"
    fi

    printf "%-25s %s\n" "$name" "$path"
  done

  printf "\nRegistry: %s\n" "$WS_REGISTRY" >&2
  exit 0
}

arg_help() {
  printf "ws: Workspace Manager for VS Code\n\n"
  printf "Usage: ws <name>\n"
  printf "       ws <command> [args...]\n\n"
  printf "Commands:\n"
  printf "  <name>                  Open a workspace in VS Code\n"
  printf "  -r, --reuse <name>      Open it in the current VS Code window\n"
  printf "  path <name>             Print a workspace's absolute path\n"
  printf "  add [name | path]       Register the current directory, or the given path\n"
  printf "  add -n <name> -p <path> Register a path under a name (flags in any order)\n"
  printf "  rem <name>              Remove a workspace from the registry\n"
  printf "  list                    List all workspaces, flagging invalid paths\n"
  printf "  --help                  Show this help message\n\n"
  printf "Examples:\n"
  printf "  ws myproject\n"
  printf "  ws -r myproject\n"
  printf "  ws add\n"
  printf "  ws add -n myproject -p ~/projects/myproject\n"
  printf "  ws rem myproject\n"
  printf "  ws list\n"
  printf "  cd \"\$(ws path myproject)\"\n\n"
  printf "Registry: %s (override with WS_REGISTRY)\n" "$WS_REGISTRY"
}

case "$1" in
  add)
    shift; cmd_add "$@"
    ;;
  path)
    shift; cmd_path "$@"
    ;;
  rem)
    shift; cmd_rem "$@"
    ;;
  list)
    shift; cmd_list "$@"
    ;;
  edit)
    ;;
  rep)
    ;;
  --help)
    arg_help
    ;;
  *)
    if [[ $# -eq 1 || $# -eq 2 ]]; then
      open "$@"
    fi

    printf "ws: Unknown command '%s'.\n" "$1" >&2
    exit 1
    ;;
esac  