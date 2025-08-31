#!/usr/bin/env bash
set -euo pipefail

# Task Database System - File-based task/status tracking for agent coordination
# Implements solution to handoff disconnect problem identified in TASK-001 scenario

# ════════════════════════════════════════════════════════════════════════════════════════════════
# 🎨 COLOR CONFIGURATION (Customize as needed)
# ════════════════════════════════════════════════════════════════════════════════════════════════

# Heat Level Colors
declare -A HEAT_COLORS=(
    ["BLAZ"]="red"
    ["HOT"]="red" 
    ["WARM"]="yellow"
    ["COOL"]="cyan"
    ["COLD"]="purple"
    ["DEAD"]="gray"
)

# Task Status Colors
declare -A STATUS_COLORS=(
    ["ISSUES_FOUND"]="red"
    ["FIX_ASSIGNED"]="red"
    ["FIX_IN_PROGRESS"]="red"
    ["ASSIGNED"]="yellow"
    ["RESEARCH_REQUIRED"]="purple"
    ["PRODUCT_REVIEW"]="cyan"
    ["IN_PROGRESS"]="yellow"
    ["DEV_COMPLETE"]="yellow"
    ["PRODUCTION_READY"]="green"
    ["VALIDATED"]="green"
    ["FIX_COMPLETE"]="green"
    ["REVIEW_PENDING"]="cyan"
    ["ARCHIVED"]="gray"
)

# Priority Colors
declare -A PRIORITY_COLORS=(
    ["CRITICAL"]="red"
    ["URGENT"]="red"
    ["HIGH"]="yellow"
    ["NORMAL"]="cyan"
    ["BACKLOG"]="gray"
)

# ANSI Color Codes
declare -A ANSI_COLORS=(
    ["red"]='\033[0;31m'
    ["green"]='\033[0;32m'
    ["yellow"]='\033[0;33m'
    ["blue"]='\033[0;34m'
    ["purple"]='\033[0;35m'
    ["cyan"]='\033[0;36m'
    ["gray"]='\033[0;90m'
    ["bold"]='\033[1m'
    ["reset"]='\033[0m'
)

# Global color flag (set by --color argument)
USE_COLORS=false

# ════════════════════════════════════════════════════════════════════════════════════════════════
# 📦 DISPLAY SYSTEM CONFIGURATION
# ════════════════════════════════════════════════════════════════════════════════════════════════

# Check for whiptail availability and set display mode
WHIPTAIL_AVAILABLE=false
DISPLAY_MODE="fallback"  # Options: whiptail, fallback

# Check whiptail dependency on startup
check_whiptail_dependency() {
    if command -v whiptail >/dev/null 2>&1; then
        WHIPTAIL_AVAILABLE=true
        DISPLAY_MODE="whiptail"
        return 0
    else
        WHIPTAIL_AVAILABLE=false
        DISPLAY_MODE="fallback"
        return 1
    fi
}

# Initialize display system
initialize_display_system() {
    check_whiptail_dependency
    
    # Default to AI-friendly mode (the perfectly tuned bicycle 🚴‍♂️)
    DISPLAY_MODE="fallback"
    
    # Ferrari available in garage if needed:
    # Uncomment below to enable whiptail in proper interactive terminals
    # if [ "$WHIPTAIL_AVAILABLE" = true ]; then
    #     if whiptail --msgbox "Display system test" 6 30 2>/dev/null; then
    #         DISPLAY_MODE="whiptail"  # 🏎️ Ferrari mode!
    #     fi
    # fi
}

# Whiptail display configuration
WHIPTAIL_DEFAULT_WIDTH=80
WHIPTAIL_DEFAULT_HEIGHT=20
WHIPTAIL_MAX_WIDTH=120
WHIPTAIL_MIN_WIDTH=60

# ════════════════════════════════════════════════════════════════════════════════════════════════
# 🏷️  4-LETTER CODE MAPPINGS & ICONOGRAPHY
# ════════════════════════════════════════════════════════════════════════════════════════════════

# Task State 4-Letter Codes
declare -A TASK_STATE_CODES=(
    ["ASSIGNED"]="ASSN"
    ["RESEARCH_REQUIRED"]="RXRQ"
    ["PRODUCT_REVIEW"]="PRRV"
    ["IN_PROGRESS"]="INPR"
    ["DEV_COMPLETE"]="DEVD"
    ["REVIEW_PENDING"]="REVW"
    ["ISSUES_FOUND"]="REGR"
    ["FIX_ASSIGNED"]="FASS"
    ["FIX_IN_PROGRESS"]="FIPR"
    ["FIX_COMPLETE"]="FIXD"
    ["VALIDATED"]="PASS"
    ["PRODUCTION_READY"]="PROD"
    ["ARCHIVED"]="DONE"
)

# Task State Icons
declare -A TASK_STATE_ICONS=(
    ["ASSIGNED"]="📌"
    ["RESEARCH_REQUIRED"]="🧪"
    ["PRODUCT_REVIEW"]="🔍"
    ["IN_PROGRESS"]="⚙️"
    ["DEV_COMPLETE"]="✅"
    ["REVIEW_PENDING"]="👀"
    ["ISSUES_FOUND"]="⚠️"
    ["FIX_ASSIGNED"]="🔧"
    ["FIX_IN_PROGRESS"]="🛠️"
    ["FIX_COMPLETE"]="🔨"
    ["VALIDATED"]="✨"
    ["PRODUCTION_READY"]="🚀"
    ["ARCHIVED"]="📦"
)

# Priority 4-Letter Codes
declare -A PRIORITY_CODES=(
    ["CRITICAL"]="CRIT"
    ["URGENT"]="URGT"
    ["HIGH"]="HIGH"
    ["NORMAL"]="NORM"
    ["BACKLOG"]="BACK"
)

# Priority Icons
declare -A PRIORITY_ICONS=(
    ["CRITICAL"]="🚨"
    ["URGENT"]="🔥"
    ["HIGH"]="🏃"
    ["NORMAL"]="👟"
    ["BACKLOG"]="✏️"
)

# Heat Level 4-Letter Codes
declare -A HEAT_CODES=(
    ["BLAZ"]="BLAZ"
    ["HOT"]="SPCY"
    ["WARM"]="WARM"
    ["COOL"]="COOL"
    ["COLD"]="COLD"
    ["DEAD"]="DEAD"
)

# Heat Level Icons
declare -A HEAT_ICONS=(
    ["BLAZ"]="🔥"
    ["SPCY"]="🌶️"
    ["WARM"]="☕"
    ["COOL"]="🧊"
    ["COLD"]="❄️"
    ["DEAD"]="💀"
)

# ════════════════════════════════════════════════════════════════════════════════════════════════

# Colorize text based on type and content
colorize() {
    local text="$1"
    local color_key="$2"
    
    if [[ "$USE_COLORS" != "true" ]]; then
        echo "$text"
        return
    fi
    
    local color_code="${ANSI_COLORS[$color_key]:-}"
    local reset_code="${ANSI_COLORS[reset]}"
    
    if [[ -n "$color_code" ]]; then
        echo -e "${color_code}${text}${reset_code}"
    else
        echo "$text"
    fi
}

# Get project identifier for data isolation
# Path-to-ID mapping for collision resolution
declare -A PATH_TO_ID_MAP

get_project_id() {
    local current_dir="$(pwd)"
    local path_checksum=$(echo "$current_dir" | md5sum | cut -c1-8)
    
    # Check if we already have a mapping for this path
    local mapping_file="$TASKDB_BASE_DIR/path_mappings.conf"
    if [[ -f "$mapping_file" ]]; then
        local existing_id=$(grep "^$current_dir|" "$mapping_file" 2>/dev/null | cut -d'|' -f2)
        if [[ -n "$existing_id" ]]; then
            echo "$existing_id"
            return
        fi
    fi
    
    # Generate clean project name
    local project_name=""
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local git_url=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$git_url" ]]; then
            # Extract repo name from URL (remove .git, path, etc.)
            local repo_name=$(basename "$git_url" .git)
            project_name="git-$repo_name"
        else
            # Fallback to git root directory name
            local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
            if [[ -n "$git_root" ]]; then
                local dirname=$(basename "$git_root")
                project_name="git-$dirname"
            fi
        fi
    else
        # For non-git directories
        local dirname=$(basename "$current_dir")
        project_name="dir-$dirname"
    fi
    
    # Check for collision with existing project names
    mkdir -p "$TASKDB_BASE_DIR"
    local final_id="$project_name"
    if [[ -f "$mapping_file" ]] && grep -q "|$project_name$" "$mapping_file" 2>/dev/null; then
        # Collision detected - use checksum suffix
        final_id="$project_name-$path_checksum"
    fi
    
    # Store the mapping
    echo "$current_dir|$final_id" >> "$mapping_file"
    echo "$final_id"
}

# Project-aware configuration
TASKDB_BASE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/taskdb"
PROJECT_ID=$(get_project_id)
TASKDB_DIR="$TASKDB_BASE_DIR/projects/$PROJECT_ID"
GLOBAL_HR_DIR="$TASKDB_BASE_DIR/global"
COUNTERS_DIR="$TASKDB_DIR/counters"
COUNTER_MANIFEST="$COUNTERS_DIR/manifest.conf"
TASKS_FILE="$TASKDB_DIR/tasks.tsv" 
STATUS_LOG="$TASKDB_DIR/status.log"
NOTIFICATIONS_DIR="$TASKDB_DIR/notifications"

# Preview next ID without consuming it
preview_next_id() {
    local counter_type="$1"
    local counter_subtype="${2:-}"
    
    # Get the format and counter info without incrementing
    local counter_path=""
    local id_format=""
    local manifest_key=""
    
    case "$counter_type" in
        "tasks")
            counter_path="$COUNTERS_DIR/tasks"
            id_format="TASK-%03d"
            manifest_key="tasks"
            ;;
        "notifications")
            [[ -z "$counter_subtype" ]] && { echo "Error: notifications require agent subtype"; return 1; }
            local agent_clean="${counter_subtype#@}"
            counter_path="$COUNTERS_DIR/notifications/$agent_clean"
            id_format="%03d"
            manifest_key="notifications-$agent_clean"
            ;;
        *)
            echo "Error: Unknown counter type '$counter_type'"
            return 1
            ;;
    esac
    
    mkdir -p "$COUNTERS_DIR"
    mkdir -p "$(dirname "$counter_path")"
    
    # Check current counter value or determine what it would be
    local current_value=0
    if [[ -f "$counter_path/.counter" ]]; then
        current_value=$(awk -F'::' '{print $2}' "$counter_path/.counter")
        # Return what next increment would be
        local next_value=$((current_value + 1))
        printf "$id_format" "$next_value"
    else
        # Same initialization logic as get_next_id
        if [[ "$counter_type" == "tasks" && -f "$TASKS_FILE" ]]; then
            local highest_task_num=0
            while IFS='|' read -r task_id rest; do
                if [[ "$task_id" =~ ^TASK-([0-9]+)$ ]]; then
                    local num="${BASH_REMATCH[1]}"
                    ((num > highest_task_num)) && highest_task_num=$num
                fi
            done < <(tail -n +2 "$TASKS_FILE" 2>/dev/null || true)
            current_value=$highest_task_num
        else
            if [[ -f "$COUNTER_MANIFEST" ]]; then
                current_value=$(grep "^$manifest_key|" "$COUNTER_MANIFEST" 2>/dev/null | cut -d'|' -f2 || echo "0")
            fi
        fi
        
        # Return what first increment would be (counter would initialize at current_value, then increment to current_value + 1)
        local next_value=$((current_value + 1))
        printf "$id_format" "$next_value"
    fi
}

