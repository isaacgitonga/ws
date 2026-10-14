#!/usr/bin/env bash

WS_REGISTRY="${WS_REGISTRY:-$HOME/.config/ws/registry}"

if [[ $# -lt 1 ]]; then
  printf "ws: Missing arguments.\nUsage: ws <command> [args...]\nSee 'ws --help' for more information.\n" >&2
  exit 1
fi

if [[ ! -f "$WS_REGISTRY" ]]; then
  mkdir -p "$(dirname "$WS_REGISTRY")" && touch "$WS_REGISTRY"
fi

commands=("add" "remove" "list" "edit" "clean" "replace")

names=()
paths=()

if [[ ! -s "$WS_REGISTRY" && ("$1" == "remove" || "$1" == "list") ]]; then
  printf "ws: Registry is empty. Please add a workspace first.\n" >&2
  exit 1
fi

while read -r name path || [[ -n "$name" ]]; do

  [[ -z "$name" || "$name" == \#* ]] && continue

  names+=("$name")
  paths+=("$path")
done < "$WS_REGISTRY"

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

  if [[ "$name" == \#* ]]; then
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
        printf "ws: Path '%s' does not exist.\nws: Run 'ws remove %s' to remove.\n" "$path" "$name" >&2
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

case "$1" in
  add)
    shift; cmd_add "$@"
    ;;
  remove)
    ;;
  list)
    ;;
  edit)
    ;;
  replace)
    ;;
  --help)
    ;;
  *)
    if [[ $# -eq 1 || $# -eq 2 ]]; then
      open "$@"
    fi

    printf "ws: Unknown command '%s'.\n" "$1" >&2
    exit 1
    ;;
esac  