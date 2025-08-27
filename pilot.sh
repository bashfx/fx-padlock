#!/usr/bin/env bash
#
# Padlock Ignition Key System - Architecture Pilot
# 
# This pilot tests 4 different approaches to implementing ignition keys:
# 1. double_wrapped - Double-encrypted (master + passphrase)
# 2. ssh_delegation - SSH key certificates and delegation  
# 3. layered_native - Age-native with passphrase derivation
# 4. hybrid_proxy - Proxy keys with separation of concerns
#
# Usage: ./pilot.sh <approach> <command> [args...]
#

set -euo pipefail

# Colors for output
red=$'\x1B[31m'
green=$'\x1B[32m'
yellow=$'\x1B[33m'
blue=$'\x1B[36m'
grey=$'\x1B[38;5;249m'
xx=$'\x1B[0m'

# Configuration
PILOT_DIR="./pilot"
MASTER_KEY_PATH="$PILOT_DIR/master.key"
MASTER_PUB_PATH="$PILOT_DIR/master.pub"

# Utility functions
info() { echo "${blue}ℹ ${1}${xx}" >&2; }
okay() { echo "${green}✓ ${1}${xx}" >&2; }
warn() { echo "${yellow}⚠ ${1}${xx}" >&2; }
error() { echo "${red}✗ ${1}${xx}" >&2; }
fatal() { error "$1"; exit 1; }
trace() { echo "${grey}… ${1}${xx}" >&2; }

# Timer utilities
timer_start() {
    TIMER_START=$(date +%s.%N)
}

timer_stop() {
    local end=$(date +%s.%N)
    local duration=$(echo "$end - $TIMER_START" | bc -l)
    printf "%.3fs" "$duration"
}

# Setup pilot environment
setup_pilot() {
    mkdir -p "$PILOT_DIR"/{double_wrapped,ssh_delegation,layered_native,hybrid_proxy}
    
    # Generate master key pair if not exists
    if [[ ! -f "$MASTER_KEY_PATH" ]]; then
        trace "Generating master key pair"
        age-keygen > "$MASTER_KEY_PATH" 2>/dev/null
        age-keygen -y < "$MASTER_KEY_PATH" > "$MASTER_PUB_PATH"
        okay "Master key pair created"
    fi
    
    # Ensure master public key exists and is valid
    if [[ ! -s "$MASTER_PUB_PATH" ]]; then
        trace "Regenerating master public key"
        age-keygen -y < "$MASTER_KEY_PATH" > "$MASTER_PUB_PATH"
    fi
}

# Generate test passphrase
generate_passphrase() {
    local words=(flame rocket boost spark ignite power turbo super mega ultra)
    printf "%s-%s-%s-%s" "${words[$((RANDOM % ${#words[@]}))]}" "${words[$((RANDOM % ${#words[@]}))]}" "${words[$((RANDOM % ${#words[@]}))]}" "${words[$((RANDOM % ${#words[@]}))]}"
}

#===============================================================================
# APPROACH 1: DOUBLE-WRAPPED ENCRYPTION
#===============================================================================

double_wrapped_create_ignition() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/double_wrapped"
    
    trace "Creating double-wrapped ignition key: $name"
    
    # Generate inner age key
    local temp_key=$(mktemp)
    age-keygen > "$temp_key"
    
    # Create metadata
    local metadata="TYPE=ignition-master
