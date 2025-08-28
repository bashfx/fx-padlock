# RX_TEAM_IMPLEMENTATION_GUIDE.md

## Event-Driven Agent Signaling: Implementation Guide

### Quick Start: Eliminate Manual Tapping in 30 Minutes

#### Step 1: Create Event Infrastructure (5 minutes)
```bash
# Create necessary directories
mkdir -p ./events ./notifications/{@AA,@QA,@LSE,@PRD,@OXX}/{pending,processed}

# Initialize event log
touch ./events/task_events.jsonl
echo "0" > ./events/last_event_id
```

#### Step 2: Add Event Emission to Task Functions (10 minutes)
```bash
# Add to your task management script
emit_task_event() {
    local task_id="$1"
    local old_state="$2" 
    local new_state="$3"
    local timestamp="$(date -Iseconds)"
    local event_id="$(($(cat ./events/last_event_id) + 1))"
    
    # Create event
    local event="{\"id\":$event_id,\"task_id\":\"$task_id\",\"old_state\":\"$old_state\",\"new_state\":\"$new_state\",\"timestamp\":\"$timestamp\"}"
    
    # Log event
    echo "$event" >> ./events/task_events.jsonl
    echo "$event_id" > ./events/last_event_id
    
    # Signal relevant agents
    signal_agents "$event" "$new_state"
}

signal_agents() {
    local event="$1"
    local new_state="$2"
    
    case "$new_state" in
        "DEV_COMPLETE"|"REVIEW_NEEDED")
            echo "$event" > "./notifications/@AA/pending/$(date +%s).json"
            ;;
        "VALIDATED"|"AA_APPROVED")  
            echo "$event" > "./notifications/@QA/pending/$(date +%s).json"
            ;;
        "BLOCKED"|"CRITICAL")
            echo "$event" > "./notifications/@OXX/pending/$(date +%s).json"
            ;;
        "SPEC_CHANGE"|"ARCHITECTURE_CHANGE")
            echo "$event" > "./notifications/@LSE/pending/$(date +%s).json"
            echo "$event" > "./notifications/@PRD/pending/$(date +%s).json"
            ;;
    esac
}
```

#### Step 3: Integrate with Existing Task Updates (10 minutes)
```bash
# Modify your existing task state update function
update_task_state() {
    local task_id="$1"
    local new_state="$2"
    local old_state="$(get_current_state "$task_id")"  # Your existing function
    
    # Your existing state update logic here
    # ... set_task_state "$task_id" "$new_state" ...
    
    # NEW: Emit event for automatic signaling  
    if [[ "$old_state" != "$new_state" ]]; then
        emit_task_event "$task_id" "$old_state" "$new_state"
    fi
}
```

#### Step 4: Agent Notification Checking (5 minutes)
```bash
# Add to each agent's workflow
check_notifications() {
    local agent="$1"  # e.g., "@AA"
    local notification_dir="./notifications/${agent}/pending"
    
    if [[ -d "$notification_dir" ]]; then
        for notification_file in "$notification_dir"/*.json; do
            [[ -f "$notification_file" ]] || continue
            
            echo "📬 NEW WORK: $(jq -r '.task_id + " → " + .new_state' "$notification_file")"
            
            # Move to processed
            mv "$notification_file" "./notifications/${agent}/processed/"
        done
    fi
}

# Usage in agent scripts
@AA_check_work() {
    echo "Checking for new reviews..."
    check_notifications "@AA"
}
```

### Advanced Implementation: Real-Time Monitoring (Optional)

#### Background Event Watcher
```bash
# ./scripts/event_watcher.sh
#!/bin/bash

start_event_watcher() {
    local agent="$1"
    local notification_dir="./notifications/${agent}/pending"
    
    # Watch for new notification files
    inotifywait -m "$notification_dir" -e create -e moved_to --format '%f' | \
    while read -r filename; do
        if [[ "$filename" == *.json ]]; then
            echo "🔔 [@${agent}] New task ready: $filename"
            # Optional: trigger agent-specific handler
            # handle_agent_notification "$agent" "$notification_dir/$filename"
        fi
    done &
    
    echo $! > "./pids/${agent}_watcher.pid"
}

# Start watchers for all agents
for agent in "AA" "QA" "LSE" "PRD" "OXX"; do
    start_event_watcher "@$agent"
done
```