# Counter Orchestrator - Centralized ID management with disaster recovery
get_next_id() {
    local counter_type="$1"
    local counter_subtype="${2:-}"  # For notifications: agent name
    
    mkdir -p "$COUNTERS_DIR"
    
    # Determine counter path and ID format
    local counter_path=""
    local id_format=""
    local manifest_key=""
    
    case "$counter_type" in
        "tasks")
            counter_path="$COUNTERS_DIR/tasks"
            id_format="TASK-%03d"
            manifest_key="tasks"
            ;;
        "notifications")
            [[ -z "$counter_subtype" ]] && { echo "Error: notifications require agent subtype"; return 1; }
            local agent_clean="${counter_subtype#@}"
            counter_path="$COUNTERS_DIR/notifications/$agent_clean"
            id_format="%03d"
            manifest_key="notifications-$agent_clean"
            ;;
        *)
            echo "Error: Unknown counter type '$counter_type'"
            return 1
            ;;
    esac
    
    mkdir -p "$(dirname "$counter_path")"
    
    # Check if counter exists, if not try to recover from manifest or existing data
    if [[ ! -f "$counter_path/.counter" ]]; then
        local last_known_id=0
        
        # For tasks, scan existing tasks to find highest ID
        if [[ "$counter_type" == "tasks" && -f "$TASKS_FILE" ]]; then
            # Extract highest task number from existing tasks
            local highest_task_num=0
            while IFS='|' read -r task_id rest; do
                if [[ "$task_id" =~ ^TASK-([0-9]+)$ ]]; then
                    local num="${BASH_REMATCH[1]}"
                    ((num > highest_task_num)) && highest_task_num=$num
                fi
            done < <(tail -n +2 "$TASKS_FILE" 2>/dev/null || true)
            last_known_id=$highest_task_num
        else
            # Try manifest recovery
            if [[ -f "$COUNTER_MANIFEST" ]]; then
                last_known_id=$(grep "^$manifest_key|" "$COUNTER_MANIFEST" 2>/dev/null | cut -d'|' -f2 || echo "0")
            fi
        fi
        
        # Initialize counter at last_known_id
        local start_value=$last_known_id
        mkdir -p "$counter_path"
        (cd "$counter_path" && countx init "$start_value" --fmt 000 2>/dev/null)
    fi
    
    # Get next ID by incrementing
    local next_id
    next_id=$(cd "$counter_path" && countx 1)
    
    # Update manifest
    local timestamp=$(date +%s)
    local temp_manifest=$(mktemp)
    
    # Remove existing entry for this counter type
    if [[ -f "$COUNTER_MANIFEST" ]]; then
        grep -v "^$manifest_key|" "$COUNTER_MANIFEST" > "$temp_manifest" || true
    fi
    
    # Add updated entry
    echo "$manifest_key|$next_id|$counter_path/.counter|$timestamp" >> "$temp_manifest"
    mv "$temp_manifest" "$COUNTER_MANIFEST"
    
    # Return formatted ID
    printf "$id_format" "$next_id"
}

# Task States (based on RX_ITERATION_PROTOCOL_V2.md research)
declare -A TASK_STATES=(
    ["ASSIGNED"]="Task assigned to agent, work can begin"
    ["RESEARCH_REQUIRED"]="Needs R&D exploration before development"
    ["PRODUCT_REVIEW"]="Scope too big or needs more product input"
    ["IN_PROGRESS"]="Agent actively working on task"
    ["DEV_COMPLETE"]="Implementation done, awaiting review"
    ["REVIEW_PENDING"]="Under architectural/QA review"
    ["ISSUES_FOUND"]="Blocking issues identified, needs fix"
    ["FIX_ASSIGNED"]="Fix task created and assigned (CRITICAL PATH)"
    ["FIX_IN_PROGRESS"]="Fix work actively underway"
    ["FIX_COMPLETE"]="Fix implemented, awaiting validation"
    ["VALIDATED"]="All issues resolved, meets requirements"
    ["PRODUCTION_READY"]="Fully complete, no blockers"
    ["ARCHIVED"]="Completed and archived, no further work needed"
)

# Priority Levels
declare -A PRIORITIES=(
    ["CRITICAL"]="🚨 Critical - Right now first!"
    ["URGENT"]="🔥 Urgent - This sprint/session"
    ["HIGH"]="🏃 High - Current work"
    ["NORMAL"]="👟 Normal - Sprint scoped"
    ["BACKLOG"]="✏️ Backlog - Dev can review/elevate"
)

# Agent manifest file (global across all projects)
AGENTS_FILE="$GLOBAL_HR_DIR/agents.conf"

# Load agents from manifest
load_agents() {
    if [[ ! -f "$AGENTS_FILE" ]]; then
        # Create default agent manifest
        cat > "$AGENTS_FILE" << 'EOF'
# Agent Manifest - One agent per line
# Format: @AGENT_NAME|ROLE|DESCRIPTION
@OXX|Orchestrator|Team coordination and task orchestration
@PRD|Product|Product requirements and delivery management
@LSE|Engineer|Software engineering and development
@AA|Architect|Architecture analysis and design review
@QA|Quality|Quality assurance and testing
@RRR|Research|Research and investigation tasks
@USER|User|User tasks and personal assignments
EOF
    fi
    
    # Parse agents from manifest
    AGENTS=()
    while IFS='|' read -r agent role description; do
        [[ "$agent" =~ ^#.*|^$ ]] && continue  # Skip comments and empty lines
        AGENTS+=("$agent")
    done < "$AGENTS_FILE"
}

# Get agent role and description
get_agent_info() {
    local target_agent="$1"
    while IFS='|' read -r agent role description; do
        [[ "$agent" =~ ^#.*|^$ ]] && continue
        if [[ "$agent" == "$target_agent" ]]; then
            echo "$role|$description"
            return 0
        fi
    done < "$AGENTS_FILE"
    return 1
}

# Initialize database
init_taskdb() {
    mkdir -p "$TASKDB_DIR" "$NOTIFICATIONS_DIR" "$GLOBAL_HR_DIR"
    
    # Load agents from global manifest
    load_agents
    
    # Create project registry entry
    local registry_file="$GLOBAL_HR_DIR/projects.registry"
    local current_path="$(pwd)"
    local project_name=$(basename "$current_path")
    
    # Add project to registry if not already there
    if ! grep -q "^$PROJECT_ID|" "$registry_file" 2>/dev/null; then
        echo "$PROJECT_ID|$project_name|$current_path|$(date '+%Y-%m-%d %H:%M:%S')" >> "$registry_file"
    fi
    
    if [[ ! -f "$TASKS_FILE" ]]; then
        # Pipe-delimited Header: task_id, title, assigned_agent, state, priority, parent_task, created_date, updated_date, description
        echo "task_id|title|assigned_agent|state|priority|parent_task|created_date|updated_date|description" > "$TASKS_FILE"
    fi
    
    if [[ ! -f "$STATUS_LOG" ]]; then
        touch "$STATUS_LOG"
    fi
    
    # Create notification directories for all agents
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
    local title="$1"
    local assigned_agent="$2"
    local priority="${3:-NORMAL}"
    local parent_task="${4:-}"
    local description="${5:-}"
    
    # Generate unique task ID using counter orchestrator
    local task_id
    task_id=$(get_next_id "tasks")
    
    local created_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if task already exists (shouldn't happen with auto-generated IDs)
    if grep -q "^$task_id|" "$TASKS_FILE" 2>/dev/null; then
        echo "Error: Task $task_id already exists"
        return 1
    fi
    
    # Add task to database
    echo "$task_id|$title|$assigned_agent|ASSIGNED|$priority|$parent_task|$created_date|$created_date|$description" >> "$TASKS_FILE"
    
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
    local task_line=$(grep "^$task_id|" "$TASKS_FILE" || true)
    if [[ -z "$task_line" ]]; then
        echo "Error: Task $task_id not found"
        return 1
    fi
    
    # Parse current task data with whitespace trimming
    t_id=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
    title=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    assigned_agent=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
    old_state=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')
    priority=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
    parent_task=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')
    created_date=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $7); print $7}')
    description=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $9); print $9}')
    
    # Update the task
    local updated_date=$(date '+%Y-%m-%d %H:%M:%S')
    local temp_file=$(mktemp)
    
    # Update the specific line
    awk -F'|' -v OFS='|' -v task_id="$task_id" -v new_state="$new_state" -v updated_date="$updated_date" '
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
    
    echo "$fix_id|$fix_title|$assigned_agent|FIX_ASSIGNED|CRITICAL|$parent_task|$created_date|$created_date|Auto-generated fix task" >> "$TASKS_FILE"
    
    log_activity "AUTO_CREATED_FIX: $fix_id for parent $parent_task"
}

# Calculate notification heat based on age
get_notification_heat() {
    local timestamp="$1"
    local current_time=$(date +%s)
    local age_seconds=$((current_time - timestamp))
    local age_hours=$((age_seconds / 3600))
    local age_days=$((age_seconds / 86400))
    
    # Heat levels with colors, icons, and status codes
    if [[ $age_days -gt 0 ]]; then
        # Super old - grey with skull
        echo "DEAD|💀|🔘"
    elif [[ $age_hours -gt 12 ]]; then
        # Very old - blue (cool)
        echo "COLD|❄️|🔵"
    elif [[ $age_hours -gt 6 ]]; then
        # Old - light blue
        echo "COOL|🧊|🔷"
    elif [[ $age_hours -gt 3 ]]; then
        # Medium - yellow/orange
        echo "WARM|⚠️|🟡"
    elif [[ $age_hours -gt 1 ]]; then
        # Fresh - orange/red
        echo "HOT|🔥|🟠"
    else
        # Very fresh - red hot
        echo "BLAZ|🚨|🔴"
    fi
}

# Format notification with heat indicator
format_notification_with_heat() {
    local notification_file="$1"
    local file_ext="${notification_file##*.}"
    local filename=""
    
    # Handle both .notification and .broadcast files
    if [[ "$file_ext" == "broadcast" ]]; then
        filename=$(basename "$notification_file" .broadcast)
    else
        filename=$(basename "$notification_file" .notification)
    fi
    
    # Extract timestamp from ID.TIMESTAMP format
    local timestamp="${filename##*.}"
    local notification_id="${filename%%.*}"
    local content=$(cat "$notification_file" 2>/dev/null || echo "")
    
    local heat_info=$(get_notification_heat "$timestamp")
    IFS='|' read -r heat_code heat_icon heat_color <<< "$heat_info"
    
    local color_key="${HEAT_COLORS[$heat_code]:-gray}"
    local colored_heat=$(colorize "[$heat_code]" "$color_key")
    local colored_icon=$(colorize "$heat_icon" "$color_key")
    
    echo "$heat_color $colored_icon $colored_heat #$notification_id $content"
}

# Notify agent
notify_agent() {
    local agent="$1"
    local type="$2"
    local message="$3"
    local priority="${4:-NORMAL}"
    
    local agent_clean="${agent#@}"
    mkdir -p "$NOTIFICATIONS_DIR/$agent_clean"
    
    # Get unique notification ID using counter orchestrator
    local notification_id
    notification_id=$(get_next_id "notifications" "$agent")
    local timestamp=$(date +%s)
    local notification_file="$NOTIFICATIONS_DIR/$agent_clean/${notification_id}.${timestamp}.notification"
    
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

# ════════════════════════════════════════════════════════════════════════════════════════════════
# 🔧 ADMIN FUNCTIONS  
# ════════════════════════════════════════════════════════════════════════════════════════════════

# Admin function to revoke (clear) all broadcast messages
admin_revoke_broadcasts() {
    local confirmation="${1:-}"
    
    if [[ "$confirmation" != "--confirm" ]]; then
        echo "⚠️  This will permanently delete ALL broadcast messages for all agents."
        echo "Usage: admin broadcast revoke --confirm"
        return 1
    fi
    
    # Clear broadcast notifications (those containing BROADCAST in filename or content)
    local broadcasts_cleared=0
    
    if [[ -d "$NOTIFICATIONS_DIR" ]]; then
        # Find all broadcast notification files across all agents
        find "$NOTIFICATIONS_DIR" -name "*.notification" -type f | while read -r notif_file; do
            if grep -q "📢 BROADCAST:" "$notif_file" 2>/dev/null; then
                rm -f "$notif_file"
                ((broadcasts_cleared++))
            fi
        done
        
        # Also clear notifications in ALL directory if it exists
        if [[ -d "$NOTIFICATIONS_DIR/ALL" ]]; then
            local all_cleared=$(find "$NOTIFICATIONS_DIR/ALL" -name "*.notification" -type f | wc -l)
            rm -rf "$NOTIFICATIONS_DIR/ALL"
            broadcasts_cleared=$((broadcasts_cleared + all_cleared))
        fi
    fi
    
    echo "✅ Cleared broadcast messages"
    log_activity "ADMIN: Cleared broadcast messages"
}

# Admin function to revoke stale/dead notifications
admin_revoke_stale_notifications() {
    local confirmation="${1:-}"
    
    if [[ "$confirmation" != "--confirm" ]]; then
        echo "⚠️  This will permanently delete COLD and DEAD notifications."
        echo "Usage: admin notif revoke --confirm"
        return 1
    fi
    
    local stale_cleared=0
    
    if [[ -d "$NOTIFICATIONS_DIR" ]]; then
        # Find all notification files across all agents
        find "$NOTIFICATIONS_DIR" -name "*.notification" -type f | while read -r notif_file; do
            # Extract timestamp from filename (format: ID.TIMESTAMP.notification)
            local filename=$(basename "$notif_file")
            local timestamp=$(echo "$filename" | cut -d. -f2)
            
            # Calculate notification heat
            local heat_level=$(get_notification_heat "$timestamp")
            
            # Remove COLD and DEAD notifications
            if [[ "$heat_level" == "COLD" || "$heat_level" == "DEAD" ]]; then
                rm -f "$notif_file"
                ((stale_cleared++))
            fi
        done
    fi
    
    echo "✅ Cleared stale (COLD/DEAD) notifications"
    log_activity "ADMIN: Cleared stale notifications"
}

# Admin function to show system statistics
admin_show_stats() {
    echo "📊 TaskDB System Statistics:"
    echo ""
    
    # Task statistics
    local total_tasks=0
    local tasks_by_state=()
    declare -A state_counts
    
    if [[ -f "$TASKS_FILE" ]]; then
        while IFS='|' read -r task_id title agent state priority parent created updated desc || [[ -n "$task_id" ]]; do
            ((total_tasks++))
            ((state_counts[$state]++))
        done < "$TASKS_FILE"
    fi
    
    echo "🗃️  Tasks: $total_tasks total"
    for state in "${!state_counts[@]}"; do
        local state_code="${TASK_STATE_CODES[$state]:-UNKN}"
        local state_icon="${TASK_STATE_ICONS[$state]:-📋}"
        printf "   • %s %s: %d\n" "$state_icon" "$state_code" "${state_counts[$state]}"
    done
    echo ""
    
    # Notification statistics
    local total_notifications=0
    local broadcasts=0
    declare -A heat_counts
    
    if [[ -d "$NOTIFICATIONS_DIR" ]]; then
        # Count all notification files across all agents
        while read -r notif_file; do
            [[ -f "$notif_file" ]] || continue
            ((total_notifications++))
            
            # Check if it's a broadcast
            if grep -q "📢 BROADCAST:" "$notif_file" 2>/dev/null; then
                ((broadcasts++))
            fi
            
            # Extract timestamp and calculate heat
            local filename=$(basename "$notif_file")
            local timestamp=$(echo "$filename" | cut -d. -f2)
            local heat_level=$(get_notification_heat "$timestamp")
            ((heat_counts[$heat_level]++))
        done < <(find "$NOTIFICATIONS_DIR" -name "*.notification" -type f 2>/dev/null)
    fi
    
    echo "📢 Notifications: $total_notifications total ($broadcasts broadcasts)"
    for heat in BLAZ HOT WARM COOL COLD DEAD; do
        if [[ -n "${heat_counts[$heat]:-}" ]]; then
            local heat_color="${HEAT_COLORS[$heat]:-cyan}"
            local colored_heat=$(colorize "$heat" "$heat_color")
            printf "   • %s: %d\n" "$colored_heat" "${heat_counts[$heat]}"
        fi
    done
    echo ""
    
    # Agent statistics
    load_agents
    echo "👥 Agents: ${#AGENTS[@]} registered"
    printf "   • %s\n" "${AGENTS[@]}"
    echo ""
    
    # Project info
    echo "🏗️  Project: $(basename "$(pwd)")"
    echo "   • ID: $PROJECT_ID"
    echo "   • Data: $TASKDB_DIR"
}

# 🚨 SUPER ADMIN: Nuclear option to wipe project data
admin_wipe_project() {
    local confirmation="${1:-}"
    
    if [[ "$confirmation" != "--i-am-sure" ]]; then
        echo "🚨 ═══════════════════════════════════════════════════════════════"
        echo "🚨   SUPER ADMIN: PROJECT WIPE COMMAND"
        echo "🚨 ═══════════════════════════════════════════════════════════════"
        echo ""
        echo "⚠️  This will PERMANENTLY DELETE:"
        echo "   • ALL TASKS for this project"
        echo "   • ALL NOTIFICATIONS for this project"
        echo "   • ALL ACTIVITY LOGS for this project"
        echo "   • Reset ALL COUNTERS for this project"
        echo ""
        echo "✅ This will PRESERVE:"
        echo "   • Agent registry (HR system)"
        echo "   • Global project registry"
        echo "   • Other projects' data"
        echo ""
        echo "📍 Current project: $(colorize "$(basename "$(pwd)")" "bold") (ID: $PROJECT_ID)"
        echo "📂 Data location: $TASKDB_DIR"
        echo ""
        echo "🚨 Usage: admin wipe --i-am-sure"
        echo ""
        return 1
    fi
    
    echo "🚨 INITIATING PROJECT WIPE..."
    echo ""
    
    local items_cleared=0
    local start_time=$(date +%s)
    
    # Clear tasks
    local tasks_cleared=0
    if [[ -f "$TASKS_FILE" ]]; then
        tasks_cleared=$(wc -l < "$TASKS_FILE" 2>/dev/null || echo 0)
        > "$TASKS_FILE"
        echo "🗃️  Cleared $tasks_cleared tasks"
        items_cleared=$((items_cleared + tasks_cleared))
    fi
    
    # Clear notifications
    local notifications_cleared=0
    if [[ -d "$NOTIFICATIONS_DIR" ]]; then
        notifications_cleared=$(find "$NOTIFICATIONS_DIR" -name "*.notification" -type f 2>/dev/null | wc -l)
        rm -rf "$NOTIFICATIONS_DIR"
        mkdir -p "$NOTIFICATIONS_DIR"
        echo "📢 Cleared $notifications_cleared notifications"
        items_cleared=$((items_cleared + notifications_cleared))
    fi
    
    # Clear activity logs
    local activity_cleared=0
    if [[ -f "$STATUS_LOG" ]]; then
        activity_cleared=$(wc -l < "$STATUS_LOG" 2>/dev/null || echo 0)
        > "$STATUS_LOG"
        echo "📝 Cleared $activity_cleared activity log entries"
        items_cleared=$((items_cleared + activity_cleared))
    fi
    
    # Reset counters for this project
    local counters_cleared=0
    local counter_dir="/home/xnull/.local/share/taskdb/projects/$PROJECT_ID/counters"
    if [[ -d "$counter_dir" ]]; then
        counters_cleared=$(find "$counter_dir" -name "*.counter" -type f 2>/dev/null | wc -l)
        rm -rf "$counter_dir"
        mkdir -p "$counter_dir"
        echo "🔢 Reset $counters_cleared project counters"
        items_cleared=$((items_cleared + counters_cleared))
    fi
    
    # Clear any project-specific data but preserve structure
    mkdir -p "$NOTIFICATIONS_DIR"
    touch "$TASKS_FILE"
    touch "$STATUS_LOG"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "✅ ═══════════════════════════════════════════════════════════════"
    echo "✅   PROJECT WIPE COMPLETED"
    echo "✅ ═══════════════════════════════════════════════════════════════"
    echo "📊 Total items cleared: $items_cleared"
    echo "⏱️  Duration: ${duration}s"
    echo "📍 Project: $(basename "$(pwd)") (ID: $PROJECT_ID)"
    echo "🕒 Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "🔄 Project is now clean and ready for new tasks"
    
    # Log the wipe action (after clearing, so it's the first entry in the new log)
    log_activity "🚨 SUPER_ADMIN: Project wiped clean - $items_cleared items cleared by $(whoami)"
}

# ════════════════════════════════════════════════════════════════════════════════════════════════
# 📦 WHIPTAIL DISPLAY FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════════════════════

# Build task content for whiptail display
build_task_content() {
    local task_line="$1"
    local content=""
    
    # Parse fields
    local t_id=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
    local title=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    local assigned_agent=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
    local state=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')
    local priority=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
    local parent_task=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')
    local created_date=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $7); print $7}')
    local updated_date=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $8); print $8}')
    local description=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $9); print $9}')
    
    # Build content with icons and formatting
    local state_icon="${TASK_STATE_ICONS[$state]:-📋}"
    local state_code="${TASK_STATE_CODES[$state]:-UNKN}"
    local priority_icon="${PRIORITY_ICONS[$priority]:-📋}"
    local priority_code="${PRIORITY_CODES[$priority]:-NORM}"
    
    content+="ID: $t_id"$'\n'
    content+="Title: $title"$'\n'
    content+="Agent: $assigned_agent"$'\n'
    content+="State: $state_code ($state_icon $state)"$'\n'
    content+="Priority: $priority_code ($priority_icon $priority)"$'\n'
    [[ -n "$parent_task" ]] && content+="Parent Task: $parent_task"$'\n'
    content+="Created: $created_date"$'\n'
    content+="Updated: $updated_date"$'\n'
    [[ -n "$description" ]] && content+=""$'\n'"Description:"$'\n'"$description"
    
    echo "$content"
}