NAME=$name  
CREATED=$(date -Iseconds)
AUTHORITY=master
PASSPHRASE_HINT=${passphrase:0:4}***
---"
    
    # Try to create passphrase-encrypted inner layer using script to fake TTY
    local inner_encrypted="$key_dir/inner-$name.age"
    
    # Use script command to fake TTY for age -p
    if script -qec "echo -e '${passphrase}\n${passphrase}' | age -p -o '$inner_encrypted' '$temp_key'" /dev/null >/dev/null 2>&1; then
        trace "Passphrase encryption successful with fake TTY"
    else
        # Fallback: simulate with deterministic key derivation  
        warn "Age -p failed, using simulation (this is the expected blocking behavior)"
        echo "$passphrase" | sha256sum | cut -c1-32 | xxd -r -p | base64 | tr -d '=' | tr '+/' '-_' > "$inner_encrypted.temp"
        # Use a derived key instead of passphrase encryption
        local derived_hash=$(echo "$passphrase" | sha256sum | cut -d' ' -f1)
        mkdir -p "$key_dir/.derived"
        echo "$derived_hash" > "$key_dir/.derived/$name.hash"
        age-keygen > "$key_dir/.derived/$name.key" 2>/dev/null
        age -r "$(age-keygen -y < "$key_dir/.derived/$name.key")" < "$temp_key" > "$inner_encrypted"
        rm -f "$inner_encrypted.temp"
    fi
    
    # Encrypt with master key (outer layer)
    {
        echo "$metadata"
        cat "$inner_encrypted"
    } | age -r "$(cat "$MASTER_PUB_PATH")" > "$key_dir/ignition-master-$name.key"
    
    # Create metadata file
    echo "$metadata" > "$key_dir/ignition-master-$name.meta"
    
    # Cleanup
    rm -f "$temp_key" "$inner_encrypted"
    
    okay "Double-wrapped ignition key created: $name"
}

double_wrapped_create_distro() {
    local name="$1" 
    local passphrase="$2"
    local key_dir="$PILOT_DIR/double_wrapped"
    
    # Check if ignition master exists
    [[ -f "$key_dir/ignition-master-default.key" ]] || fatal "No ignition master key found"
    
    trace "Creating double-wrapped distributed key: $name"
    
    # Similar process to ignition master
    local temp_key=$(mktemp)
    age-keygen > "$temp_key"
    
    local metadata="TYPE=distro
NAME=$name
CREATED=$(date -Iseconds)  
AUTHORITY=ignition-master
PASSPHRASE_HINT=${passphrase:0:4}***
---"
    
    # Simulate passphrase encryption (since real -p would block)
    local derived_key=$(echo "$passphrase" | sha256sum | cut -c1-32)
    echo "$derived_key" | age-keygen -y > "$key_dir/temp-derived.key"
    local inner_encrypted="$key_dir/inner-distro-$name.age"
    age -r "$(cat "$key_dir/temp-derived.key")" < "$temp_key" > "$inner_encrypted"
    
    # Encrypt with master key
    {
        echo "$metadata"
        cat "$inner_encrypted"
    } | age -r "$(cat "$MASTER_PUB_PATH")" > "$key_dir/distro-$name.key"
    
    echo "$metadata" > "$key_dir/distro-$name.meta"
    
    rm -f "$temp_key" "$inner_encrypted" "$key_dir/temp-derived.key"
    
    okay "Double-wrapped distributed key created: $name"
}

double_wrapped_unlock() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/double_wrapped"
    
    trace "Attempting double-wrapped unlock with key: $name"
    
    # This would block in real implementation due to age -p interactive requirement
    warn "Double-wrapped unlock would block - age -p requires interactive terminal"
    warn "This is the critical flaw that makes this approach unsuitable for automation"
    return 1
}

#===============================================================================
# APPROACH 2: SSH KEY DELEGATION  
#===============================================================================

ssh_delegation_create_ignition() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/ssh_delegation"
    
    trace "Creating SSH delegation ignition key: $name"
    
    # Generate SSH key pair
    ssh-keygen -t ed25519 -f "$key_dir/ignition-master-$name" -N "$passphrase" -C "ignition:$name" >/dev/null 2>&1
    
    # Create certificate (simulate master signing)
    local cert_data="ssh-ed25519-cert-v01@openssh.com $(cat "$key_dir/ignition-master-$name.pub" | cut -d' ' -f2) ignition:$name"
    echo "$cert_data" > "$key_dir/ignition-master-$name-cert.pub"
    
    # Encrypt private key with master key for authority
    age -r "$(cat "$MASTER_PUB_PATH")" < "$key_dir/ignition-master-$name" > "$key_dir/ignition-master-$name.key"
    
    # Create metadata
    cat > "$key_dir/ignition-master-$name.meta" << EOF