### Integration Points

#### 1. Task Creation
```bash
create_task() {
    local task_id="$1"
    # ... existing task creation ...
    
    # Signal task created
    emit_task_event "$task_id" "NONE" "CREATED"
}
```

#### 2. Development Completion  
```bash
complete_development() {
    local task_id="$1"
    # ... mark dev work done ...
    
    # This will automatically signal @AA
    update_task_state "$task_id" "DEV_COMPLETE"
}
```

#### 3. Review Completion
```bash
complete_aa_review() {
    local task_id="$1"
    local approved="$2"  # true/false
    
    if [[ "$approved" == "true" ]]; then
        # This will automatically signal @QA
        update_task_state "$task_id" "VALIDATED" 
    else
        update_task_state "$task_id" "NEEDS_REWORK"
    fi
}
```

### Immediate Benefits You'll See

#### Before (Manual Tapping)
```
Developer: "Hey @AA, task XYZ is ready for review"
@AA: "Thanks, I'll check it"
[Later] @AA: "Approved. @QA please validate"  
@QA: "Thanks, I'll test it"
```

#### After (Event-Driven)
```
Developer: [completes task] → update_task_state "XYZ" "DEV_COMPLETE"
System: [automatically creates notification in @AA/pending/]
@AA: [checks work] → sees "📬 NEW WORK: XYZ → DEV_COMPLETE"
@AA: [approves] → update_task_state "XYZ" "VALIDATED"  
System: [automatically creates notification in @QA/pending/]
@QA: [checks work] → sees "📬 NEW WORK: XYZ → VALIDATED"
```

### Monitoring and Debugging

#### Event Log Analysis
```bash
# See all recent events
tail -10 ./events/task_events.jsonl | jq .

# Find events for specific task
grep '"task_id":"TASK-123"' ./events/task_events.jsonl | jq .

# See state transition patterns
jq -r '.old_state + " → " + .new_state' ./events/task_events.jsonl | sort | uniq -c
```

#### Notification Queue Status
```bash
# Check pending notifications for all agents
for agent in "@AA" "@QA" "@LSE" "@PRD" "@OXX"; do
    pending_count=$(ls "./notifications/${agent}/pending/"*.json 2>/dev/null | wc -l)
    echo "${agent}: ${pending_count} pending notifications"
done
```

### Rollback Strategy

If event system causes issues:
1. Comment out `emit_task_event` calls
2. System reverts to manual coordination
3. Event logs preserved for debugging
4. No data loss, just loss of automation

### Future Enhancements

#### Phase 2: Smart Batching
- Batch multiple events for same task
- Reduce notification spam for rapid state changes

#### Phase 3: Priority Signaling  
- Critical/urgent tasks get immediate notification
- Normal tasks can batch/delay

#### Phase 4: Cross-Project Events
- Share events between multiple projects
- Global agent notification across codebases

### Success Metrics

Track these metrics to validate the event system:

- **Manual Taps Eliminated**: Count of "hey @agent" messages before/after
- **Response Time**: Time from DEV_COMPLETE to AA_REVIEW_START  
- **Work Queue Visibility**: Agents know immediately when work is ready
- **Missed Handoffs**: Should drop to zero with automatic signaling

### Getting Started Checklist

- [ ] Create event directories (`mkdir -p ./events ./notifications/...`)
- [ ] Add `emit_task_event()` function to task management script
- [ ] Modify `update_task_state()` to emit events
- [ ] Add `check_notifications()` to agent workflows  
- [ ] Test with one task state change
- [ ] Verify notification appears in agent's pending directory
- [ ] Roll out to all state transitions
- [ ] Monitor event log for proper functioning

This implementation will eliminate manual agent tapping immediately while providing a foundation for more sophisticated workflow automation.