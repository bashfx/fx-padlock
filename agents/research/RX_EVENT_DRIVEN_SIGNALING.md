# RX_EVENT_DRIVEN_SIGNALING.md

## Research: Event-Driven Agent Notification System

### Problem Statement
Current workflow requires manual "tapping" agents when task states change. Agents need automatic notification when:
- TASK moves from DEV_COMPLETE → needs AA review
- TASK moves from VALIDATED → needs QA validation  
- Any state change requiring specific agent action

### Research Findings: 2025 State-of-Art

#### Key Architectural Patterns
1. **Event Streams with Immutable Logs** - Every state change recorded permanently
2. **Pub/Sub with Agent Subscriptions** - Agents subscribe to relevant event types
3. **State-Triggered Workflows** - Automatic transitions based on state checkpoints
4. **Message Brokers for Real-Time Processing** - Redis/Kafka for low-latency signaling
5. **Finite State Machine Event Processing** - Structured state transitions with event triggers

#### Modern Implementation Approaches

**Pattern 1: Event Bus Architecture**
```
State Change → Event Bus → Filtered Subscriptions → Agent Notifications
```

**Pattern 2: Immutable Event Log**
```
Task State Change → Append to Log → Log Watchers → Agent Triggers
```

**Pattern 3: Direct Message Queues**
```
State Change → Agent-Specific Queue → Pull/Push Notification
```

### Technical Design: BashFX Team Event System

#### Core Architecture

**1. Event Generation Layer**
```bash
# State change detection
emit_task_event() {
    local task_id="$1"
    local old_state="$2" 
    local new_state="$3"
    local timestamp="$(date -Iseconds)"
    
    # Generate event
    local event="{\"task_id\":\"$task_id\",\"old_state\":\"$old_state\",\"new_state\":\"$new_state\",\"timestamp\":\"$timestamp\"}"
    
    # Multiple notification channels
    append_to_event_log "$event"
    signal_subscribed_agents "$event"
    update_agent_queues "$event"
}
```

**2. Agent Subscription Registry**
```bash
# Agent interest patterns
declare -A AGENT_SUBSCRIPTIONS=(
    ["@AA"]="DEV_COMPLETE,REVIEW_NEEDED"
    ["@QA"]="VALIDATED,REVIEW_COMPLETE"
    ["@LSE"]="BLOCKED_TECHNICAL,SPEC_CHANGE"
    ["@PRD"]="FEATURE_COMPLETE,RELEASE_READY"
    ["@OXX"]="CRITICAL_ISSUE,DECISION_NEEDED"
)
```

**3. Multiple Signaling Channels**

#### Channel A: File-Based Event Log (Immediate Implementation)
```bash
# Simple append-only event log
EVENT_LOG="./events/task_events.jsonl"

emit_event() {
    echo "$event" >> "$EVENT_LOG"
    # Signal all watchers
    touch "$EVENT_LOG.signal"
}

# Agent polling/watching
watch_events() {
    local agent="$1"
    local last_seen="$(cat .events/${agent}_last_seen 2>/dev/null || echo 0)"
    
    # Check for new events since last_seen
    tail -n +$((last_seen + 1)) "$EVENT_LOG" | while read -r event; do
        if should_notify_agent "$agent" "$event"; then
            notify_agent "$agent" "$event"
        fi
    done
}
```

#### Channel B: Directory-Based Signaling (Cross-Session)
```bash
# Create agent notification directories
./notifications/
├── @AA/
│   ├── pending/
│   └── processed/
├── @QA/
│   ├── pending/
│   └── processed/
└── @OXX/
    ├── pending/
    └── processed/

# Signal by creating notification files
signal_agent() {
    local agent="$1"
    local event="$2"
    local notification_file="./notifications/${agent}/pending/$(date +%s)_$(uuidgen | cut -d- -f1).json"
    
    echo "$event" > "$notification_file"
}
```

#### Channel C: Process-Based Signaling (Real-Time)
```bash
# Use named pipes for live signaling
create_agent_pipes() {
    for agent in "@AA" "@QA" "@LSE" "@PRD" "@OXX"; do
        mkfifo "./pipes/${agent}_notifications" 2>/dev/null || true
    done
}

signal_via_pipe() {
    local agent="$1" 
    local event="$2"
    
    # Non-blocking write to pipe
    if [[ -p "./pipes/${agent}_notifications" ]]; then
        echo "$event" > "./pipes/${agent}_notifications" &
    fi
}
```