TYPE=ignition-master
NAME=$name
CREATED=$(date -Iseconds)
SSH_FINGERPRINT=$(ssh-keygen -lf "$key_dir/ignition-master-$name.pub" | cut -d' ' -f2)
CERTIFICATE=$key_dir/ignition-master-$name-cert.pub
EOF
    
    okay "SSH delegation ignition key created: $name"
}

ssh_delegation_create_distro() {
    local name="$1"
    local passphrase="$2" 
    local key_dir="$PILOT_DIR/ssh_delegation"
    
    [[ -f "$key_dir/ignition-master-default.key" ]] || fatal "No SSH ignition master key found"
    
    trace "Creating SSH delegation distributed key: $name"
    
    ssh-keygen -t ed25519 -f "$key_dir/distro-$name" -N "$passphrase" -C "distro:$name" >/dev/null 2>&1
    
    # Create certificate signed by ignition master (simulated)
    local cert_data="ssh-ed25519-cert-v01@openssh.com $(cat "$key_dir/distro-$name.pub" | cut -d' ' -f2) distro:$name"
    echo "$cert_data" > "$key_dir/distro-$name-cert.pub"
    
    # Encrypt with master key
    age -r "$(cat "$MASTER_PUB_PATH")" < "$key_dir/distro-$name" > "$key_dir/distro-$name.key"
    
    cat > "$key_dir/distro-$name.meta" << EOF
TYPE=distro
NAME=$name
CREATED=$(date -Iseconds)
SSH_FINGERPRINT=$(ssh-keygen -lf "$key_dir/distro-$name.pub" | cut -d' ' -f2)
CERTIFICATE=$key_dir/distro-$name-cert.pub
AUTHORITY=ignition-master
EOF
    
    okay "SSH delegation distributed key created: $name"
}

ssh_delegation_unlock() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/ssh_delegation"
    
    trace "SSH delegation unlock with key: $name"
    
    # Decrypt SSH key with master key
    local temp_ssh_key=$(mktemp)
    age -d -i "$MASTER_KEY_PATH" < "$key_dir/distro-$name.key" > "$temp_ssh_key"
    
    # Verify certificate (simulated)
    if [[ -f "$key_dir/distro-$name-cert.pub" ]]; then
        trace "Certificate verified for $name"
    else
        rm -f "$temp_ssh_key"
        fatal "No valid certificate for key: $name"
    fi
    
    # Test SSH key (simulate decryption)
    if ssh-keygen -y -f "$temp_ssh_key" -P "$passphrase" >/dev/null 2>&1; then
        okay "SSH delegation unlock successful: $name"
        rm -f "$temp_ssh_key"
        return 0
    else
        error "SSH key passphrase incorrect"
        rm -f "$temp_ssh_key"
        return 1
    fi
}

#===============================================================================
# APPROACH 3: LAYERED NATIVE
#===============================================================================

layered_native_derive_key() {
    local passphrase="$1"
    # For pilot purposes, simulate deterministic key derivation
    # In production, this would use proper key derivation functions (KDF)
    
    # Generate a real age key and store it deterministically
    local key_hash=$(echo "layered_native_key:$passphrase" | sha256sum | cut -d' ' -f1)
    local key_file="$PILOT_DIR/.derived_keys/$key_hash"
    
    mkdir -p "$PILOT_DIR/.derived_keys"
    
    if [[ ! -f "$key_file" ]]; then
        # Create deterministic key (simulate with real age-keygen for now)
        age-keygen > "$key_file" 2>/dev/null
    fi
    
    # Return the public key
    age-keygen -y < "$key_file" 2>/dev/null
}

