#!/usr/bin/env bash
#
# func - A utility for safely extracting and managing shell functions
#        as part of a structured, safe development workflow.
#
# Version: 0.4 - Major architectural refactor for BASHFX alignment.
#

#-------------------------------------------------------------------------------
#  BashFX Declarations
#-------------------------------------------------------------------------------

  # BashFX Framework Declarations
  SELF="APP_FUNC"; # the SELF variable is ephemeral, use BOOK_PREF instead.

  readonly FUNC_NAME="$SELF";
  readonly APP_FUNC_VERSION="0.4.0"; #this needs to be updated every major/minor change
  readonly APP_FUNC="${BASH_SOURCE[0]}";


  #readonly TERM_WIDTH=$(tput cols 2>/dev/null || echo 80); #save

  # Context Awareness
  readonly FUNC_ARGS=("${@}"); #immutable
  readonly FUNC_PPID="$$";     #current run
  readonly FUNC_PATH="$0";     #execution origin

  FUNC_PREF='funcx'; #controls the name for app and directory installs


#-------------------------------------------------------------------------------
#  Flags
#-------------------------------------------------------------------------------


# --- Global Configuration & State ---

readonly C_RED='\x1B[38;5;9m'
readonly C_RESET='\x1B[0m'

# Default modes, can be overridden by environment or flags
SAFE_MODE=${SAFE_MODE:-1}
QUIET_MODE=${QUIET_MODE:-0}

# Populated by options()
opt_yes=0
opt_force=0
opt_alias=""
opt_bash=0


#-------------------------------------------------------------------------------
#  Stderr Quiet(1) Compliance
#-------------------------------------------------------------------------------

stderr(){
  local msg="$1"
  local force_print="$2" # A non-empty second arg bypasses QUIET_MODE

  # BASHFX QUIET(1) Compliance:
  # Only return (and print nothing) if QUIET_MODE is on AND
  # this is NOT a forced print (i.e., not an error/fatal message).
  if [ "${QUIET_MODE}" -eq 1 ] && [ -z "$force_print" ]; then
    return 0;
  fi

  printf "%b\n" "${msg}" >&2
}

error(){
  # We now pass a second argument "force" to stderr. This signals that
  # this is a high-priority message that must be printed even in QUIET_MODE.
  stderr "${C_RED}Error: ${1}${C_RESET}" "force"
  return 1;
}

fatal(){
  error "$1"
  exit 1
}

# --- Standardized Prompt Helpers ---

__prompt(){
  local prompt_msg="$1"
  local confirm
  read -p "${prompt_msg}: " confirm
  [[ "$confirm" == "y" || "$confirm" == "Y" ]]
  return $?;
}

__yes_prompt(){
  [ "$opt_yes" -eq 1 ] && return 0;
  local hint="(Use --yes to skip this prompt)"
  __prompt "${1} ${hint}"
}

__force_prompt(){
  [ "$opt_force" -eq 1 ] && return 0;
  local hint="(Use --force to override)"
  __prompt "${1} ${hint}"
}


# --- Low-Ordinal Filesystem & Logic Helpers ---

__safe_cp(){
  cp "$1" "$2"
  [ $? -ne 0 ] && fatal "Filesystem operation failed: cp '$1' to '$2'"
}

__safe_mv(){
  mv "$1" "$2"
  [ $? -ne 0 ] && fatal "Filesystem operation failed: mv '$1' to '$2'"
}

__safe_rm(){
  rm "$@"
  [ $? -ne 0 ] && fatal "Filesystem operation failed: rm '$@'"
}

__checksum(){
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    md5sum | awk '{print $1}'
  fi
}

__extract_function_body(){
  awk -v target_func="$1" '
    BEGIN { in_func = 0; brace_level = 0; }
    $0 ~ "^[[:space:]]*" target_func "[[:space:]]*\\([[:space:]]*\\)[[:space:]]*\\{" {
      if (in_func == 0) {
        in_func = 1;
        for (i = 1; i <= length($0); ++i) { if (substr($0, i, 1) == "{") brace_level++; }
        print $0; next;
      }
    }
    in_func == 1 {
      print $0;
      for (i = 1; i <= length($0); ++i) {
        if (substr($0, i, 1) == "{") brace_level++;
        else if (substr($0, i, 1) == "}") brace_level--;
      }
      if (brace_level == 0) in_func = 0;
    }
  ' "${2}"
}