### Smart Notification Filtering

#### State Transition Rules
```bash
# Define which agents care about which transitions
declare -A STATE_TRANSITIONS=(
    ["*→DEV_COMPLETE"]="@AA"
    ["*→VALIDATED"]="@QA"  
    ["*→BLOCKED"]="@OXX"
    ["*→SPEC_CHANGE"]="@LSE,@PRD"
    ["*→CRITICAL"]="@OXX,@AA,@QA"
    ["DEV_COMPLETE→AA_REVIEW"]="@AA"
    ["VALIDATED→QA_REVIEW"]="@QA"
)

should_notify_agent() {
    local agent="$1"
    local event="$2"
    
    local transition="$(echo "$event" | jq -r '.old_state + "→" + .new_state')"
    local wildcard_transition="$(echo "$event" | jq -r '"*→" + .new_state')"
    
    # Check both specific and wildcard transitions
    if [[ "${STATE_TRANSITIONS[$transition]}" == *"$agent"* ]] || 
       [[ "${STATE_TRANSITIONS[$wildcard_transition]}" == *"$agent"* ]]; then
        return 0
    fi
    return 1
}
```

### Implementation Phases

#### Phase 1: Basic File-Based Events (Immediate - 2 Story Points)
- Append-only event log for state changes
- Simple agent polling mechanism
- Basic notification filtering

#### Phase 2: Directory-Based Persistent Signaling (Short-term - 3 Story Points)  
- Agent-specific notification directories
- Cross-session persistence
- Processed/pending tracking

#### Phase 3: Real-Time Process Signaling (Medium-term - 5 Story Points)
- Named pipes for live notifications
- Background monitoring processes
- Interactive agent alerting

#### Phase 4: Advanced Event Processing (Long-term - 8 Story Points)
- Complex event patterns
- Event aggregation and batching
- Historical event querying

### Usage Examples

#### Triggering Events
```bash
# In task management code
update_task_state() {
    local task_id="$1"
    local new_state="$2"
    local old_state="$(get_current_state "$task_id")"
    
    # Update state
    set_task_state "$task_id" "$new_state"
    
    # Emit event for signaling
    emit_task_event "$task_id" "$old_state" "$new_state"
}
```

#### Agent Consumption
```bash
# Agent checks for work
@AA_check_work() {
    # Check notifications
    check_agent_notifications "@AA"
    
    # Or poll event stream
    watch_events "@AA" | while read -r event; do
        handle_aa_notification "$event"
    done
}
```

### Benefits of Event-Driven Approach

#### Immediate Benefits
- **Eliminates Manual Tapping**: Automatic notification when work is ready
- **Cross-Session Persistence**: Agents get notified even after restarts
- **Selective Filtering**: Only relevant notifications reach each agent
- **Audit Trail**: Complete history of state changes and notifications

#### Scalability Benefits  
- **Loose Coupling**: Agents don't need to know about each other
- **Parallel Processing**: Multiple agents can respond to same events
- **Resilience**: Failed notifications don't block state changes
- **Extensibility**: Easy to add new agents or notification types

#### Workflow Improvements
- **Reduced Latency**: Immediate notification vs periodic checking
- **Better Coordination**: Clear handoffs between agents
- **Improved Reliability**: No missed work due to missed notifications
- **Enhanced Observability**: Full event log for debugging workflows

### Risk Assessment

#### Low Risk Components
- File-based event logging (proven pattern)
- Directory-based signaling (filesystem reliable)
- JSON event format (simple, debuggable)

#### Medium Risk Components  
- Process-based signaling (pipes can block)
- Complex filtering rules (potential for bugs)
- Cross-platform compatibility (different OS behaviors)

#### Mitigation Strategies
- Multiple signaling channels (redundancy)
- Simple event format (easy to debug)
- Graceful degradation (fallback to polling)
- Comprehensive testing across platforms

### Recommendation

**Immediate Implementation**: Start with Phase 1 (file-based events) for instant workflow improvement with minimal risk.

**Architecture**: Use hybrid approach - file-based persistence with optional real-time channels for responsive workflows.

**Integration**: Build into existing task state management functions to automatically generate events on all state changes.

This event-driven signaling system will eliminate manual agent coordination while providing a scalable foundation for complex multi-agent workflows.