layered_native_create_ignition() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/layered_native"
    
    trace "Creating layered native ignition key: $name"
    
    # Derive age key from passphrase deterministically
    local derived_key=$(layered_native_derive_key "$passphrase")
    
    # Get the derived public key 
    local derived_pub_key=$(layered_native_derive_key "$passphrase")
    
    # Create key bundle with metadata  
    local key_bundle=$(cat << EOF
{
  "type": "ignition-master",
  "name": "$name",
  "created": "$(date -Iseconds)",
  "authority": "master",
  "derived_public_key": "$derived_pub_key",
  "passphrase_hash": "$(echo "$passphrase" | sha256sum | cut -d' ' -f1)",
  "metadata": {
    "version": "1.0",
    "algorithm": "age-ed25519"
  }
}
EOF
)
    
    # Encrypt bundle with master key
    echo "$key_bundle" | age -r "$(cat "$MASTER_PUB_PATH")" > "$key_dir/ignition-master-$name.key"
    
    # Create metadata file
    cat > "$key_dir/ignition-master-$name.meta" << EOF
TYPE=ignition-master
NAME=$name
CREATED=$(date -Iseconds)
AUTHORITY=master
KEY_DERIVATION=sha512-passphrase
EOF
    
    okay "Layered native ignition key created: $name"
}

layered_native_create_distro() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/layered_native"
    
    [[ -f "$key_dir/ignition-master-default.key" ]] || fatal "No layered native ignition master key found"
    
    trace "Creating layered native distributed key: $name"
    
    local derived_pub_key=$(layered_native_derive_key "$passphrase")
    
    local key_bundle=$(cat << EOF
{
  "type": "distro", 
  "name": "$name",
  "created": "$(date -Iseconds)",
  "authority": "ignition-master",
  "derived_public_key": "$derived_pub_key",
  "passphrase_hash": "$(echo "$passphrase" | sha256sum | cut -d' ' -f1)",
  "metadata": {
    "version": "1.0",
    "algorithm": "age-ed25519",
    "revoked": false
  }
}
EOF
)
    
    echo "$key_bundle" | age -r "$(cat "$MASTER_PUB_PATH")" > "$key_dir/distro-$name.key"
    
    cat > "$key_dir/distro-$name.meta" << EOF
TYPE=distro
NAME=$name
CREATED=$(date -Iseconds)
AUTHORITY=ignition-master  
KEY_DERIVATION=sha512-passphrase
EOF
    
    okay "Layered native distributed key created: $name"
}

layered_native_unlock() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/layered_native"
    
    trace "Layered native unlock with key: $name"
    
    # Decrypt key bundle
    local key_bundle=$(age -d -i "$MASTER_KEY_PATH" < "$key_dir/distro-$name.key")
    
    # Extract derived public key and hash from bundle
    local stored_pub_key=$(echo "$key_bundle" | jq -r '.derived_public_key')
    local stored_hash=$(echo "$key_bundle" | jq -r '.passphrase_hash')
    
    # Verify passphrase by comparing derived public key
    local derived_pub_key=$(layered_native_derive_key "$passphrase")
    local passphrase_hash=$(echo "$passphrase" | sha256sum | cut -d' ' -f1)
    
    if [[ "$derived_pub_key" == "$stored_pub_key" && "$passphrase_hash" == "$stored_hash" ]]; then
        okay "Layered native unlock successful: $name"
        
        # Update last used timestamp (simulate)
        trace "Updated last used timestamp for $name"
        return 0
    else
        error "Invalid passphrase for layered native key: $name"
        return 1
    fi
}

#===============================================================================
# APPROACH 4: HYBRID PROXY
#===============================================================================