__find_function_line(){
  grep -n -E "^[[:space:]]*${1}[[:space:]]*\([[:space:]]*\)[[:space:]]*\{" "${2}" | cut -d: -f1
}

__parse_meta_header(){
  grep "^# FUNC_META" "$2" | sed -n "s/.*$1:\([^ |]*\).*/\1/p"
}


# --- Guard Functions ---

is_file(){
  [ -f "$1" ]
}

is_valid_shell_source(){
  local file_path="$1"
  [ "$opt_bash" -eq 1 ] && return 0;
  ! is_file "$file_path" && return 1;
  case "$file_path" in
   (*.sh|*.bash*|*.func|*.fx) return 0; ;;
   (*.log|*.txt|*.md) return 1; ;;
  esac
  grep -q "^#!.*bash" <(head -n 1 "$file_path") && return 0;
  return 1;
}


# --- High-Ordinal Command Implementations ---

do_copy(){
  local func_name="$1";
  local src_path="$2";
  
  local func_body;
  func_body=$(__extract_function_body "$func_name" "$src_path");
  [ -z "$func_body" ] && fatal "Function '${func_name}' not found in '${src_path}'.";

  mkdir -p "./func";
  local orig_file="./func/${func_name}.orig.sh";
  local edit_file new_func_name;
  if [ -n "$opt_alias" ]; then
    new_func_name="$opt_alias"
  else
    local i=2
    new_func_name="${func_name}_v${i}";
    while is_file "./func/${new_func_name}.edit.sh"; do
      i=$((i+1))
      new_func_name="${func_name}_v${i}";
    done
  fi
  edit_file="./func/${new_func_name}.edit.sh";

  if [ -f "$orig_file" ] || [ -f "$edit_file" ]; then
    if [ "$opt_force" -eq 0 ]; then
      error "Target files already exist. Use --force to overwrite.";
      is_file "$orig_file" && stderr "  - Exists: $orig_file";
      is_file "$edit_file" && stderr "  - Exists: $edit_file";
      exit 1;
    fi
  fi
  
  printf "%s\n" "$func_body" > "$orig_file"
  echo "$func_body" | sed "1s/${func_name}/${new_func_name}/" > "$edit_file"

  local src_sum;
  src_sum=$(< "$src_path" __checksum)
  local orig_sum;
  orig_sum=$(echo "$func_body" | __checksum)
  local real_src_path;
  real_src_path=$(realpath "$src_path")
  local header="# FUNC_META | src:${real_src_path} | src_sum:${src_sum} | orig:${func_name} | edit:${new_func_name} | orig_sum:${orig_sum}";
  
  sed -i "1i\\${header}" "$orig_file";
  sed -i "1i\\${header}" "$edit_file";

  stderr "Created reference file: '${orig_file}'";
  stderr "Created working file:   '${edit_file}'";
}

do_insert(){
  local new_func_name="$1";
  local src_path="$2";
  
  local edit_file="./func/${new_func_name}.edit.sh";
  local marker_pattern="# FUNC_INSERT ${edit_file}";

  ! is_file "$edit_file" && fatal "Function file not found: '$edit_file'.";
  ! grep -q "${marker_pattern}" "$src_path" && fatal "FUNC_INSERT marker not found in '$src_path'.";

  if [ "$SAFE_MODE" -eq 1 ]; then
    local meta_src;
    meta_src=$(__parse_meta_header "src" "$edit_file");
    local real_src_path;
    real_src_path=$(realpath "$src_path");
    if [[ "$meta_src" != "$real_src_path" ]]; then
      local meta_src_sum;
      meta_src_sum=$(__parse_meta_header "src_sum" "$edit_file");
      local current_src_sum;
      current_src_sum=$(< "$src_path" __checksum);
      if [[ "$meta_src_sum" == "$current_src_sum" ]]; then
        if __yes_prompt "Warning: Source path mismatch, but checksums match. Update metadata in '${edit_file}'?"; then
          sed -i "s|src:${meta_src}|src:${real_src_path}|" "$edit_file";
        else
          fatal "Abort.";
        fi
      else
        fatal "SAFE_MODE Abort. Source file path and checksum both mismatch.";
      fi
    fi
  fi
  
  if is_file "${src_path}.orig"; then
    if [ "$opt_force" -eq 1 ]; then
      __safe_mv "${src_path}.orig" "${src_path}.orig.0";
      __safe_cp "$src_path" "${src_path}.orig";
    elif [ "$opt_yes" -eq 0 ]; then
      fatal "Backup file '${src_path}.orig' already exists. Use --yes to proceed without creating a new backup, or --force to version the existing one.";
    fi
  else
    __safe_cp "$src_path" "${src_path}.orig";
  fi

  sed -i -e "\#${marker_pattern}#r ${edit_file}" -e "\#${marker_pattern}#d" "${src_path}";
  stderr "Successfully inserted '${new_func_name}' into '${src_path}'.";
}

