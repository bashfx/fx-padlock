#!/usr/bin/env bash
set -euo pipefail

# Task Database System - File-based task/status tracking for agent coordination
# Implements solution to handoff disconnect problem identified in TASK-001 scenario

# Configuration
TASKDB_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fx-padlock/taskdb"
TASKS_FILE="$TASKDB_DIR/tasks.tsv" 
STATUS_LOG="$TASKDB_DIR/status.log"
NOTIFICATIONS_DIR="$TASKDB_DIR/notifications"

# Task States (based on RX_ITERATION_PROTOCOL_V2.md research)
declare -A TASK_STATES=(
    ["ASSIGNED"]="Task assigned to agent, work can begin"
    ["IN_PROGRESS"]="Agent actively working on task"
    ["DEV_COMPLETE"]="Implementation done, awaiting review"
    ["REVIEW_PENDING"]="Under architectural/QA review"
    ["ISSUES_FOUND"]="Blocking issues identified, needs fix"
    ["FIX_ASSIGNED"]="Fix task created and assigned (CRITICAL PATH)"
    ["FIX_IN_PROGRESS"]="Fix work actively underway"
    ["FIX_COMPLETE"]="Fix implemented, awaiting validation"
    ["VALIDATED"]="All issues resolved, meets requirements"
    ["PRODUCTION_READY"]="Fully complete, no blockers"
)

# Priority Levels
declare -A PRIORITIES=(
    ["CRITICAL"]="🚨 Critical Path - Work This First"
    ["HIGH"]="⚡ High Priority"
    ["NORMAL"]="📋 Normal Priority"
    ["LOW"]="⏳ Low Priority"
)

# Agent List
declare -a AGENTS=("@PRD" "@LSE" "@AA" "@QA" "@RRR")

# Initialize database
init_taskdb() {
    mkdir -p "$TASKDB_DIR" "$NOTIFICATIONS_DIR"
    
    if [[ ! -f "$TASKS_FILE" ]]; then
        # TSV Header: task_id, title, assigned_agent, state, priority, parent_task, created_date, updated_date, description
        echo -e "task_id\ttitle\tassigned_agent\tstate\tpriority\tparent_task\tcreated_date\tupdated_date\tdescription" > "$TASKS_FILE"
    fi
    
    if [[ ! -f "$STATUS_LOG" ]]; then
        touch "$STATUS_LOG"
    fi
    
    for agent in "${AGENTS[@]}"; do
        mkdir -p "$NOTIFICATIONS_DIR/${agent#@}"
    done
}

# Logging function
log_activity() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$STATUS_LOG"
}

# Create new task
create_task() {
    local task_id="$1"
    local title="$2"
    local assigned_agent="$3"
    local priority="${4:-NORMAL}"
    local parent_task="${5:-}"
    local description="${6:-}"
    
    local created_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if task already exists
    if grep -q "^$task_id" "$TASKS_FILE" 2>/dev/null; then
        echo "Error: Task $task_id already exists"
        return 1
    fi
    
    # Add task to database
    echo -e "$task_id\t$title\t$assigned_agent\tASSIGNED\t$priority\t$parent_task\t$created_date\t$created_date\t$description" >> "$TASKS_FILE"
    
    log_activity "CREATED: $task_id assigned to $assigned_agent with priority $priority"
    
    # Trigger notifications
    notify_agent "$assigned_agent" "NEW_TASK" "$task_id: $title" "$priority"
    
    echo "Task $task_id created and assigned to $assigned_agent"
}

# Update task state
update_task_state() {
    local task_id="$1"
    local new_state="$2"
    local agent="${3:-system}"
    
    # Validate state
    if [[ ! ${TASK_STATES[$new_state]+_} ]]; then
        echo "Error: Invalid state '$new_state'"
        echo "Valid states: ${!TASK_STATES[*]}"
        return 1
    fi
    
    # Get current task info
    local task_line=$(grep "^$task_id" "$TASKS_FILE" || true)
    if [[ -z "$task_line" ]]; then
        echo "Error: Task $task_id not found"
        return 1
    fi
    
    # Parse current task data
    IFS=$'\t' read -r t_id title assigned_agent old_state priority parent_task created_date _ description <<< "$task_line"
    
    # Update the task
    local updated_date=$(date '+%Y-%m-%d %H:%M:%S')
    local temp_file=$(mktemp)
    
    # Update the specific line
    awk -F'\t' -v OFS='\t' -v task_id="$task_id" -v new_state="$new_state" -v updated_date="$updated_date" '
        NR==1 { print; next }
        $1 == task_id { $4 = new_state; $8 = updated_date; print; next }
        { print }
    ' "$TASKS_FILE" > "$temp_file"
    
    mv "$temp_file" "$TASKS_FILE"
    
    log_activity "STATE_CHANGE: $task_id $old_state → $new_state by $agent"
    
    # Handle state transition triggers
    handle_state_triggers "$task_id" "$title" "$assigned_agent" "$old_state" "$new_state" "$priority" "$parent_task"
    
    echo "Task $task_id state updated: $old_state → $new_state"
}