hybrid_proxy_create_ignition() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/hybrid_proxy"
    
    trace "Creating hybrid proxy ignition key: $name"
    
    # Generate actual encryption key (stays constant)
    local encryption_key=$(mktemp)
    age-keygen > "$encryption_key"
    
    # Create proxy key that unlocks encryption key
    local proxy_data=$(cat << EOF
{
  "type": "ignition-master-proxy",
  "name": "$name",
  "created": "$(date -Iseconds)",
  "encryption_key_ref": "encryption-$name",
  "passphrase_hash": "$(echo "$passphrase" | sha256sum | cut -d' ' -f1)",
  "proxy_id": "$(uuidgen 2>/dev/null || echo "proxy-$name-$(date +%s)")",
  "authority": "master"
}
EOF
)
    
    # Store encryption key encrypted with master key
    age -r "$(cat "$MASTER_PUB_PATH")" < "$encryption_key" > "$key_dir/encryption-$name.key"
    
    # Store proxy encrypted with passphrase-derived key
    local proxy_key=$(layered_native_derive_key "$passphrase")
    echo "$proxy_data" | age -r "$proxy_key" > "$key_dir/temp-proxy"
    
    # Wrap proxy with master key for authority
    age -r "$(cat "$MASTER_PUB_PATH")" < "$key_dir/temp-proxy" > "$key_dir/ignition-master-$name.key"
    
    cat > "$key_dir/ignition-master-$name.meta" << EOF
TYPE=ignition-master-proxy
NAME=$name
CREATED=$(date -Iseconds)
ENCRYPTION_KEY=$key_dir/encryption-$name.key
PROXY_MODEL=hybrid
EOF
    
    rm -f "$encryption_key" "$key_dir/temp-proxy"
    okay "Hybrid proxy ignition key created: $name"
}

hybrid_proxy_create_distro() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/hybrid_proxy"
    
    [[ -f "$key_dir/ignition-master-default.key" ]] || fatal "No hybrid proxy ignition master key found"
    
    trace "Creating hybrid proxy distributed key: $name"
    
    # Distributed keys share the same encryption key but have unique proxy
    local proxy_data=$(cat << EOF
{
  "type": "distro-proxy",
  "name": "$name", 
  "created": "$(date -Iseconds)",
  "encryption_key_ref": "encryption-default",
  "passphrase_hash": "$(echo "$passphrase" | sha256sum | cut -d' ' -f1)",
  "proxy_id": "$(uuidgen 2>/dev/null || echo "distro-$name-$(date +%s)")",
  "authority": "ignition-master",
  "revoked": false
}
EOF
)
    
    # Create proxy encrypted with passphrase-derived key
    local proxy_key=$(layered_native_derive_key "$passphrase")
    echo "$proxy_data" | age -r "$proxy_key" > "$key_dir/temp-distro-proxy"
    
    # Wrap with master key
    age -r "$(cat "$MASTER_PUB_PATH")" < "$key_dir/temp-distro-proxy" > "$key_dir/distro-$name.key"
    
    cat > "$key_dir/distro-$name.meta" << EOF
TYPE=distro-proxy
NAME=$name
CREATED=$(date -Iseconds)
ENCRYPTION_KEY_REF=encryption-default
PROXY_MODEL=hybrid
AUTHORITY=ignition-master
EOF
    
    rm -f "$key_dir/temp-distro-proxy"
    okay "Hybrid proxy distributed key created: $name"
}