do_done(){
  local func_name="$1"
  local orig_file="./func/${func_name}.orig.sh";
  local extracted_file="./func/${func_name}.extracted.sh";
  local edit_file=""

  if is_file "$orig_file"; then
    local edit_name;
    edit_name=$(__parse_meta_header "edit" "$orig_file");
    [ -n "$edit_name" ] && edit_file="./func/${edit_name}.edit.sh";
    __safe_rm -f "$orig_file" "$edit_file";
    stderr "Removed: $orig_file";
    [ -n "$edit_file" ] && stderr "Removed: $edit_file";
  elif is_file "$extracted_file"; then
    __safe_rm -f "$extracted_file";
    stderr "Removed: $extracted_file";
  else
    fatal "No files found for '${func_name}'.";
  fi
}

do_clean(){
  if [ "$opt_force" -eq 1 ]; then
    if __force_prompt "Permanently delete ./func/ and all .orig backups?"; then
      __safe_rm -rf "./func";
      find . -maxdepth 1 -name "*.orig*" -delete;
      stderr "All artifacts removed.";
    else
      stderr "Clean operation cancelled.";
    fi
  else
    if [ -n "$(find . -maxdepth 1 -name '*.orig*')" ]; then
      mkdir -p "./orig";
      find . -maxdepth 1 -name "*.orig*" -exec mv -t "./orig/" {} +;
      stderr "Archived backups to ./orig/";
    else
      stderr "No backup files found to archive.";
    fi
  fi
}

do_spy(){ __extract_function_body "$1" "$2"; }
do_extract(){
  local func_name="$1";
  local func_body;
  func_body=$(__extract_function_body "$1" "$2");
  [ -z "$func_body" ] && fatal "Function '${func_name}' not found.";
  mkdir -p "./func";
  printf "%s\n" "$func_body" > "./func/${func_name}.extracted.sh";
  stderr "Extracted function to './func/${func_name}.extracted.sh'";
}

do_check(){
  local orig_name="$1";
  local orig_file="./func/${orig_name}.orig.sh";
  ! is_file "$orig_file" && fatal "Origin file not found: '$orig_file'";
  local edit_name;
  edit_name=$(__parse_meta_header "edit" "$orig_file");
  local edit_file="./func/${edit_name}.edit.sh";
  ! is_file "$edit_file" && fatal "Corresponding edit file not found: '$edit_file'";
  local cs1;
  cs1=$(__extract_function_body "$orig_name" "$orig_file" | __checksum);
  local cs2;
  cs2=$(__extract_function_body "$edit_name" "$edit_file" | __checksum);
  if [ "$cs1" == "$cs2" ]; then
    stderr "No changes detected.";
    return 1;
  else
    stderr "Changes detected.";
    return 0;
  fi
}

do_meta(){
  local file_path="./func/${1}"
  ! is_file "$file_path" && fatal "File not found in ./func/: '$1'";
  grep "^# FUNC_META" "$file_path";
}

do_flag(){
  local line_num
  line_num=$(__find_function_line "$1" "$3");
  [ -z "$line_num" ] && fatal "Function '${1}' not found.";
  local marker_text="# FUNC_INSERT ./func/${2}.edit.sh";
  printf -v marker_block '\n\n\n\n%s' "${marker_text}";
  sed "${line_num}i\\${marker_block}" "${3}" > "${3}.tmp" && __safe_mv "${3}.tmp" "${3}";
  stderr "Flag for '${2}' inserted.";
}