# Show task using whiptail
show_task_whiptail() {
    local task_id="$1"
    
    local task_line=$(grep "^$task_id|" "$TASKS_FILE" || true)
    if [[ -z "$task_line" ]]; then
        whiptail --title "Task Not Found" --msgbox "Task $task_id not found" 8 50 2>/dev/null || true
        return 1
    fi
    
    local content=$(build_task_content "$task_line")
    local title="Task Details - $task_id"
    
    # Calculate dimensions based on content
    local content_lines=$(echo "$content" | wc -l)
    local height=$((content_lines + 8))  # Extra space for borders and title
    local width=$WHIPTAIL_DEFAULT_WIDTH
    
    # Constrain dimensions
    [[ $height -gt 25 ]] && height=25
    [[ $width -gt $WHIPTAIL_MAX_WIDTH ]] && width=$WHIPTAIL_MAX_WIDTH
    [[ $width -lt $WHIPTAIL_MIN_WIDTH ]] && width=$WHIPTAIL_MIN_WIDTH
    
    whiptail --title "$title" --msgbox "$content" $height $width 2>/dev/null || true
}

# Show task using original fallback formatting
show_task_fallback() {
    local task_id="$1"
    
    local task_line=$(grep "^$task_id|" "$TASKS_FILE" || true)
    if [[ -z "$task_line" ]]; then
        echo "Task $task_id not found"
        return 1
    fi
    
    # Parse pipe-delimited fields with whitespace trimming
    t_id=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
    title=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    assigned_agent=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
    state=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')
    priority=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
    parent_task=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')
    created_date=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $7); print $7}')
    updated_date=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $8); print $8}')
    description=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $9); print $9}')
    
    # Card formatting constants
    local CARD_WIDTH=74
    local CONTENT_WIDTH=$((CARD_WIDTH - 4))  # 70 chars for content
    
    # Helper function to format card lines with exact width
    format_card_line() {
        local content="$1"
        printf "│ %-${CONTENT_WIDTH}s │\n" "$content"
    }
    
    # Helper function for colored content (handles ANSI codes properly)
    format_colored_line() {
        local content="$1"
        
        # Calculate visible length (excluding ANSI codes)
        local clean_content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
        local visible_length=${#clean_content}
        
        # Calculate padding needed
        local padding_needed=$((CONTENT_WIDTH - visible_length - 1))
        
        if [ $padding_needed -gt 0 ]; then
            local padding=$(printf '%*s' $padding_needed '')
            printf "│ %s%s │\n" "$content" "$padding"
        else
            # Content too long, use fallback
            printf "│ %-${CONTENT_WIDTH}s │\n" "$content"
        fi
    }
    
    # Top border - dynamically calculated with proper UTF-8
    local header_text="─ Task Details ─"
    local header_length=${#header_text}
    local remaining_dashes=$((CARD_WIDTH - 2 - header_length))
    local right_dashes=$(printf '─%.0s' $(seq 1 $remaining_dashes))
    echo "┌${header_text}${right_dashes}┐"
    format_card_line "ID: $t_id"
    format_card_line "Title: $title"
    format_card_line "Agent: $assigned_agent"
    # State with icon and description
    local state_icon="${TASK_STATE_ICONS[$state]:-📋}"
    local state_code="${TASK_STATE_CODES[$state]:-UNKN}"
    local colored_state=$(colorize "$state_code" "${STATUS_COLORS[$state]:-cyan}")
    local state_desc="${TASK_STATES[$state]:-Unknown state}"
    # State with icon and description (using colored formatter)
    local state_content="State: $colored_state ($state_icon ${TASK_STATE_CODES[$state]:-UNKN})"
    format_colored_line "$state_content"
    
    # Priority with icon and description  
    local priority_icon="${PRIORITY_ICONS[$priority]:-📋}"
    local priority_code="${PRIORITY_CODES[$priority]:-NORM}"
    local colored_priority=$(colorize "$priority_code" "${PRIORITY_COLORS[$priority]:-cyan}")
    if [[ "$priority" == "CRITICAL" || "$priority" == "URGENT" ]]; then
        colored_priority=$(colorize "$(colorize "$priority_code" "bold")" "${PRIORITY_COLORS[$priority]:-red}")
    fi
    local priority_desc="${PRIORITIES[$priority]:-Normal priority}"
    # Priority with icon and description (using colored formatter)
    local priority_content="Priority: $colored_priority ($priority_icon ${PRIORITY_CODES[$priority]:-NORM})"
    format_colored_line "$priority_content"
    [[ -n "$parent_task" ]] && format_card_line "Parent Task: $parent_task"
    format_card_line "Created: $created_date"
    format_card_line "Updated: $updated_date"
    # Use text wrapping for long descriptions
    if [[ -n "$description" ]]; then
        local desc_prefix="Description: "
        local max_desc_width=$((CONTENT_WIDTH - ${#desc_prefix}))
        if [[ ${#description} -le $max_desc_width ]]; then
            format_card_line "$desc_prefix$description"
        else
            # First line with prefix
            local first_line="${description:0:$max_desc_width}"
            format_card_line "$desc_prefix$first_line"
            
            # Remaining lines with indent
            local remaining="${description:$max_desc_width}"
            local indent="$(printf '%*s' ${#desc_prefix} '')"
            while [[ ${#remaining} -gt 0 ]]; do
                if [[ ${#remaining} -le $max_desc_width ]]; then
                    format_card_line "$indent$remaining"
                    break
                else
                    local line="${remaining:0:$max_desc_width}"
                    format_card_line "$indent$line"
                    remaining="${remaining:$max_desc_width}"
                fi
            done
        fi
    fi
    # Bottom border - dynamically calculated with proper UTF-8
    local bottom_dashes=$(printf '─%.0s' $(seq 1 $((CARD_WIDTH - 2))))
    echo "└${bottom_dashes}┘"
}

# Show task details (main function with display system integration)
show_task() {
    local task_id="$1"
    
    # Initialize display system if not done yet
    if [[ -z "${DISPLAY_MODE:-}" ]]; then
        initialize_display_system
    fi
    
    # Route to appropriate display method
    case "$DISPLAY_MODE" in
        "whiptail")
            show_task_whiptail "$task_id"
            ;;
        "fallback"|*)
            show_task_fallback "$task_id"
            ;;
    esac
}

# List all tasks
list_tasks() {
    local filter_agent="${1:-}"
    local filter_state="${2:-}"
    
    echo "Task Database Status:"
    echo "════════════════════════════════════════════════════"
    
    # Use bash loop for pipe-delimited parsing with color support
    while IFS='|' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        # Skip header
        [[ "$task_id" == "task_id" ]] && continue
        
        # Trim whitespace
        task_id=$(echo "$task_id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') 
        title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        assigned_agent=$(echo "$assigned_agent" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        state=$(echo "$state" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        priority=$(echo "$priority" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        parent_task=$(echo "$parent_task" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        updated_date=$(echo "$updated_date" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Apply filters
        [[ -n "$filter_agent" && "$assigned_agent" != "$filter_agent" ]] && continue
        [[ -n "$filter_state" && "$state" != "$filter_state" ]] && continue
        
        # Priority icons and codes with coloring
        local priority_icon="${PRIORITY_ICONS[$priority]:-📋}"
        local priority_code="${PRIORITY_CODES[$priority]:-NORM}"
        local colored_priority_code=$(colorize "$priority_code" "${PRIORITY_COLORS[$priority]:-cyan}")
        
        # Add bold emphasis for CRITICAL and URGENT priorities
        if [[ "$priority" == "CRITICAL" || "$priority" == "URGENT" ]]; then
            colored_priority_code=$(colorize "$(colorize "$priority_code" "bold")" "${PRIORITY_COLORS[$priority]:-red}")
        fi
        
        # Format state display with icon and 4-letter code
        local state_icon="${TASK_STATE_ICONS[$state]:-📋}"
        local state_code="${TASK_STATE_CODES[$state]:-UNKN}"
        local colored_state=$(colorize "$state_code" "${STATUS_COLORS[$state]:-cyan}")
        
        # Format title with truncation and priority colors
        local truncated_title=$(format_with_ellipsis "$title" 30)
        local colored_title="$truncated_title"
        if [[ "$priority" == "CRITICAL" ]]; then
            colored_title=$(colorize "$(colorize "$truncated_title" "bold")" "${PRIORITY_COLORS[CRITICAL]:-red}")
        elif [[ "$priority" == "URGENT" ]]; then
            colored_title=$(colorize "$(colorize "$truncated_title" "bold")" "${PRIORITY_COLORS[URGENT]:-red}")
        elif [[ "$priority" == "HIGH" ]]; then
            colored_title=$(colorize "$truncated_title" "${PRIORITY_COLORS[HIGH]:-yellow}")
        fi
        
        # Format parent task
        local parent_display=""
        [[ -n "$parent_task" ]] && parent_display="[parent: $parent_task]"
        
        # Print formatted line with colored priority code
        printf "%-12s %s%s %-30s %-6s %-4s %-18s %s\n" \
               "$task_id" \
               "$priority_icon" \
               "$colored_priority_code" \
               "$colored_title" \
               "$assigned_agent" \
               "$colored_state" \
               "$updated_date" \
               "$parent_display"
    done < "$TASKS_FILE"
    echo ""
    echo "$(colorize "💡 ⭐ For legend > help codes icons" "gray")"
}

# Format string with ellipsis if too long
format_with_ellipsis() {
    local string="$1"
    local max_length="$2"
    
    if [[ ${#string} -le $max_length ]]; then
        printf "%-${max_length}s" "$string"
    else
        printf "%-${max_length}s" "${string:0:$((max_length-3))}..."
    fi
}

# Show comprehensive status with dependency tree


# FUNC_META | src:/home/xnull/repos/shell/bashfx/fx-padlock/xbin/taskdb.sh | src_sum:e46d4579e568128505d76c2526c11fbcd124a95bd653843300150ab2ea0bab4c | orig:show_status | edit:show_status_colored | orig_sum:b1f2eef8f8565b1e011963862d88cecb3cd6762287c456b958784647fa02b418


# FUNC_META | src:/home/xnull/repos/shell/bashfx/fx-padlock/xbin/taskdb.sh | src_sum:50afd0feeb5e7757f93a2a0ea583c24ee7ee529931e5cc4641358d042f40294a | orig:show_status_colored | edit:show_status_fixed | orig_sum:ebbd71bdaf4e18c17e9193cc7b72b34a0294afe5759f01eb6ca71c10fe6567eb
show_status_fixed() {
    echo "════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "                                    TASK DATABASE - DEPENDENCY STATUS                            "
    echo "════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Header
    printf "%-18s %-3s %-25s %-8s %-15s %-12s %-19s %-10s\n" \
           "TASK ID" "PRI" "TITLE" "AGENT" "STATE" "UPDATED" "CREATED" "PARENT"
    echo "────────────────────────────────────────────────────────────────────────────────────────────────"
    
    # Build task maps for dependency resolution
    declare -A task_titles task_agents task_states task_priorities task_created task_updated task_parents
    declare -A children_map
    declare -a root_tasks
    
    # Read all tasks and build lookup maps
    while IFS='|' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        [[ "$task_id" == "task_id" ]] && continue  # Skip header
        
        task_titles["$task_id"]="$title"
        task_agents["$task_id"]="$assigned_agent"
        task_states["$task_id"]="$state"
        task_priorities["$task_id"]="$priority"
        task_created["$task_id"]="$created_date"
        task_updated["$task_id"]="$updated_date"
        task_parents["$task_id"]="$parent_task"
        
        if [[ -n "$parent_task" ]]; then
            children_map["$parent_task"]+="$task_id "
        else
            root_tasks+=("$task_id")
        fi
    done < "$TASKS_FILE"
    
    # Function to print task and its children recursively
    print_task_tree() {
        local task_id="$1"
        local indent="$2"
        local is_child="$3"
        
        # Get priority icon and colors
        local priority="${task_priorities[$task_id]:-}"
        local priority_icon=""
        case "$priority" in
            "CRITICAL") priority_icon="🚨" ;;
            "HIGH") priority_icon="⚡" ;;
            "NORMAL") priority_icon="📋" ;;
            "LOW") priority_icon="⏳" ;;
        esac
        
        # Format state with visual indicators and colors
        local state="${task_states[$task_id]:-}"
        local state_display="$state"
        if [[ "$state_display" =~ FIX_ ]]; then
            state_display="🔧 $state_display"
        fi
        
        # Apply colors to state (with safety check)
        local colored_state="$state_display"
        if [[ -n "$state" ]] && [[ -v STATUS_COLORS[$state] ]]; then
            colored_state=$(colorize "$state_display" "${STATUS_COLORS[$state]}")
        elif [[ -n "$state_display" ]]; then
            colored_state=$(colorize "$state_display" "cyan")
        fi
        
        # Add tree structure indicators
        local tree_prefix=""
        if [[ "$is_child" == "true" ]]; then
            tree_prefix="$indent├─ "
        fi
        
        # Format and print the task line
        local formatted_id
        local formatted_title
        local formatted_agent
        local formatted_state
        local formatted_updated
        local formatted_created
        local formatted_parent
        
        formatted_id=$(format_with_ellipsis "${tree_prefix}${task_id}" 18)
        
        # Apply title colors based on priority (with safety checks)
        local title="${task_titles[$task_id]:-}"
        local colored_title="$title"
        if [[ "$priority" == "CRITICAL" ]] && [[ -v PRIORITY_COLORS[CRITICAL] ]]; then
            colored_title=$(colorize "$(colorize "$title" "bold")" "${PRIORITY_COLORS[CRITICAL]}")
        elif [[ "$priority" == "HIGH" ]] && [[ -v PRIORITY_COLORS[HIGH] ]]; then
            colored_title=$(colorize "$title" "${PRIORITY_COLORS[HIGH]}")
        fi
        
        formatted_title=$(format_with_ellipsis "$colored_title" 25)
        formatted_agent=$(format_with_ellipsis "${task_agents[$task_id]:-}" 8)
        formatted_state=$(format_with_ellipsis "$colored_state" 15)
        local updated_val="${task_updated[$task_id]:-}"
        local created_val="${task_created[$task_id]:-}"
        formatted_updated=$(format_with_ellipsis "${updated_val##* }" 12)  # Just time part
        formatted_created=$(format_with_ellipsis "${created_val##* }" 19)  # Just time part  
        formatted_parent=$(format_with_ellipsis "${task_parents[$task_id]:-}" 10)
        
        printf "%s %s %s %s %s %s %s %s\n" \
               "$formatted_id" \
               "$priority_icon" \
               "$formatted_title" \
               "$formatted_agent" \
               "$formatted_state" \
               "$formatted_updated" \
               "$formatted_created" \
               "$formatted_parent"
        
        # Print children with increased indentation
        if [[ -n "${children_map[$task_id]:-}" ]]; then
            local child_indent="$indent  "
            for child_id in ${children_map[$task_id]:-}; do
                print_task_tree "$child_id" "$child_indent" "true"
            done
        fi
    }
    
    # Sort root tasks by priority (CRITICAL first, then by task_id)
    IFS=$'\n' sorted_roots=($(printf '%s\n' "${root_tasks[@]}" | sort -t'|' -k1,1))
    
    # Print root tasks and their dependency trees
    for task_id in "${sorted_roots[@]}"; do
        print_task_tree "$task_id" "" "false"
    done
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📊 SUMMARY:"
    
    # Count tasks by state
    declare -A state_counts
    set +u  # Temporarily disable undefined variable errors for associative arrays
    for task_id in "${!task_states[@]}"; do
        local state="${task_states[$task_id]:-}"
        if [[ -n "$state" ]]; then
            local current_count="${state_counts[$state]:-0}"
            state_counts["$state"]=$((current_count + 1))
        fi
    done
    set -u  # Re-enable undefined variable errors
    
    for state in ASSIGNED IN_PROGRESS DEV_COMPLETE REVIEW_PENDING ISSUES_FOUND FIX_ASSIGNED FIX_IN_PROGRESS FIX_COMPLETE VALIDATED PRODUCTION_READY; do
        if [[ ${state_counts[$state]:-0} -gt 0 ]]; then
            local colored_state_name="$state"
            if [[ -v STATUS_COLORS[$state] ]]; then
                colored_state_name=$(colorize "$state" "${STATUS_COLORS[$state]}")
            else
                colored_state_name=$(colorize "$state" "cyan")
            fi
            echo "  $colored_state_name: ${state_counts[$state]:-0} task(s)"
        fi
    done
    
    echo ""
    echo "💡 Use 'taskdb.sh show TASK-ID' to drill down into specific task details"
}

show_status_colored() {
    echo "════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "                                    TASK DATABASE - DEPENDENCY STATUS                            "
    echo "════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Header
    printf "%-18s %-3s %-25s %-8s %-15s %-12s %-19s %-10s\n" \
           "TASK ID" "PRI" "TITLE" "AGENT" "STATE" "UPDATED" "CREATED" "PARENT"
    echo "────────────────────────────────────────────────────────────────────────────────────────────────"
    
    # Build task maps for dependency resolution
    declare -A task_titles task_agents task_states task_priorities task_created task_updated task_parents
    declare -A children_map
    declare -a root_tasks
    
    # Read all tasks and build lookup maps
    while IFS='|' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        [[ "$task_id" == "task_id" ]] && continue  # Skip header
        
        task_titles["$task_id"]="$title"
        task_agents["$task_id"]="$assigned_agent"
        task_states["$task_id"]="$state"
        task_priorities["$task_id"]="$priority"
        task_created["$task_id"]="$created_date"
        task_updated["$task_id"]="$updated_date"
        task_parents["$task_id"]="$parent_task"
        
        if [[ -n "$parent_task" ]]; then
            children_map["$parent_task"]+="$task_id "
        else
            root_tasks+=("$task_id")
        fi
    done < "$TASKS_FILE"
    
    # Function to print task and its children recursively
    print_task_tree() {
        local task_id="$1"
        local indent="$2"
        local is_child="$3"
        
        # Get priority icon and colors
        local priority="${task_priorities[$task_id]:-}"
        local priority_icon=""
        case "$priority" in
            "CRITICAL") priority_icon="🚨" ;;
            "HIGH") priority_icon="⚡" ;;
            "NORMAL") priority_icon="📋" ;;
            "LOW") priority_icon="⏳" ;;
        esac
        
        # Format state with visual indicators and colors
        local state="${task_states[$task_id]:-}"
        local state_display="$state"
        if [[ "$state_display" =~ FIX_ ]]; then
            state_display="🔧 $state_display"
        fi
        
        # Apply colors to state
        local colored_state=$(colorize "$state_display" "${STATUS_COLORS[$state]:-cyan}")
        
        # Add tree structure indicators
        local tree_prefix=""
        if [[ "$is_child" == "true" ]]; then
            tree_prefix="$indent├─ "
        fi
        
        # Format and print the task line
        local formatted_id
        local formatted_title
        local formatted_agent
        local formatted_state
        local formatted_updated
        local formatted_created
        local formatted_parent
        
        formatted_id=$(format_with_ellipsis "${tree_prefix}${task_id}" 18)
        
        # Apply title colors based on priority
        local title="${task_titles[$task_id]:-}"
        local colored_title="$title"
        if [[ "$priority" == "CRITICAL" ]]; then
            colored_title=$(colorize "$(colorize "$title" "bold")" "${PRIORITY_COLORS[CRITICAL]:-red}")
        elif [[ "$priority" == "HIGH" ]]; then
            colored_title=$(colorize "$title" "${PRIORITY_COLORS[HIGH]:-yellow}")
        fi
        
        formatted_title=$(format_with_ellipsis "$colored_title" 25)
        formatted_agent=$(format_with_ellipsis "${task_agents[$task_id]:-}" 8)
        formatted_state=$(format_with_ellipsis "$colored_state" 15)
        local updated_val="${task_updated[$task_id]:-}"
        local created_val="${task_created[$task_id]:-}"
        formatted_updated=$(format_with_ellipsis "${updated_val##* }" 12)  # Just time part
        formatted_created=$(format_with_ellipsis "${created_val##* }" 19)  # Just time part  
        formatted_parent=$(format_with_ellipsis "${task_parents[$task_id]:-}" 10)
        
        printf "%s %s %s %s %s %s %s %s\n" \
               "$formatted_id" \
               "$priority_icon" \
               "$formatted_title" \
               "$formatted_agent" \
               "$formatted_state" \
               "$formatted_updated" \
               "$formatted_created" \
               "$formatted_parent"
        
        # Print children with increased indentation
        if [[ -n "${children_map[$task_id]:-}" ]]; then
            local child_indent="$indent  "
            for child_id in ${children_map[$task_id]:-}; do
                print_task_tree "$child_id" "$child_indent" "true"
            done
        fi
    }
    
    # Sort root tasks by priority (CRITICAL first, then by task_id)
    IFS=$'\n' sorted_roots=($(printf '%s\n' "${root_tasks[@]}" | sort -t'|' -k1,1))
    
    # Print root tasks and their dependency trees
    for task_id in "${sorted_roots[@]}"; do
        print_task_tree "$task_id" "" "false"
    done
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📊 SUMMARY:"
    
    # Count tasks by state
    declare -A state_counts
    set +u  # Temporarily disable undefined variable errors for associative arrays
    for task_id in "${!task_states[@]}"; do
        local state="${task_states[$task_id]:-}"
        if [[ -n "$state" ]]; then
            local current_count="${state_counts[$state]:-0}"
            state_counts["$state"]=$((current_count + 1))
        fi
    done
    set -u  # Re-enable undefined variable errors
    
    for state in ASSIGNED IN_PROGRESS DEV_COMPLETE REVIEW_PENDING ISSUES_FOUND FIX_ASSIGNED FIX_IN_PROGRESS FIX_COMPLETE VALIDATED PRODUCTION_READY; do
        if [[ ${state_counts[$state]:-0} -gt 0 ]]; then
            local colored_state_name=$(colorize "$state" "${STATUS_COLORS[$state]:-cyan}")
            echo "  $colored_state_name: ${state_counts[$state]:-0} task(s)"
        fi
    done
    
    echo ""
    echo "💡 Use 'taskdb.sh show TASK-ID' to drill down into specific task details"
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
    while IFS='|' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        [[ "$assigned_agent" != "$agent" ]] && continue
        [[ "$state" == "PRODUCTION_READY" ]] && continue
        
        if [[ "$priority" == "CRITICAL" || "$state" =~ FIX_ ]]; then
            if [[ "$has_critical" == false ]]; then
                echo "🚨 CRITICAL PATH (work this first):"
                echo "──────────────────────────────────────────────────"
                has_critical=true
            fi
            local colored_state=$(colorize "$state" "${STATUS_COLORS[$state]:-red}")
            local colored_title="$title"
            if [[ "$priority" == "CRITICAL" ]]; then
                colored_title=$(colorize "$(colorize "$title" "bold")" "${PRIORITY_COLORS[CRITICAL]:-red}")
            fi
            printf "  %-12s %s %s\n" "$task_id" "$colored_state" "$colored_title"
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
    while IFS='|' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        [[ "$assigned_agent" != "$agent" ]] && continue
        [[ "$state" == "PRODUCTION_READY" ]] && continue
        [[ "$priority" == "CRITICAL" || "$state" =~ FIX_ ]] && continue
        
        local priority_icon=""
        case "$priority" in
            "HIGH") priority_icon="⚡" ;;
            "NORMAL") priority_icon="📋" ;;
            "LOW") priority_icon="⏳" ;;
        esac
        
        local colored_state=$(colorize "$state" "${STATUS_COLORS[$state]:-cyan}")
        local colored_title="$title"
        if [[ "$priority" == "HIGH" ]]; then
            colored_title=$(colorize "$title" "${PRIORITY_COLORS[HIGH]:-yellow}")
        elif [[ "$priority" == "CRITICAL" ]]; then
            colored_title=$(colorize "$(colorize "$title" "bold")" "${PRIORITY_COLORS[CRITICAL]:-red}")
        fi
        printf "  %-12s %s %-15s %s\n" "$task_id" "$priority_icon" "$colored_state" "$colored_title"
    done < <(tail -n +2 "$TASKS_FILE")
    
    echo ""
    
    # Show recent notifications with heat indicators
    local agent_clean="${agent#@}"
    
    # Get separate lists for notifications and broadcasts
    local notification_list
    notification_list=$(find "$NOTIFICATIONS_DIR/$agent_clean" -name "*.notification" 2>/dev/null | sort -nr)
    local broadcast_list
    broadcast_list=$(find "$NOTIFICATIONS_DIR/$agent_clean" -name "*.broadcast" 2>/dev/null | sort -nr)
    
    set +e  # Temporarily disable strict error checking
    local notification_files=($notification_list)
    local broadcast_files=($broadcast_list)
    set -e  # Re-enable strict error checking
    
    local notification_count=${#notification_files[@]}
    local broadcast_count=${#broadcast_files[@]}
    local total_count=$((notification_count + broadcast_count))
    
    if [[ $total_count -gt 0 ]]; then
        echo "📢 NOTIFICATIONS (Heat-tracked):"
        echo "──────────────────────────────────────────────────"
        
        # Count hot notifications and broadcasts (less than 3 hours old)
        local hot_count=0
        local hot_broadcast_count=0
        local current_time=$(date +%s)
        
        # Count hot notifications
        for file in "${notification_files[@]}"; do
            local filename=$(basename "$file" .notification)
            local timestamp="${filename##*.}"
            local age_hours=$(((current_time - timestamp) / 3600))
            if [[ $age_hours -le 3 ]]; then
                ((hot_count++))
            fi
        done
        
        # Count hot broadcasts
        for file in "${broadcast_files[@]}"; do
            local filename=$(basename "$file" .broadcast)
            local timestamp="${filename##*.}"
            local age_hours=$(((current_time - timestamp) / 3600))
            if [[ $age_hours -le 3 ]]; then
                ((hot_count++))
                ((hot_broadcast_count++))
            fi
        done
        
        # Show broadcast count if any
        if [[ $broadcast_count -gt 0 ]]; then
            if [[ $hot_broadcast_count -gt 0 ]]; then
                echo "🚨 $hot_broadcast_count HOT BROADCAST(S) - Priority review required!"
                echo ""
            else
                echo "📢 $broadcast_count broadcast notification(s) available"
                echo ""
            fi
        fi
        
        # Show only HOT/WARM notifications with heat, prioritizing hot broadcasts
        local shown=0
        local cooler_count=0
        
        # First pass: show hot broadcasts (BLAZ/HOT/WARM)
        for file in "${broadcast_files[@]}"; do
            if [[ $shown -ge 5 ]]; then break; fi
            
            local filename=$(basename "$file" .broadcast)
            local timestamp="${filename##*.}"
            local heat_info=$(get_notification_heat "$timestamp")
            local heat_code=$(echo "$heat_info" | cut -d'|' -f1)
            
            if [[ "$heat_code" == "BLAZ" || "$heat_code" == "HOT" || "$heat_code" == "WARM" ]]; then
                format_notification_with_heat "$file"
                ((shown++))
            else
                ((cooler_count++))
            fi
        done
        
        # Second pass: show HOT/WARM notifications
        for file in "${notification_files[@]}"; do
            if [[ $shown -ge 5 ]]; then break; fi
            
            local filename=$(basename "$file" .notification)
            local timestamp="${filename##*.}"
            local heat_info=$(get_notification_heat "$timestamp")
            local heat_code=$(echo "$heat_info" | cut -d'|' -f1)
            
            if [[ "$heat_code" == "BLAZ" || "$heat_code" == "HOT" || "$heat_code" == "WARM" ]]; then
                format_notification_with_heat "$file"
                ((shown++))
            else
                ((cooler_count++))
            fi
        done
        
        # Show count of cooler notifications
        if [[ $cooler_count -gt 0 ]]; then
            echo ""
            echo "🔷 $cooler_count cooler notification(s) available (COOL/COLD/DEAD)"
        fi
        
        # Show help for notification management
        if [[ $shown -gt 0 || $cooler_count -gt 0 ]]; then
            echo ""
            echo "💡 Use 'taskdb.sh notifications $agent' to review all notifications by heat"
            echo "💡 Use 'taskdb.sh resolve $agent ID' to resolve individual notifications"
            echo "🧹 Use 'taskdb.sh clear-notifications $agent' to clear all notifications"
        fi
        echo ""
    fi
}

# Show all notifications for agent with heat indicators
show_notifications() {
    local agent="$1"
    local agent_clean="${agent#@}"
    
    echo "════════════════════════════════════════════════════"
    echo "  $agent NOTIFICATION HEAT MAP"
    echo "════════════════════════════════════════════════════"
    echo ""
    
    # Get separate lists for notifications and broadcasts
    local notification_list
    notification_list=$(find "$NOTIFICATIONS_DIR/$agent_clean" -name "*.notification" 2>/dev/null | sort -nr)
    local broadcast_list
    broadcast_list=$(find "$NOTIFICATIONS_DIR/$agent_clean" -name "*.broadcast" 2>/dev/null | sort -nr)
    
    set +e  # Temporarily disable strict error checking
    local notification_files=($notification_list)
    local broadcast_files=($broadcast_list)
    set -e  # Re-enable strict error checking
    
    local notification_count=${#notification_files[@]}
    local broadcast_count=${#broadcast_files[@]}
    local total_count=$((notification_count + broadcast_count))
    
    if [[ $total_count -eq 0 ]]; then
        echo "✅ No notifications for $agent"
        echo ""
        return
    fi
    
    echo "ALL NOTIFICATIONS ($total_count total):"
    echo "──────────────────────────────────────────────────"
    
    # Group notifications by heat level
    declare -A heat_groups
    
    # Process notification files
    for file in "${notification_files[@]}"; do
        local filename=$(basename "$file" .notification)
        local timestamp="${filename##*.}"
        local heat_info=$(get_notification_heat "$timestamp")
        local heat_code=$(echo "$heat_info" | cut -d'|' -f1)
        heat_groups["$heat_code"]+="$file "
    done
    
    # Process broadcast files
    for file in "${broadcast_files[@]}"; do
        local filename=$(basename "$file" .broadcast)
        local timestamp="${filename##*.}"
        local heat_info=$(get_notification_heat "$timestamp")
        local heat_code=$(echo "$heat_info" | cut -d'|' -f1)
        heat_groups["$heat_code"]+="$file "
    done
    
    # Display in heat order: BLAZ, HOT, WARM, COOL, COLD, DEAD
    for heat in BLAZ HOT WARM COOL COLD DEAD; do
        if [[ -n "${heat_groups[$heat]:-}" ]]; then
            echo ""
            echo "[$heat] Notifications:"
            for file in ${heat_groups[$heat]}; do
                echo "  $(format_notification_with_heat "$file")"
            done
        fi
    done
    echo ""
    echo "💡 Use 'taskdb.sh help heat' to see heat level legend"
    echo "💡 Use 'taskdb.sh clear-notifications $agent' to remove old notifications"
}

# Clear all notifications for agent
clear_notifications() {
    local agent="$1"
    local agent_clean="${agent#@}"
    rm -f "$NOTIFICATIONS_DIR/$agent_clean"/*.notification "$NOTIFICATIONS_DIR/$agent_clean"/*.broadcast 2>/dev/null || true
    echo "All notifications cleared for $agent"
}

# Broadcast notification to all agents
broadcast_notification() {
    local message="$1"
    local priority="${2:-NORMAL}"
    
    load_agents
    local timestamp=$(date +%s)
    
    # Create broadcast for each agent
    for agent in "${AGENTS[@]}"; do
        local agent_clean="${agent#@}"
        mkdir -p "$NOTIFICATIONS_DIR/$agent_clean"
        
        # Get unique broadcast ID using notification counter
        local broadcast_id
        broadcast_id=$(get_next_id "notifications" "$agent")
        local broadcast_file="$NOTIFICATIONS_DIR/$agent_clean/${broadcast_id}.${timestamp}.broadcast"
        
        case "$priority" in
            "CRITICAL")
                echo "🚨 BROADCAST: $message" > "$broadcast_file"
                ;;
            "HIGH")
                echo "📢 BROADCAST: $message" > "$broadcast_file"
                ;;
            *)
                echo "📋 BROADCAST: $message" > "$broadcast_file"
                ;;
        esac
    done
    
    echo "📢 Broadcast sent to ${#AGENTS[@]} agents: $message"
}

# Resolve specific notification by ID
resolve_notification() {
    local agent="$1"
    local notification_id="$2"
    local agent_clean="${agent#@}"
    
    # Find notification or broadcast file with this ID
    local notification_file
    notification_file=$(find "$NOTIFICATIONS_DIR/$agent_clean" \( -name "${notification_id}.*.notification" -o -name "${notification_id}.*.broadcast" \) 2>/dev/null | head -1)
    
    if [[ -z "$notification_file" ]]; then
        echo "❌ Notification #$notification_id not found for $agent"
        return 1
    fi
    
    rm "$notification_file"
    echo "✅ Notification #$notification_id resolved for $agent"
}

# Show training and workflow examples
show_training() {
    local title_color=$(colorize "TASKDB TRAINING GUIDE" "cyan")
    echo "════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "                                    $title_color"
    echo "════════════════════════════════════════════════════════════════════════════════════════════════"
cat <<EOF

$(colorize "📚 TASK WORKFLOW TRAINING" "yellow")

┌─ TASK LIFECYCLE ──────────────────────────────────────────────────────────────────────────────┐
│                                                                                                │
│  1. CREATE → 2. ASSIGN → 3. IN_PROGRESS → 4. DEV_COMPLETE → 5. REVIEW → 6. PRODUCTION_READY  │
│                                                                                                │
│  🔄 IF ISSUES FOUND: → FIX_ASSIGNED → FIX_IN_PROGRESS → FIX_COMPLETE → VALIDATED             │
│                                                                                                │
└────────────────────────────────────────────────────────────────────────────────────────────────┘

$(colorize "📝 TASK MANAGEMENT EXAMPLES:" "green")

  # Create new task (auto-generates ID like TASK-007)
  taskdb.sh create "Fix authentication bug" @LSE HIGH

  # Update task state as you work
  taskdb.sh update TASK-007 IN_PROGRESS @LSE

  # Mark task complete when done
  taskdb.sh update TASK-007 DEV_COMPLETE @LSE

  # QA reviews and either approves or finds issues
  taskdb.sh update TASK-007 ISSUES_FOUND @QA  # Creates TASK-007-FIX automatically
  taskdb.sh update TASK-007 PRODUCTION_READY @QA  # or approves if good

  # Check what you should work on next
  taskdb.sh dashboard @LSE

  # See all your tasks
  taskdb.sh list @LSE

══════════════════════════════════════════════════════════════════════════════════════════════════

$(colorize "📢 NOTIFICATION & BROADCAST TRAINING" "yellow")

┌─ NOTIFICATION TYPES ──────────────────────────────────────────────────────────────────────────┐
│                                                                                                │
│  🔔 NOTIFICATIONS: Direct messages to specific agents (task updates, assignments, etc.)       │
│  📢 BROADCASTS: System-wide messages to ALL agents (meetings, announcements, etc.)            │
│                                                                                                │
└────────────────────────────────────────────────────────────────────────────────────────────────┘

$(colorize "📨 NOTIFICATION WORKFLOW:" "green")

  # Check your notifications (shows hot ones first)
  taskdb.sh notifications @USER

  # Resolve specific notification by ID
  taskdb.sh resolve @USER 005

  # Clear all your notifications
  taskdb.sh clear-notifications @USER

📡 BROADCAST WORKFLOW:

  # Send message to ALL agents (use sparingly!)
  taskdb.sh broadcast "Team meeting tomorrow 10 AM" HIGH

  # Critical system announcements
  taskdb.sh broadcast "System maintenance in 1 hour" CRITICAL

  # Broadcasts show up in everyone's dashboard with high priority

══════════════════════════════════════════════════════════════════════════════════════════════════

🌡️  NOTIFICATION HEAT SYSTEM

  🔴 🚨 [BLAZ] - Blazing hot (< 1 hour) - IMMEDIATE ATTENTION REQUIRED
  🟠 🔥 [HOT]  - Hot (1-3 hours) - High priority, review soon  
  🟡 ⚠️  [WARM] - Warm (3-6 hours) - Should review when convenient
  🔷 🧊 [COOL] - Cool (6-12 hours) - May need refresh, lower priority
  🔵 ❄️  [COLD] - Cold (> 12 hours) - Likely stale, consider resolving
  🔘 💀 [DEAD] - Dead (> 1 day) - Probably invalid, should clean up

  💡 Dashboard shows only HOT/WARM notifications to reduce noise
  💡 Use 'notifications @AGENT' to see all notifications by heat

══════════════════════════════════════════════════════════════════════════════════════════════════

🎯 COMMON WORKFLOWS

👤 AS A DEVELOPER (@LSE):
  1. taskdb.sh dashboard @LSE                    # See what to work on
  2. taskdb.sh update TASK-123 IN_PROGRESS      # Start working
  3. taskdb.sh update TASK-123 DEV_COMPLETE     # Mark done
  4. taskdb.sh notifications @LSE               # Check for updates

🔍 AS QA (@QA):
  1. taskdb.sh list DEV_COMPLETE                # Find tasks to review
  2. taskdb.sh update TASK-123 ISSUES_FOUND     # If problems found
  3. taskdb.sh update TASK-123 PRODUCTION_READY # If approved

📋 AS COORDINATOR (@OXX):
  1. taskdb.sh status                           # See project overview
  2. taskdb.sh create "New urgent task" @LSE CRITICAL
  3. taskdb.sh broadcast "Sprint demo Friday" NORMAL

🛠️ USEFUL COMMANDS:

  # Preview next IDs (useful for planning)
  taskdb.sh next task                          # Shows TASK-008
  taskdb.sh next notif @USER                   # Shows 006

  # Project management
  taskdb.sh projects list                      # See all projects
  taskdb.sh hr list                           # See team roster

  # Quick status checks
  taskdb.sh agents                            # Available agents
  taskdb.sh states                            # Available task states

══════════════════════════════════════════════════════════════════════════════════════════════════

💡 BEST PRACTICES:

  ✅ Check your dashboard daily: taskdb.sh dashboard @YOU
  ✅ Resolve notifications promptly to keep system clean
  ✅ Use CRITICAL priority sparingly (only true emergencies)
  ✅ Update task states as you work (keeps team informed)
  ✅ Use broadcasts for team-wide info (meetings, announcements)

  ❌ Don't let notifications pile up (they get stale)
  ❌ Don't use broadcasts for individual task updates
  ❌ Don't skip state updates (team loses visibility)

════════════════════════════════════════════════════════════════════════════════════════════════
EOF
}

# Show help for specific topics
show_help() {
    local topic="${1:-}"
    
    case "$topic" in
        "tasks")
            echo "$(colorize "📋  TASK STATE SYSTEM" "cyan")"
            echo ""
            echo "$(colorize "📊 STATE LEGEND:" "yellow")"
            for state in ASSIGNED RESEARCH_REQUIRED PRODUCT_REVIEW IN_PROGRESS DEV_COMPLETE REVIEW_PENDING ISSUES_FOUND FIX_ASSIGNED FIX_IN_PROGRESS FIX_COMPLETE VALIDATED PRODUCTION_READY ARCHIVED; do
                local icon="${TASK_STATE_ICONS[$state]}"
                local code="${TASK_STATE_CODES[$state]}"
                local desc="${TASK_STATES[$state]}"
                echo "  $(colorize "$icon [$code] - $desc" "${STATUS_COLORS[$state]:-cyan}")"
            done
            echo ""
            echo "💡 Workflow: ASSN → INPR → DEVD → REVW → PASS → PROD → DONE"
            echo "💡 Research: Use RXRQ when R&D exploration needed first"
            echo "💡 Product: Use PRRV when scope is too big or needs input"
            echo "💡 Fixes: REGR creates automatic FIX tasks with CRITICAL priority"
            ;;
        "priority")
            echo "$(colorize "⚙️  PRIORITY SYSTEM" "cyan")"
            echo ""
            echo "$(colorize "📊 PRIORITY LEGEND:" "yellow")"
            for priority in CRITICAL URGENT HIGH NORMAL BACKLOG; do
                local icon="${PRIORITY_ICONS[$priority]}"
                local code="${PRIORITY_CODES[$priority]}"
                local desc="${PRIORITIES[$priority]}"
                echo "  $(colorize "$icon [$code] - $desc" "${PRIORITY_COLORS[$priority]:-cyan}")"
            done
            echo ""
            echo "💡 Sprint Planning: CRIT (now) → URGT (sprint) → HIGH (current) → NORM (scoped) → BACK (review)"
            echo "💡 Escalation: Devs can elevate BACK items to higher priorities"
            echo "💡 CRIT vs URGT: CRIT = drop everything, URGT = this sprint/session"
            ;;
        "heat")
            echo "$(colorize "🌡️  NOTIFICATION HEAT SYSTEM" "cyan")"
            echo ""
            echo "$(colorize "📊 HEAT LEGEND:" "yellow")"
            for heat in BLAZ HOT WARM COOL COLD DEAD; do
                local icon="${HEAT_ICONS[${HEAT_CODES[$heat]}]}"
                local code="${HEAT_CODES[$heat]}"
                local color="${HEAT_COLORS[$heat]}"
                case "$heat" in
                    "BLAZ") echo "  $(colorize "$icon [$code] - Blazing hot (< 1 hour) - IMMEDIATE ATTENTION" "$color")" ;;
                    "HOT") echo "  $(colorize "$icon [${HEAT_CODES[HOT]}] - Spicy hot (1-3 hours) - High priority review" "$color")" ;;
                    "WARM") echo "  $(colorize "$icon [$code] - Warm coffee (3-6 hours) - Should review soon" "$color")" ;;
                    "COOL") echo "  $(colorize "$icon [$code] - Cool ice (6-12 hours) - May need refresh" "$color")" ;;
                    "COLD") echo "  $(colorize "$icon [$code] - Cold freeze (> 12 hours) - Likely stale" "$color")" ;;
                    "DEAD") echo "  $(colorize "$icon [$code] - Dead skull (> 1 day) - Probably invalid" "$color")" ;;
                esac
            done
            echo ""
            echo "💡 Dashboard shows only SPCY/WARM notifications to reduce noise"
            echo "💡 Use 'notifications @AGENT' to see all notifications by heat"
            echo "💡 Use --color flag to see heat levels in color"
            ;;
        "codes")
            echo "$(colorize "🏷️  4-LETTER CODE REFERENCE" "cyan")"
            echo ""
            echo "$(colorize "📋 TASK STATES:" "yellow")"
            for state in ASSIGNED RESEARCH_REQUIRED PRODUCT_REVIEW IN_PROGRESS DEV_COMPLETE REVIEW_PENDING ISSUES_FOUND FIX_ASSIGNED FIX_IN_PROGRESS FIX_COMPLETE VALIDATED PRODUCTION_READY ARCHIVED; do
                printf "  %-4s = %s\n" "${TASK_STATE_CODES[$state]}" "$state"
            done
            echo ""
            echo "$(colorize "⚙️ PRIORITIES:" "yellow")"
            for priority in CRITICAL URGENT HIGH NORMAL BACKLOG; do
                printf "  %-4s = %s\n" "${PRIORITY_CODES[$priority]}" "$priority"
            done
            echo ""
            echo "$(colorize "🌡️ HEAT LEVELS:" "yellow")"
            for heat in BLAZ HOT WARM COOL COLD DEAD; do
                printf "  %-4s = %s\n" "${HEAT_CODES[$heat]}" "$heat"
            done
            ;;
        "icons")
            echo "$(colorize "🎨  ICONOGRAPHY REFERENCE" "cyan")"
            echo ""
            echo "$(colorize "📋 TASK STATE ICONS:" "yellow")"
            for state in ASSIGNED RESEARCH_REQUIRED PRODUCT_REVIEW IN_PROGRESS DEV_COMPLETE REVIEW_PENDING ISSUES_FOUND FIX_ASSIGNED FIX_IN_PROGRESS FIX_COMPLETE VALIDATED PRODUCTION_READY ARCHIVED; do
                printf "  %s %-4s = %s\n" "${TASK_STATE_ICONS[$state]}" "${TASK_STATE_CODES[$state]}" "$state"
            done
            echo ""
            echo "$(colorize "⚙️ PRIORITY ICONS:" "yellow")"
            for priority in CRITICAL URGENT HIGH NORMAL BACKLOG; do
                printf "  %s %-4s = %s\n" "${PRIORITY_ICONS[$priority]}" "${PRIORITY_CODES[$priority]}" "$priority"
            done
            echo ""
            echo "$(colorize "🌡️ HEAT LEVEL ICONS:" "yellow")"
            for heat in BLAZ HOT WARM COOL COLD DEAD; do
                printf "  %s %-4s = %s\n" "${HEAT_ICONS[${HEAT_CODES[$heat]}]}" "${HEAT_CODES[$heat]}" "$heat"
            done
            ;;
        *)
            echo "$(colorize "Available help topics:" "yellow")"
            echo "  $(colorize "tasks" "cyan")     Task states legend + workflow notes"
            echo "  $(colorize "priority" "cyan")  Priority levels legend + usage notes"
            echo "  $(colorize "heat" "cyan")      Heat levels legend + aging system"
            echo "  $(colorize "codes" "cyan")     All 4-letter abbreviations reference"
            echo "  $(colorize "icons" "cyan")     Complete iconography reference"
            echo ""
            echo "Usage: taskdb.sh help TOPIC"
            echo "$(colorize "💡 ⭐ For legends > help tasks priority heat codes icons" "gray")"
            ;;
    esac
}

# Reassign task to different agent
reassign_task() {
    local task_id="$1"
    local new_agent="$2"
    local reassign_agent="${3:-system}"
    
    # Validate new agent exists
    load_agents
    local agent_found=false
    for agent in "${AGENTS[@]}"; do
        if [[ "$agent" == "$new_agent" ]]; then
            agent_found=true
            break
        fi
    done
    
    if [[ "$agent_found" != "true" ]]; then
        echo "Error: Agent $new_agent not found"
        echo "Available agents: ${AGENTS[*]}"
        return 1
    fi
    
    # Get current task info
    local task_line=$(grep "^$task_id|" "$TASKS_FILE" || true)
    if [[ -z "$task_line" ]]; then
        echo "Error: Task $task_id not found"
        return 1
    fi
    
    # Parse current task data
    local t_id title old_agent state priority parent_task created_date updated_date description
    t_id=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
    title=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    old_agent=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
    state=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')
    priority=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
    parent_task=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')
    created_date=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $7); print $7}')
    updated_date=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $8); print $8}')
    description=$(echo "$task_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $9); print $9}')
    
    # Update task assignment
    local temp_file=$(mktemp)
    local new_updated_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    awk -F'|' -v OFS='|' -v task_id="$task_id" -v new_agent="$new_agent" -v updated_date="$new_updated_date" '
        NR==1 { print; next }
        $1 == task_id { $3 = new_agent; $8 = updated_date; print; next }
        { print }
    ' "$TASKS_FILE" > "$temp_file"
    
    mv "$temp_file" "$TASKS_FILE"
    
    log_activity "REASSIGN: $task_id $old_agent → $new_agent by $reassign_agent"
    
    # Ensure notification directories exist for both agents
    local old_agent_clean="${old_agent#@}"
    local new_agent_clean="${new_agent#@}"
    mkdir -p "$NOTIFICATIONS_DIR/$old_agent_clean" "$NOTIFICATIONS_DIR/$new_agent_clean"
    
    # Notify both agents
    notify_agent "$old_agent" "TASK_REASSIGNED" "Task $task_id reassigned to $new_agent: $title" "HIGH"
    notify_agent "$new_agent" "TASK_ASSIGNED" "New task assigned from $old_agent: $task_id - $title" "$priority"
    
    echo "Task $task_id reassigned: $old_agent → $new_agent"
}

# HR: Add agent
hr_add_agent() {
    local agent="$1"
    local role="${2:-Agent}"
    local description="${3:-Team member}"
    
    # Validate agent format
    if [[ ! "$agent" =~ ^@[A-Z0-9_]+$ ]]; then
        echo "Error: Agent must be format @NAME (e.g., @NEWDEV)"
        return 1
    fi
    
    # Check if agent already exists
    load_agents
    for existing_agent in "${AGENTS[@]}"; do
        if [[ "$existing_agent" == "$agent" ]]; then
            echo "Error: Agent $agent already exists"
            return 1
        fi
    done
    
    # Add agent to manifest
    echo "$agent|$role|$description" >> "$AGENTS_FILE"
    
    # Create notification directory
    mkdir -p "$NOTIFICATIONS_DIR/${agent#@}"
    
    log_activity "HR_ADD_AGENT: $agent ($role) added to team"
    
    echo "✅ Agent $agent added successfully"
    echo "   Role: $role"
    echo "   Description: $description"
    echo "   Notification directory created: $NOTIFICATIONS_DIR/${agent#@}"
}

# HR: Remove agent (reassign tasks to @OXX)
hr_remove_agent() {
    local agent="$1"
    local reassign_to="${2:-@OXX}"
    
    # Validate agent exists
    load_agents
    local agent_found=false
    for existing_agent in "${AGENTS[@]}"; do
        if [[ "$existing_agent" == "$agent" ]]; then
            agent_found=true
            break
        fi
    done
    
    if [[ "$agent_found" != "true" ]]; then
        echo "Error: Agent $agent not found"
        return 1
    fi
    
    # Don't allow removing @OXX (orchestrator)
    if [[ "$agent" == "@OXX" ]]; then
        echo "Error: Cannot remove @OXX (orchestrator). Tasks would have nowhere to go!"
        return 1
    fi
    
    # Find and reassign all tasks for this agent
    local reassigned_count=0
    while IFS='|' read -r task_id title assigned_agent state priority parent_task created_date updated_date description; do
        [[ "$task_id" == "task_id" ]] && continue  # Skip header
        
        if [[ "$assigned_agent" == "$agent" ]]; then
            reassign_task "$task_id" "$reassign_to" "HR_SYSTEM"
            ((reassigned_count++))
        fi
    done < "$TASKS_FILE"
    
    # Remove agent from manifest
    local temp_file=$(mktemp)
    grep -v "^$agent|" "$AGENTS_FILE" > "$temp_file"
    mv "$temp_file" "$AGENTS_FILE"
    
    # Archive notification directory
    if [[ -d "$NOTIFICATIONS_DIR/${agent#@}" ]]; then
        local archive_dir="$NOTIFICATIONS_DIR/REMOVED_${agent#@}_$(date +%Y%m%d_%H%M%S)"
        mv "$NOTIFICATIONS_DIR/${agent#@}" "$archive_dir"
        echo "📁 Notifications archived to: $archive_dir"
    fi
    
    log_activity "HR_REMOVE_AGENT: $agent removed, $reassigned_count tasks reassigned to $reassign_to"
    
    echo "🗑️  Agent $agent removed successfully"
    echo "📋 $reassigned_count task(s) reassigned to $reassign_to"
    echo "💡 Use 'taskdb.sh dashboard $reassign_to' to review reassigned tasks"
}

# HR: List all agents
hr_list_agents() {
    load_agents
    
    echo "════════════════════════════════════════════════════"
    echo "  TEAM ROSTER - AGENT DIRECTORY"
    echo "════════════════════════════════════════════════════"
    echo ""
    printf "%-8s %-12s %-35s %-8s\n" "AGENT" "ROLE" "DESCRIPTION" "TASKS"
    echo "────────────────────────────────────────────────────"
    
    for agent in "${AGENTS[@]}"; do
        local info=$(get_agent_info "$agent")
        local role=$(echo "$info" | cut -d'|' -f1)
        local description=$(echo "$info" | cut -d'|' -f2)
        
        # Count tasks for this agent
        local task_count=$(grep -c "^[^|]*|[^|]*|$agent|" "$TASKS_FILE" 2>/dev/null || echo "0")
        
        printf "%-8s %-12s %-35s %-8s\n" \
               "$agent" \
               "${role:-Unknown}" \
               "${description:-No description}" \
               "$task_count"
    done
    
    echo ""
    echo "💡 Use 'taskdb.sh hr add-agent @NAME ROLE \"Description\"' to add agents"
    echo "🗑️  Use 'taskdb.sh hr rem-agent @NAME' to remove agents (tasks go to @OXX)"
}

# Show all projects using taskdb
show_projects() {
    local registry_file="$GLOBAL_HR_DIR/projects.registry"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "                              TASKDB PROJECT REGISTRY                           "
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ ! -f "$registry_file" ]]; then
        echo "📂 No projects found in registry"
        echo ""
        echo "💡 Projects are automatically registered when taskdb is first used"
        return
    fi
    
    printf "%-25s %-20s %-35s %-8s %-19s\n" \
           "PROJECT ID" "NAME" "PATH" "TASKS" "LAST USED"
    echo "────────────────────────────────────────────────────────────────────────────────"
    
    while IFS='|' read -r project_id project_name project_path created_date; do
        [[ -z "$project_id" ]] && continue
        
        # Count tasks for this project
        local tasks_file="$TASKDB_BASE_DIR/projects/$project_id/tasks.tsv"
        local task_count=0
        if [[ -f "$tasks_file" ]]; then
            task_count=$(tail -n +2 "$tasks_file" 2>/dev/null | wc -l || echo "0")
        fi
        
        # Check if path still exists
        local path_status="✓"
        if [[ ! -d "$project_path" ]]; then
            path_status="❌"
        fi
        
        # Truncate path if too long
        local display_path="$project_path"
        if [[ ${#display_path} -gt 35 ]]; then
            display_path="...${display_path: -32}"
        fi
        
        # Mark current project
        local current_marker=""
        if [[ "$project_id" == "$PROJECT_ID" ]]; then
            current_marker="→ "
        fi
        
        printf "%s%-25s %-20s %-35s %-8s %-19s %s\n" \
               "$current_marker" \
               "$project_id" \
               "$project_name" \
               "$display_path" \
               "$task_count" \
               "$created_date" \
               "$path_status"
    done < "$registry_file"
    
    echo ""
    echo "Current project: $PROJECT_ID ($(pwd))"
    echo ""
    echo "💡 Use 'taskdb.sh' commands from any project directory for isolated task management"
    echo "🗑️  Use 'taskdb.sh projects clean' to remove projects with missing directories"
}

# Clean up projects with missing directories
clean_projects() {
    local registry_file="$GLOBAL_HR_DIR/projects.registry"
    local temp_file=$(mktemp)
    local cleaned_count=0
    
    if [[ ! -f "$registry_file" ]]; then
        echo "📂 No project registry found"
        return
    fi
    
    while IFS='|' read -r project_id project_name project_path created_date; do
        [[ -z "$project_id" ]] && continue
        
        if [[ -d "$project_path" ]]; then
            # Keep projects with existing directories
            echo "$project_id|$project_name|$project_path|$created_date" >> "$temp_file"
        else
            # Archive project data instead of deleting
            local archive_dir="$TASKDB_BASE_DIR/archived/projects/$project_id"
            if [[ -d "$TASKDB_BASE_DIR/projects/$project_id" ]]; then
                mkdir -p "$TASKDB_BASE_DIR/archived/projects"
                mv "$TASKDB_BASE_DIR/projects/$project_id" "$archive_dir" 2>/dev/null || true
                echo "📁 Archived project data: $project_id → $archive_dir"
            fi
            ((cleaned_count++))
        fi
    done < "$registry_file"
    
    mv "$temp_file" "$registry_file"
    
    if [[ $cleaned_count -gt 0 ]]; then
        echo "🧹 Cleaned $cleaned_count project(s) with missing directories"
        echo "📁 Project data archived to $TASKDB_BASE_DIR/archived/projects/"
    else
        echo "✅ All projects have valid directories"
    fi
}

# Show usage
usage() {
    cat << EOF
Task Database System - Agent Coordination Tool

USAGE:
    taskdb.sh COMMAND [ARGS...]

COMMANDS:
    init                           Initialize task database
    create TITLE AGENT [PRIORITY] [PARENT] [DESC]
                                  Create new task
    update TASK_ID STATE [AGENT]  Update task state
    show TASK_ID                  Show task details
    list [AGENT] [STATE]          List all tasks (with optional filters)
    status                        Show comprehensive dependency tree status
    dashboard AGENT               Show agent's work dashboard
    notifications AGENT           Show all notifications with heat indicators
    clear-notifications AGENT     Clear agent's notifications
    resolve AGENT NOTIFICATION_ID Resolve specific notification by ID
    reassign TASK_ID NEW_AGENT    Reassign task to different agent
    next ENTITY                   Preview next ID (task, notif @AGENT)
    broadcast MESSAGE [PRIORITY]  Send notification to all agents
    projects COMMAND              Project management commands  
    hr COMMAND                    HR management commands (add/remove agents)
    states                        Show available task states
    agents                        Show available agents
    training                      Show workflow training and examples
    help TOPIC                    Show help for specific topics (heat)
    
EXAMPLES:
    taskdb.sh create "Implement TTY functions" @LSE HIGH
    taskdb.sh update TASK-001 IN_PROGRESS @LSE
    taskdb.sh reassign TASK-001 @USER
    taskdb.sh next task                           # Shows TASK-007
    taskdb.sh next notif @USER                    # Shows 005
    taskdb.sh broadcast "System maintenance tonight" HIGH
    taskdb.sh dashboard @USER
    taskdb.sh hr add-agent @NEWDEV "Developer" "Junior developer"
    taskdb.sh hr rem-agent @OLDDEV
    taskdb.sh hr list

PROJECT COMMANDS:
    projects list                     Show all projects using taskdb
    projects clean                    Archive projects with missing directories

HR COMMANDS:
    hr add-agent @AGENT [ROLE] [DESC]  Add new team member
    hr rem-agent @AGENT [REASSIGN_TO]  Remove agent (reassign tasks to @OXX)
    hr list                           Show team roster

STATES: ${!TASK_STATES[*]}

PRIORITIES: ${!PRIORITIES[*]}
EOF
}

# Main command dispatch
main() {
    # Parse global flags first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color)
                USE_COLORS=true
                shift
                ;;
            -*)
                echo "Unknown flag: $1"
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    local command="${1:-}"
    [[ $# -gt 0 ]] && shift
    
    case "$command" in
        "init")
            init_taskdb
            ;;
        "create")
            [[ $# -lt 2 ]] && { echo "Usage: create TITLE AGENT [PRIORITY] [PARENT] [DESC]"; exit 1; }
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
        "status")
            show_status_fixed
            ;;
        "dashboard")
            [[ $# -lt 1 ]] && { echo "Usage: dashboard AGENT"; exit 1; }
            agent_dashboard "$1"
            ;;
        "notifications")
            [[ $# -lt 1 ]] && { echo "Usage: notifications AGENT"; exit 1; }
            show_notifications "$1"
            ;;
        "clear-notifications")
            [[ $# -lt 1 ]] && { echo "Usage: clear-notifications AGENT"; exit 1; }
            clear_notifications "$1"
            ;;
        "resolve")
            [[ $# -lt 2 ]] && { echo "Usage: resolve AGENT NOTIFICATION_ID"; exit 1; }
            resolve_notification "$1" "$2"
            ;;
        "next")
            if [[ $# -eq 0 ]]; then
                echo "Usage: next ENTITY"
                echo "  next task          Show next task ID"
                echo "  next notif @AGENT  Show next notification ID for agent"
                exit 1
            elif [[ "$1" == "task" ]]; then
                echo "Next task ID: $(preview_next_id "tasks")"
            elif [[ "$1" == "notif" ]]; then
                [[ $# -lt 2 ]] && { echo "Usage: next notif @AGENT"; exit 1; }
                echo "Next notification ID for $2: $(preview_next_id "notifications" "$2")"
            else
                echo "Unknown entity '$1'. Use 'task' or 'notif @AGENT'"
                exit 1
            fi
            ;;
        "broadcast")
            [[ $# -lt 1 ]] && { echo "Usage: broadcast MESSAGE [PRIORITY]"; exit 1; }
            broadcast_notification "$1" "${2:-NORMAL}"
            ;;
        "states")
            echo "Available task states:"
            for state in "${!TASK_STATES[@]}"; do
                echo "  $state: ${TASK_STATES[$state]}"
            done
            ;;
        "agents")
            load_agents
            echo "Available agents: ${AGENTS[*]}"
            ;;
        "training")
            show_training
            ;;
        "admin")
            local admin_command="${1:-stats}"
            if [[ -n "${1:-}" ]]; then
                shift  # Remove admin subcommand
            fi
            case "$admin_command" in
                "broadcast")
                    local broadcast_action="${1:-help}"
                    if [[ -n "${1:-}" ]]; then
                        shift  # Remove broadcast action
                    fi
                    case "$broadcast_action" in
                        "revoke")
                            admin_revoke_broadcasts "$@"
                            ;;
                        *)
                            echo "Unknown broadcast action: $broadcast_action"
                            echo "Available broadcast actions:"
                            echo "  revoke --confirm  - Clear all broadcast messages"
                            exit 1
                            ;;
                    esac
                    ;;
                "notif"|"notification"|"notifications")
                    local notif_action="${1:-help}"
                    if [[ -n "${1:-}" ]]; then
                        shift  # Remove notification action
                    fi
                    case "$notif_action" in
                        "revoke")
                            admin_revoke_stale_notifications "$@"
                            ;;
                        *)
                            echo "Unknown notification action: $notif_action"
                            echo "Available notification actions:"
                            echo "  revoke --confirm  - Clear COLD/DEAD notifications"
                            exit 1
                            ;;
                    esac
                    ;;
                "stats"|"statistics"|"")
                    admin_show_stats
                    ;;
                "wipe")
                    admin_wipe_project "$@"
                    ;;
                *)
                    echo "Unknown admin command: $admin_command"
                    echo "Available admin commands:"
                    echo "  broadcast revoke --confirm  - Clear all broadcast messages"
                    echo "  notif revoke --confirm      - Clear stale (COLD/DEAD) notifications"  
                    echo "  stats                       - Show system statistics"
                    echo "  wipe --i-am-sure            - 🚨 WIPE ALL project data (DANGEROUS)"
                    exit 1
                    ;;
            esac
            ;;
        "help")
            show_help "${1:-}"
            ;;
        "reassign")
            [[ $# -lt 2 ]] && { echo "Usage: reassign TASK_ID NEW_AGENT [REASSIGNING_AGENT]"; exit 1; }
            reassign_task "$@"
            ;;
        "projects")
            local projects_command="${1:-list}"
            if [[ -n "${1:-}" ]]; then
                shift  # Remove projects subcommand
            fi
            case "$projects_command" in
                "list"|"ls"|"")
                    show_projects
                    ;;
                "clean")
                    clean_projects
                    ;;
                *)
                    echo "Unknown projects command: $projects_command"
                    echo "Available projects commands:"
                    echo "  list  - Show all projects using taskdb"
                    echo "  clean - Remove projects with missing directories"
                    exit 1
                    ;;
            esac
            ;;
        "hr")
            local hr_command="${1:-list}"
            if [[ -n "${1:-}" ]]; then
                shift  # Remove hr subcommand
            fi
            case "$hr_command" in
                "add-agent"|"add")
                    [[ $# -lt 1 ]] && { echo "Usage: hr add-agent @AGENT [ROLE] [DESCRIPTION]"; exit 1; }
                    hr_add_agent "$@"
                    ;;
                "rem-agent"|"remove"|"rem")
                    [[ $# -lt 1 ]] && { echo "Usage: hr rem-agent @AGENT [REASSIGN_TO]"; exit 1; }
                    hr_remove_agent "$@"
                    ;;
                "list"|"ls"|"")
                    hr_list_agents
                    ;;
                *)
                    echo "Unknown HR command: $hr_command"
                    echo "Available HR commands:"
                    echo "  add-agent @AGENT [ROLE] [DESCRIPTION] - Add new agent"
                    echo "  rem-agent @AGENT [REASSIGN_TO]       - Remove agent (reassign tasks)"
                    echo "  list                                 - List all agents"
                    exit 1
                    ;;
            esac
            ;;
        "display-info"|"info"|"display")
            echo "📦 Display System Information:"
            echo "  • Whiptail available: $WHIPTAIL_AVAILABLE"
            echo "  • Display mode: $DISPLAY_MODE"
            echo "  • Whiptail path: $(command -v whiptail 2>/dev/null || echo 'not found')"
            if [ "$WHIPTAIL_AVAILABLE" = true ]; then
                echo "  • Whiptail version: $(whiptail --version 2>&1 | head -1 || echo 'unknown')"
                echo "  • Configuration:"
                echo "    - Default width: $WHIPTAIL_DEFAULT_WIDTH"
                echo "    - Default height: $WHIPTAIL_DEFAULT_HEIGHT" 
                echo "    - Max width: $WHIPTAIL_MAX_WIDTH"
                echo "    - Min width: $WHIPTAIL_MIN_WIDTH"
            fi
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
else
    # Load agents for existing database and ensure project is registered
    mkdir -p "$GLOBAL_HR_DIR"
    load_agents
    
    # Update project registry for existing projects
    registry_file="$GLOBAL_HR_DIR/projects.registry"
    current_path="$(pwd)"
    project_name=$(basename "$current_path")
    
    if [[ ! -f "$registry_file" ]] || ! grep -q "^$PROJECT_ID|" "$registry_file" 2>/dev/null; then
        mkdir -p "$GLOBAL_HR_DIR"
        echo "$PROJECT_ID|$project_name|$current_path|$(date '+%Y-%m-%d %H:%M:%S')" >> "$registry_file"
    fi
fi

# Initialize display system
initialize_display_system

# Run main function
main "$@"