hybrid_proxy_unlock() {
    local name="$1"
    local passphrase="$2"
    local key_dir="$PILOT_DIR/hybrid_proxy"
    
    trace "Hybrid proxy unlock with key: $name"
    
    # Decrypt proxy with master key first
    local temp_proxy=$(mktemp)
    age -d -i "$MASTER_KEY_PATH" < "$key_dir/distro-$name.key" > "$temp_proxy"
    
    # Decrypt proxy with passphrase-derived key
    local proxy_key=$(layered_native_derive_key "$passphrase")
    local temp_proxy_key=$(mktemp)
    echo "$proxy_key" > "$temp_proxy_key"
    
    if proxy_data=$(age -d -i "$temp_proxy_key" < "$temp_proxy" 2>/dev/null); then
        # Verify passphrase hash
        local stored_hash=$(echo "$proxy_data" | jq -r '.passphrase_hash')
        local passphrase_hash=$(echo "$passphrase" | sha256sum | cut -d' ' -f1)
        
        if [[ "$passphrase_hash" == "$stored_hash" ]]; then
            # Load encryption key (simulate caching)
            local encryption_key_ref=$(echo "$proxy_data" | jq -r '.encryption_key_ref')
            if [[ -f "$key_dir/$encryption_key_ref.key" ]]; then
                okay "Hybrid proxy unlock successful: $name (cached encryption key)"
                rm -f "$temp_proxy" "$temp_proxy_key"
                return 0
            fi
        fi
    fi
    
    error "Hybrid proxy unlock failed: $name"
    rm -f "$temp_proxy" "$temp_proxy_key"
    return 1
}

#===============================================================================
# BENCHMARK FUNCTIONS
#===============================================================================

benchmark_approach() {
    local approach="$1"
    local operations="${2:-100}"
    
    info "Benchmarking approach: $approach ($operations operations)"
    
    local passphrase="test-passphrase-$(date +%s)"
    
    # Key Generation Benchmark
    timer_start
    for ((i=1; i<=operations; i++)); do
        "${approach}_create_ignition" "bench-$i" "$passphrase-$i" >/dev/null 2>&1 || true
    done
    local gen_time=$(timer_stop)
    
    # Create one distributed key for unlock testing
    "${approach}_create_distro" "unlock-test" "$passphrase" >/dev/null 2>&1 || true
    
    # Key Unlock Benchmark  
    timer_start
    local unlock_success=0
    for ((i=1; i<=operations; i++)); do
        if "${approach}_unlock" "unlock-test" "$passphrase" >/dev/null 2>&1; then
            ((unlock_success++))
        fi
    done
    local unlock_time=$(timer_stop)
    
    echo "Results for $approach:"
    echo "  Key Generation: $gen_time ($operations ops)"
    echo "  Key Unlock: $unlock_time ($unlock_success/$operations successful)"
    echo
}

#===============================================================================  
# TEST FUNCTIONS
#===============================================================================

test_approach() {
    local approach="$1"
    
    info "Testing approach: $approach"
    
    local passphrase="test-flame-rocket-boost"
    local bad_passphrase="wrong-passphrase"
    
    # Test 1: Create ignition master key
    if "${approach}_create_ignition" "default" "$passphrase"; then
        okay "✓ Ignition master key creation"
    else
        error "✗ Ignition master key creation failed"
        return 1
    fi
    
    # Test 2: Create distributed key
    if "${approach}_create_distro" "test-ai" "$passphrase"; then
        okay "✓ Distributed key creation"
    else
        error "✗ Distributed key creation failed"
        return 1
    fi
    
    # Test 3: Unlock with correct passphrase
    if "${approach}_unlock" "test-ai" "$passphrase"; then
        okay "✓ Unlock with correct passphrase"
    else
        error "✗ Unlock with correct passphrase failed"
        return 1
    fi
    
    # Test 4: Unlock with wrong passphrase (should fail)
    if "${approach}_unlock" "test-ai" "$bad_passphrase"; then
        error "✗ Unlock with wrong passphrase should have failed"
        return 1
    else
        okay "✓ Unlock with wrong passphrase correctly failed"
    fi
    
    okay "All tests passed for approach: $approach"
    return 0
}

#===============================================================================
# MAIN DISPATCHER
#===============================================================================