do_point(){ __find_flag_line "$1" "$2"; }
do_where(){
  local line_num;
  line_num=$(__find_function_line "$1" "$2");
  [ -z "$line_num" ] && echo "-1" || echo "$line_num";
}

do_ls(){ grep -E '^[[:space:]]*[a-zA-Z0-9_]+\s*\(\s*\)\s*\{' "$1" | sed -E 's/^[[:space:]]*//;s/\s*\(.*//'; }
do_find(){ do_ls "$2" | grep "$1"; }


# --- Core Application Logic ---

usage(){
  cat << EOF
func v${VERSION}
Usage: func <command> [args...]

A powerful, safety-conscious utility for the FIIP workflow.

WORKFLOW COMMANDS:
  copy <func> <src> [--alias <new>] [-f|--force]
  insert <new_func> <src> [-y|--yes] [-f|--force]
  done <func_name>
  clean [-f|--force]

UTILITY COMMANDS:
  spy <func> <src>
  extract <func> <src>
  check <func_name>
  meta <func_file_in_func_dir>
  flag <func> <new> <src>
  point <new> <src>
  where <func> <src> [--bash]
  ls <src> [--bash]
  find <pattern> <src> [--bash]

GLOBAL FLAGS:
  -y, --yes          Answers 'yes' to confirmation prompts.
  -f, --force        Overrides safety guards (e.g., file overwrites).
  -q, --quiet        Suppresses all stderr output.
  --alias <name>     Provides a custom name for 'copy' command.
  --bash             Treats source file as a shell script, bypassing validation.
  -h, --help         Displays this help message.
  --version          Displays version information.
EOF
}

version(){
  cat << EOF
Func, version $VERSION,(BashFX Utility) (requires Bash 3.2+)
Copyright (C) 2025, Qodeninja. Qodeninja Software.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>

This is free software; you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

A commercial license with different terms, including no copyleft restrictions,
is available separately for business use. 

For more information, please visit githb.com/qodeninja/fx-func.
EOF
}

options(){
  local args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      (-y|--yes) opt_yes=1; shift; ;;
      (-f|--force) opt_force=1; shift; ;;
      (-q|--quiet) QUIET_MODE=1; shift; ;;
      (--alias) opt_alias="$2"; shift 2; ;;
      (--bash) opt_bash=1; shift; ;;
      (-h|--help) args+=("help"); shift; ;;
      (--version) args+=("version"); shift; ;;
      (-*) fatal "Unknown option: $1"; ;;
      (*) args+=("$1"); shift; ;;
    esac
  done
  # Reset positional parameters to the cleaned list
  set -- "${args[@]}";
}

dispatch(){
  local command="$1";
  local src_path="";
  # Identify which argument is the source path for validation
  case "$command" in
    (copy|flag|where|ls|find|spy|extract) src_path="${@: -1}"; ;;
    (insert|point) src_path="$2"; ;;
  esac

  if [ -n "$src_path" ]; then
    if ! is_valid_shell_source "$src_path"; then
      fatal "Source file '${src_path}' does not appear to be a valid shell script. Use --bash to override."
    fi
  fi

  case "$command" in
    (copy) do_copy "$2" "$3"; ;;
    (insert) do_insert "$2" "$3"; ;;
    (done) do_done "$2"; ;;
    (clean) do_clean; ;;
    (spy) do_spy "$2" "$3"; ;;
    (extract) do_extract "$2" "$3"; ;;
    (check) do_check "$2"; ;;
    (meta) do_meta "$2"; ;;
    (flag) do_flag "$2" "$3" "$4"; ;;
    (point) do_point "$2" "$3"; ;;
    (where) do_where "$2" "$3"; ;;
    (ls) do_ls "$2"; ;;
    (find) do_find "$2" "$3"; ;;
    (*) fatal "Internal dispatch error: Unhandled command '$command'"; ;;
  esac
}

main(){
  options "$@";
  set -- "$@"; # Set positional params to the cleaned list from options()

  local command="$1";

  # --- Pre-dispatch Handler for Independent Commands ---
  case "$command" in
    (help) usage; exit 0; ;;
    (version) version; exit 0; ;;
    ("") usage; exit 1; ;;
  esac

  dispatch "$@";
}


main "$@";