# Handle automated state triggers
handle_state_triggers() {
    local task_id="$1"
    local title="$2"
    local assigned_agent="$3"
    local old_state="$4"
    local new_state="$5" 
    local priority="$6"
    local parent_task="$7"
    
    case "$new_state" in
        "ISSUES_FOUND")
            # Auto-create fix task
            local fix_id="${task_id}-FIX"
            local fix_title="Fix issues found in: $title"
            create_fix_task "$fix_id" "$fix_title" "$assigned_agent" "$task_id"
            notify_agent "$assigned_agent" "CRITICAL_FIX" "CRITICAL PATH ACTIVE: $fix_id" "CRITICAL"
            ;;
        "FIX_ASSIGNED"|"FIX_IN_PROGRESS")
            notify_agent "$assigned_agent" "CRITICAL_PATH" "Focus on $task_id - Critical path blocking" "CRITICAL"
            ;;
        "DEV_COMPLETE")
            notify_agent "@AA" "REVIEW_REQUEST" "Ready for review: $task_id" "HIGH"
            notify_agent "@QA" "REVIEW_REQUEST" "Ready for review: $task_id" "HIGH"
            ;;
        "VALIDATED")
            notify_agent "@PRD" "PRODUCTION_READY" "Task ready for production: $task_id" "HIGH"
            ;;
    esac
}

# Create fix task
create_fix_task() {
    local fix_id="$1"
    local fix_title="$2"
    local assigned_agent="$3"
    local parent_task="$4"
    
    local created_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "$fix_id\t$fix_title\t$assigned_agent\tFIX_ASSIGNED\tCRITICAL\t$parent_task\t$created_date\t$created_date\tAuto-generated fix task" >> "$TASKS_FILE"
    
    log_activity "AUTO_CREATED_FIX: $fix_id for parent $parent_task"
}

# Notify agent
notify_agent() {
    local agent="$1"
    local type="$2"
    local message="$3"
    local priority="${4:-NORMAL}"
    
    local agent_clean="${agent#@}"
    local notification_file="$NOTIFICATIONS_DIR/$agent_clean/$(date +%s).notification"
    
    case "$priority" in
        "CRITICAL")
            echo "🚨 CRITICAL: $message" > "$notification_file"
            ;;
        "HIGH")
            echo "⚡ HIGH: $message" > "$notification_file"
            ;;
        *)
            echo "📋 $message" > "$notification_file"
            ;;
    esac
    
    log_activity "NOTIFICATION: $agent received $type - $message"
}

# Show task details
show_task() {
    local task_id="$1"
    
    local task_line=$(grep "^$task_id" "$TASKS_FILE" || true)
    if [[ -z "$task_line" ]]; then
        echo "Task $task_id not found"
        return 1
    fi
    
    IFS=$'\t' read -r t_id title assigned_agent state priority parent_task created_date updated_date description <<< "$task_line"
    
    echo "┌─ Task Details ─────────────────────────────────────┐"
    echo "│ ID: $t_id"
    echo "│ Title: $title"
    echo "│ Assigned: $assigned_agent"
    echo "│ State: $state (${TASK_STATES[$state]})"
    echo "│ Priority: $priority (${PRIORITIES[$priority]})"
    [[ -n "$parent_task" ]] && echo "│ Parent Task: $parent_task"
    echo "│ Created: $created_date"
    echo "│ Updated: $updated_date"
    [[ -n "$description" ]] && echo "│ Description: $description"
    echo "└────────────────────────────────────────────────────┘"
}

# List all tasks
list_tasks() {
    local filter_agent="${1:-}"
    local filter_state="${2:-}"
    
    echo "Task Database Status:"
    echo "════════════════════════════════════════════════════"
    
    local line_num=0
    while IFS=$'\t' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        ((line_num++))
        [[ $line_num -eq 1 ]] && continue  # Skip header
        
        # Apply filters
        if [[ -n "$filter_agent" && "$assigned_agent" != "$filter_agent" ]]; then
            continue
        fi
        
        if [[ -n "$filter_state" && "$state" != "$filter_state" ]]; then
            continue
        fi
        
        # Format priority icon
        local priority_icon=""
        case "$priority" in
            "CRITICAL") priority_icon="🚨" ;;
            "HIGH") priority_icon="⚡" ;;
            "NORMAL") priority_icon="📋" ;;
            "LOW") priority_icon="⏳" ;;
        esac
        
        # Format state
        local state_display="$state"
        if [[ "$state" =~ FIX_ ]]; then
            state_display="🔧 $state"
        fi
        
        printf "%-12s %s %-30s %s %-12s %-18s %s\n" \
            "$task_id" \
            "$priority_icon" \
            "$title" \
            "$assigned_agent" \
            "$state_display" \
            "$updated_date" \
            "${parent_task:+[parent: $parent_task]}"
    done < "$TASKS_FILE"
}