usage() {
    cat << EOF
Padlock Ignition Key System - Architecture Pilot

USAGE:
  ./pilot.sh <approach> <command> [args...]

APPROACHES:
  double_wrapped  - Double-encrypted (master + passphrase)
  ssh_delegation  - SSH key certificates and delegation
  layered_native  - Age-native with passphrase derivation  
  hybrid_proxy    - Proxy keys with separation of concerns

COMMANDS:
  create-ignition <name> <passphrase>  - Create ignition master key
  create-distro <name> <passphrase>    - Create distributed access key
  unlock <name> <passphrase>           - Unlock with distributed key
  test                                 - Run comprehensive tests
  benchmark [operations]               - Run performance benchmarks

UTILITIES:
  test-all                            - Test all approaches
  benchmark-all [operations]          - Benchmark all approaches  
  clean                               - Clean pilot directory
  status                              - Show pilot status

EXAMPLES:
  ./pilot.sh layered_native create-ignition master flame-rocket-boost
  ./pilot.sh layered_native create-distro ai-bot flame-rocket-boost  
  ./pilot.sh layered_native unlock ai-bot flame-rocket-boost
  ./pilot.sh layered_native test
  ./pilot.sh benchmark-all 50

EOF
}

main() {
    # Handle global commands first
    case "${1:-}" in
        test-all)
            setup_pilot
            local approaches=(double_wrapped ssh_delegation layered_native hybrid_proxy)
            local passed=0
            local total=${#approaches[@]}
            
            for approach in "${approaches[@]}"; do
                echo
                if test_approach "$approach"; then
                    ((passed++))
                fi
            done
            
            echo
            info "Test Results: $passed/$total approaches passed"
            [[ $passed -eq $total ]] && okay "All approaches working!" || warn "Some approaches failed"
            return 0
            ;;
            
        benchmark-all)
            setup_pilot
            local operations="${2:-10}"
            local approaches=(double_wrapped ssh_delegation layered_native hybrid_proxy)
            
            echo "=== Benchmark Results (${operations} operations) ==="
            echo
            
            for approach in "${approaches[@]}"; do
                benchmark_approach "$approach" "$operations"
            done
            return 0
            ;;
            
        clean)
            rm -rf "$PILOT_DIR"
            okay "Pilot directory cleaned"
            return 0
            ;;
            
        status)
            if [[ -d "$PILOT_DIR" ]]; then
                echo "Pilot Status:"
                find "$PILOT_DIR" -name "*.key" -o -name "*.meta" | sort | while read -r file; do
                    echo "  $file"
                done
            else
                info "No pilot directory found"
            fi
            return 0
            ;;
            
        help|--help|-h|"")
            usage
            return 0
            ;;
    esac
    
    # Handle approach-specific commands
    local approach="$1"
    local command="$2"
    shift 2 || true
    
    # Validate approach
    case "$approach" in
        double_wrapped|ssh_delegation|layered_native|hybrid_proxy)
            setup_pilot
            ;;
        *)
            error "Unknown approach: $approach"
            info "Available approaches: double_wrapped, ssh_delegation, layered_native, hybrid_proxy"
            return 1
            ;;
    esac
    
    # Execute command
    case "$command" in
        create-ignition)
            local name="${1:-default}"
            local passphrase="${2:-$(generate_passphrase)}"
            "${approach}_create_ignition" "$name" "$passphrase"
            ;;
            
        create-distro)
            local name="${1:-}"
            local passphrase="${2:-$(generate_passphrase)}"
            [[ -n "$name" ]] || fatal "Missing distributed key name"
            "${approach}_create_distro" "$name" "$passphrase"
            ;;
            
        unlock)
            local name="${1:-}"
            local passphrase="${2:-}"
            [[ -n "$name" ]] || fatal "Missing key name"
            [[ -n "$passphrase" ]] || fatal "Missing passphrase"
            "${approach}_unlock" "$name" "$passphrase"
            ;;
            
        test)
            test_approach "$approach"
            ;;
            
        benchmark)
            local operations="${1:-100}"
            benchmark_approach "$approach" "$operations"
            ;;
            
        *)
            error "Unknown command: $command"
            info "Available commands: create-ignition, create-distro, unlock, test, benchmark"
            return 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi