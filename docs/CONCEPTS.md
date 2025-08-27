# Padlock Key Hierarchy & Command Structure

## Key Hierarchy (Authority Chain)

```
X => M => R => I => D
```

### Key Types
- **X (Skull Key)**: Master ignition key - ultimate backup authority (passphrase-wrapped)
- **M (Master Key)**: Global master key for all repos  
- **R (Repo Key)**: Individual repository encryption key
- **I (Repo-Ignition Master Key)**: Authority key that bridges R to D keys (passphrase-wrapped)
- **D (Distro Key)**: Distributed third-party/AI access keys (passphrase-wrapped)

### Ignition Key Concept
An "ignition key" is **any key wrapped by a passphrase**. You access the actual key via the passphrase. This includes:
- **X**: Skull ignition key (passphrase unlocks master key)
- **I**: Repo-ignition master key (passphrase unlocks repo access authority) 
- **D**: Distributed ignition key (passphrase unlocks repo access for third parties)

**I** is NOT a third-party access key - it's the **authority key** that controls D keys. **D** keys are the actual third-party access keys.

### Authority Relationships

**Authority flows DOWN the chain:**
- X has authority over M (skull can unlock master)
- M has authority over R (master can unlock any repo)  
- R has authority over I (repo controls its ignition keys)
- I has authority over D (ignition keys control their distro keys)

**Subject relationships flow UP the chain:**
- M is subject to X (master is controlled by skull)
- R is subject to M (repo is controlled by master)
- I is subject to R (ignition is controlled by repo)
- D is subject to I (distro is controlled by ignition)

### Key Testing Commands

```bash
# Authority tests (parent -> child):
padlock key authority --key1=/path/skull.key --key2=/path/master.key
padlock key authority --key1=/path/master.key --key2=/path/repo.key
padlock key authority --key1=/path/repo.key --key2=/path/ignition.key
padlock key authority --key1=/path/ignition.key --key2=/path/distro.key

# Subject tests (child of parent):
padlock key subject --key1=/path/master.key --key2=/path/skull.key
padlock key subject --key1=/path/repo.key --key2=/path/master.key
padlock key subject --key1=/path/ignition.key --key2=/path/repo.key
padlock key subject --key1=/path/distro.key --key2=/path/ignition.key

# Type detection:
padlock key is skull --key=/path/maybe.key
padlock key is master --key=/path/maybe.key
padlock key is ignition --key=/path/maybe.key
padlock key is expired --key=/path/maybe.key

# Type identification:
padlock key type --key=/path/mystery.key    # Returns: skull|master|repo|ignition|distro|unknown
```

## Command Structure Patterns

### Mini-Dispatchers
Commands are organized into logical namespaces:

```bash
# Master key operations
padlock master generate
padlock master show  
padlock master restore
padlock master unlock

# Ignition key operations  
padlock ignite create [name]
padlock ignite unlock [name]
padlock ignite allow <pubkey>

# Generic key operations
padlock key is <type> --key=/path
padlock key authority --key1=/path --key2=/path
padlock key subject --key1=/path --key2=/path
padlock key type --key=/path
```

### Argument Patterns

**Positional Arguments**: Required inputs, natural order
```bash
padlock ignite create ai-bot        # name is positional
padlock rotate ignition ai-bot      # type and name are positional
```

**Flag Arguments**: Optional modifiers, clarify ambiguous inputs
```bash
padlock ignite create ai-bot --phrase="secret"   # modifier at end
padlock key is skull --path=/maybe/key          # clarify path vs flag
```

### Rotation Clarity
Always specify WHAT is being rotated:

```bash
padlock rotate master              # Rotate master key
padlock rotate ignition [name]     # Rotate ignition key  
padlock rotate distro [name]       # Rotate distro key
# NOT: padlock rotate (rotate what??)
```

### Revocation Clarity  
Always specify WHAT is being revoked:

```bash
padlock revoke ignition [name]     # Revoke ignition key
padlock revoke distro [name]       # Revoke distro key  
# NOT: padlock revoke (revoke what??)
```

## Security Model

### Revocation Boundaries
- Rotating **I** keys invalidates ALL **D** keys derived from them
- Rotating **R** keys invalidates ALL **I** and **D** keys for that repo
- Rotating **M** key invalidates ALL **R**, **I**, and **D** keys globally

### Access Patterns
- **AI/Automation**: Uses **D** keys (distributed ignition keys) with `PADLOCK_IGNITION_PASS` environment variable
- **Repo Authority**: Uses **I** keys (repo-ignition master) to manage D key access
- **Human Users**: Uses **R** keys directly or **M** key for emergency access
- **Emergency Recovery**: Uses **X** skull ignition key to restore **M** master key

### Upstream Expiration
Repository-controlled auto-rotation:
- Repo tracks when ignition keys were created
- Auto-rotates **I** keys after configured period (e.g., 6 months)
- Cannot be bypassed by filename/clock manipulation
- Repository owner controls the expiration policy

## Final Clean Command API

```bash
# Repository management
padlock clamp /repo [--with-ignition]
padlock release /repo
padlock status

# Daily operations
padlock lock
padlock unlock

# Master key dispatcher  
padlock master generate
padlock master show
padlock master restore
padlock master unlock

# Ignition dispatcher
padlock ignite create [name] [--phrase="..."]
padlock ignite unlock [name]  
padlock ignite allow <pubkey>

# Generic key operations
padlock key is <type> --path=/path
padlock key authority <key1> <key2>
padlock key subject <key1> <key2>

# Rotation (verb-first, explicit)
padlock rotate master
padlock rotate ignition [name] 
padlock rotate distro [name]

# Revocation (explicit predicate)
padlock revoke ignition [name]
padlock revoke distro [name]

# File security operations
padlock sec /path              # Secure file (was: map)
padlock dec /path              # De-secure file (was: unmap)  
padlock autosec                # Auto-secure sensitive files

# Discovery (command + filter)
padlock ls [ignition|repos]
padlock clean [--dry-run]

# Repository repair (intelligent)
padlock repair                 # Smart repair for lockout situations

# Internal events
padlock _on_commit             # Git pre-commit hook
padlock _on_checkout           # Git post-checkout hook
```

## Mental Models

### Clamp/Release
- **Clamp**: "We're clamping down security - this is serious, you could get locked out"
- **Release**: "Release the clamp, back to normal state"

### Ignition Keys  
- **Ignition Key**: Any key wrapped by a passphrase - you unlock the actual key via passphrase
- **I (Repo-Ignition Master)**: Authority key that bridges repo to distributed access, maintains security veil
- **D (Distributed Ignition)**: Third-party access keys derived from and controlled by I keys
- Used for passphrase-based access where `PADLOCK_IGNITION_PASS` unlocks the key

### Authority Chain
- Keys have **parent/child relationships** following the math hierarchy
- Authority flows **down** the chain (parents control children)
- Subject relationships flow **up** the chain (children are subject to parents)