# Generate agent dashboard
agent_dashboard() {
    local agent="$1"
    
    echo "════════════════════════════════════════════════════"
    echo "  $agent WORK DASHBOARD"
    echo "════════════════════════════════════════════════════"
    echo ""
    
    # Show critical path tasks first
    local has_critical=false
    while IFS=$'\t' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        [[ "$assigned_agent" != "$agent" ]] && continue
        [[ "$state" == "PRODUCTION_READY" ]] && continue
        
        if [[ "$priority" == "CRITICAL" || "$state" =~ FIX_ ]]; then
            if [[ "$has_critical" == false ]]; then
                echo "🚨 CRITICAL PATH (work this first):"
                echo "──────────────────────────────────────────────────"
                has_critical=true
            fi
            printf "  %-12s %s %s\n" "$task_id" "$state" "$title"
        fi
    done < <(tail -n +2 "$TASKS_FILE")
    
    if [[ "$has_critical" == true ]]; then
        echo ""
        echo "📋 OTHER WORK (paused until critical path clear):"
        echo "──────────────────────────────────────────────────"
    else
        echo "📋 ACTIVE WORK:"
        echo "──────────────────────────────────────────────────"
    fi
    
    # Show other tasks
    while IFS=$'\t' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        [[ "$assigned_agent" != "$agent" ]] && continue
        [[ "$state" == "PRODUCTION_READY" ]] && continue
        [[ "$priority" == "CRITICAL" || "$state" =~ FIX_ ]] && continue
        
        local priority_icon=""
        case "$priority" in
            "HIGH") priority_icon="⚡" ;;
            "NORMAL") priority_icon="📋" ;;
            "LOW") priority_icon="⏳" ;;
        esac
        
        printf "  %-12s %s %-15s %s\n" "$task_id" "$priority_icon" "$state" "$title"
    done < <(tail -n +2 "$TASKS_FILE")
    
    echo ""
    
    # Show recent notifications
    local agent_clean="${agent#@}"
    local notification_count=$(find "$NOTIFICATIONS_DIR/$agent_clean" -name "*.notification" 2>/dev/null | wc -l)
    if [[ $notification_count -gt 0 ]]; then
        echo "📢 RECENT NOTIFICATIONS:"
        echo "──────────────────────────────────────────────────"
        find "$NOTIFICATIONS_DIR/$agent_clean" -name "*.notification" -exec cat {} \; 2>/dev/null | tail -5
        echo ""
    fi
}

# Clear notifications for agent
clear_notifications() {
    local agent="$1"
    local agent_clean="${agent#@}"
    rm -f "$NOTIFICATIONS_DIR/$agent_clean"/*.notification 2>/dev/null || true
    echo "Notifications cleared for $agent"
}

# Show usage
usage() {
    cat << EOF
Task Database System - Agent Coordination Tool

USAGE:
    taskdb.sh COMMAND [ARGS...]

COMMANDS:
    init                           Initialize task database
    create TASK_ID TITLE AGENT [PRIORITY] [PARENT] [DESC]
                                  Create new task
    update TASK_ID STATE [AGENT]  Update task state
    show TASK_ID                  Show task details
    list [AGENT] [STATE]          List all tasks (with optional filters)
    dashboard AGENT               Show agent's work dashboard
    clear-notifications AGENT     Clear agent's notifications
    states                        Show available task states
    agents                        Show available agents
    
EXAMPLES:
    taskdb.sh create TASK-001 "Implement TTY functions" @LSE HIGH
    taskdb.sh update TASK-001 IN_PROGRESS @LSE
    taskdb.sh dashboard @LSE
    taskdb.sh list @LSE
    taskdb.sh list "" IN_PROGRESS

AGENTS: ${AGENTS[*]}

STATES: ${!TASK_STATES[*]}

PRIORITIES: ${!PRIORITIES[*]}
EOF
}

# Main command dispatch
main() {
    local command="${1:-}"
    shift || true
    
    case "$command" in
        "init")
            init_taskdb
            ;;
        "create")
            [[ $# -lt 3 ]] && { echo "Usage: create TASK_ID TITLE AGENT [PRIORITY] [PARENT] [DESC]"; exit 1; }
            create_task "$@"
            ;;
        "update")
            [[ $# -lt 2 ]] && { echo "Usage: update TASK_ID STATE [AGENT]"; exit 1; }
            update_task_state "$@"
            ;;
        "show")
            [[ $# -lt 1 ]] && { echo "Usage: show TASK_ID"; exit 1; }
            show_task "$1"
            ;;
        "list")
            list_tasks "$@"
            ;;
        "dashboard")
            [[ $# -lt 1 ]] && { echo "Usage: dashboard AGENT"; exit 1; }
            agent_dashboard "$1"
            ;;
        "clear-notifications")
            [[ $# -lt 1 ]] && { echo "Usage: clear-notifications AGENT"; exit 1; }
            clear_notifications "$1"
            ;;
        "states")
            echo "Available task states:"
            for state in "${!TASK_STATES[@]}"; do
                echo "  $state: ${TASK_STATES[$state]}"
            done
            ;;
        "agents")
            echo "Available agents: ${AGENTS[*]}"
            ;;
        "help"|"-h"|"--help"|"")
            usage
            ;;
        *)
            echo "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Auto-initialize if needed
if [[ ! -d "$TASKDB_DIR" ]]; then
    init_taskdb
fi

# Run main function
main "$@"