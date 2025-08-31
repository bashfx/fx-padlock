# Age TTY Subversion Research

**Goal**: Find reliable methods to automate `age -p` (passphrase mode) without interactive prompts.

**Problem**: `age -p` requires TTY input and doesn't accept piped passphrases, making it unusable in automated/test environments.

## Methods to Test

1. **script command variations**
2. **expect/unbuffer approaches** 
3. **socat/pty manipulation**
4. **heredoc/process substitution**
5. **Alternative age usage patterns**

## Test Cases
- Single passphrase
- Passphrase with special characters (`'`, `"`, `$`, etc.)
- Command injection prevention validation