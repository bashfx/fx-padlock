# BRIEF: Repo-Scoped Encryption with `age` (Git clean/smudge)

## Goal

Developer wants to encrypt one or more **secure folders** so that code meant to be confidential is **encrypted at commit time** (pre‑commit/post‑add). Locally these secure folders stay **unencrypted for normal editing**. The recommended CLI is [Go ](https://github.com/FiloSottile/age)[`age`](https://github.com/FiloSottile/age), though other tools can be adapted.

Additionally, this design should support **AI agents and virtualized/CI environments** where code is checked out and must be decrypted automatically using a provided **key phrase or key file**.

---

## How it works

- **Smudge** (checkout): Git runs a command that **decrypts** blobs before writing them to the working tree.
- **Clean** (commit): Git runs a command that **encrypts** plaintext before writing to the Git object store.
- **.gitattributes** binds those filters to `secure/**`.
- **Hooks** nudge users to set keys and re-checkout `secure/` after clone/merge.

Crypto engine: [`age`](https://github.com/FiloSottile/age) (modern, tiny, scriptable).\
Modes:

- **Public-key** (recommended): `AGE_RECIPIENT="age1..."` + `AGE_KEY_FILE=~/.config/age/key.txt`
- **Symmetric**: `AGE_PASSPHRASE="..."` (shared secret)

---

## What each project repo needs

```
your-repo/
  secure/                 # plaintext locally; encrypted in Git
  .gitattributes          # binds filter to secure/**
  .githooks/              # repo-scoped hooks (core.hooksPath=.githooks)
    post-checkout
    post-merge
    pre-commit
  scripts/
    setup-crypto.sh       # wires git filters + hooks for this clone
  BRIEF.md                # this file
```

### Minimal contents

**.gitattributes**

```gitattributes
secure/** filter=agecrypt diff=agecrypt
```

**scripts/setup-crypto.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Ensure age is installed
command -v age >/dev/null 2>&1 || { echo "age not installed"; exit 1; }

# Wire the filter
if [[ -n "${AGE_RECIPIENT:-}" ]]; then
  git config filter.agecrypt.clean  "age -R <(printf '%s' $AGE_RECIPIENT)"
  git config filter.agecrypt.smudge "age -d -i ${AGE_KEY_FILE:-$HOME/.config/age/key.txt}"
else
  git config filter.agecrypt.clean  "age -p"
  git config filter.agecrypt.smudge "age -d -p"
fi

git config filter.agecrypt.required true
git config core.hooksPath .githooks
```

**.githooks/post-checkout**

```bash
#!/usr/bin/env bash
set -euo pipefail

if git ls-files --error-unmatch secure >/dev/null 2>&1; then
  git checkout -- secure || true
fi
```

**.githooks/post-merge**

```bash
#!/usr/bin/env bash
set -euo pipefail

git checkout -- secure || true
```

**.githooks/pre-commit**

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! git config --get filter.agecrypt.clean >/dev/null; then
  echo "[pre-commit] age filter not configured; run scripts/setup-crypto.sh" >&2
  exit 1
fi
```

---

## Developer workflow

1. **Clone**
   ```bash
   sudo apt update
   sudo apt install -y age
   export AGE_RECIPIENT="age1..."
   export AGE_KEY_FILE="$HOME/.config/age/key.txt"
   # or: export AGE_PASSPHRASE="..."
   bash scripts/setup-crypto.sh
   ```
2. Work normally in `secure/` (plaintext).
3. Commit/push → Git stores **encrypted** blobs.
4. Pull/merge → hooks refresh `secure/` to plaintext.

---

## CI/CD notes

- Add decrypt material via secrets:
  - Public-key: mount `AGE_KEY_FILE`
  - Symmetric: set `AGE_PASSPHRASE`
- Run `bash scripts/setup-crypto.sh` in pipeline before touching `secure/`.
- **Ensure **``** is installed in automated environments**:
  ```bash
  sudo apt update
  sudo apt install -y age
  ```
  (Include this in your CI job, Claude/Jules/Codex automation step, or container build.)

---

## Security characteristics

- **Contents encrypted**; **filenames are not**.
- Keys never committed.
- Rotate/add recipients by changing `AGE_RECIPIENT` and re-committing.

---

## Recovery checklist

- Lost key: without `AGE_KEY_FILE` backup, data is unrecoverable.
- Accidental plaintext commit: use `git filter-repo` to purge and recommit with filter.

---

## Alternatives

- **git-crypt** (team-friendly, GPG/age)
- **git-secret / blackbox** (explicit hide/reveal)
- **Cryptomator** (mount-based vault)
- **Single-blob** (`tar | age`) if you need to hide filenames/structure



---

## Appendix: Copy‑Paste Setup (Code)

> Drop these files into the paths shown. Make each hook executable: `chmod +x .githooks/*`.

### 1) Repo layout (reference)

```text
your-repo/
  secure/
  .gitattributes
  .githooks/
    post-checkout
    post-merge
    pre-commit
  scripts/
    setup-crypto.sh
  BRIEF.md
```

### 2) `.gitattributes`

```gitattributes
# Encrypt everything under secure/ via age clean/smudge filters
secure/** filter=agecrypt diff=agecrypt
```

### 3) `scripts/setup-crypto.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===== User-configurable (via env) =====
: "${AGE_RECIPIENT:=}"      # e.g. export AGE_RECIPIENT="age1xxxx,..."
: "${AGE_PASSPHRASE:=}"     # alternative to recipients (symmetric mode)
: "${AGE_KEY_FILE:=${HOME}/.config/age/key.txt}"  # path to private key for decryption

# ===== Ensure dependencies =====
if ! command -v age >/dev/null 2>&1; then
  echo "[setup-crypto] 'age' not found. Install it first (e.g. 'sudo apt install -y age')." >&2
  exit 1
fi

# ===== Configure git filter =====
# Clean: plaintext -> ciphertext before storing in git objects
# Smudge: ciphertext -> plaintext when writing to working tree

git config filter.agecrypt.required true

if [[ -n "$AGE_RECIPIENT" ]]; then
  # Public-key mode (one or more recipients, comma-separated)
  git config filter.agecrypt.clean  "sh -c 'age -R <(printf "%s
" "$AGE_RECIPIENT")'"
  git config filter.agecrypt.smudge "sh -c '([ -f "$AGE_KEY_FILE" ] && age -d -i "$AGE_KEY_FILE") || age -d'"
else
  # Symmetric (passphrase) mode
  git config filter.agecrypt.clean  "sh -c '[ -n "$AGE_PASSPHRASE" ] && AGE_PASSPHRASE="$AGE_PASSPHRASE" age -p || age -p'"
  git config filter.agecrypt.smudge "sh -c '[ -n "$AGE_PASSPHRASE" ] && AGE_PASSPHRASE="$AGE_PASSPHRASE" age -d -p || age -d -p'"
fi

# Use repo-scoped hooks
git config core.hooksPath .githooks

# Make hooks executable if present
chmod +x .githooks/* 2>/dev/null || true

echo "[setup-crypto] Filter + hooks configured. secure/ will be encrypted in git, plaintext locally."
```

### 4) `.githooks/post-checkout`

```bash
#!/usr/bin/env bash
set -euo pipefail

# If secure/ contains age ciphertext, force a re-checkout to trigger smudge
if git ls-files --error-unmatch secure >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do
    if head -c 23 "$f" 2>/dev/null | grep -q 'age-encryption.org'; then
      echo "[post-checkout] Detected encrypted secure/. Refreshing..."
      git checkout -- secure || true
      break
    fi
  done < <(git ls-files -z secure)
fi
```

### 5) `.githooks/post-merge`

```bash
#!/usr/bin/env bash
set -euo pipefail

# If merge touched secure/, refresh working copies to apply smudge
if git diff --name-only --diff-filter=AMRT HEAD@{1} | grep -q '^secure/'; then
  echo "[post-merge] Refreshing secure/ after merge..."
  git checkout -- secure || true
fi
```

### 6) `.githooks/pre-commit`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Ensure the filter is configured
if ! git config --get filter.agecrypt.clean >/dev/null; then
  echo "[pre-commit] age filter not configured. Run scripts/setup-crypto.sh" >&2
  exit 1
fi

# Ensure files under secure/ are matched by the filter attribute
changed=$(git diff --cached --name-only --diff-filter=ACM | grep '^secure/' || true)
if [[ -n "$changed" ]]; then
  while read -r f; do
    [[ -z "$f" ]] && continue
    attr=$(git check-attr filter -- "$f" | awk '{print $3}')
    if [[ "$attr" != "agecrypt" ]]; then
      echo "[pre-commit] $f is under secure/ but not filtered (attr=$attr). Fix .gitattributes." >&2
      exit 1
    fi
  done <<< "$changed"
fi
```

### 7) Quickstart (developers / bots)

```bash
# Install dependency (Debian/Ubuntu)
sudo apt update && sudo apt install -y age

# Public-key mode (recommended)
age-keygen -o ~/.config/age/key.txt
export AGE_KEY_FILE="$HOME/.config/age/key.txt"
export AGE_RECIPIENT="$(grep '^# public key:' "$AGE_KEY_FILE" | awk '{print $4}')"

# or symmetric mode
# export AGE_PASSPHRASE="your-strong-passphrase"

# Wire filters and hooks
bash scripts/setup-crypto.sh
```

### 8) Notes / Behavior

```text
- Encrypted at rest in git; plaintext in working tree.
- Filenames are visible. To hide names/structure, commit a single archive (tar|zstd|age) instead.
- Keys are never committed. Share access by distributing AGE_RECIPIENTs (public keys) or a passphrase.
- CI: provide AGE_KEY_FILE or AGE_PASSPHRASE via secrets before running setup-crypto.sh.
- Rotate recipients: update AGE_RECIPIENT and touch files in secure/ to re-encrypt on next commit.
```

