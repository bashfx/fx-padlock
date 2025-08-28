# TASKDB PENDING WORK

## 🎨 Color System Extensions (MEDIUM PRIORITY)

### Remaining Color Applications:
- **Task Status Colors**: Apply colors to task states in status/dashboard/list views
- **Priority Colors**: Apply colors to task priorities throughout the system
- **Bold emphasis**: Add bold formatting for CRITICAL/BLAZ items

### Archived Task Filtering (NEW FEATURE):
- **Hide old completed tasks**: PRODUCTION_READY tasks older than 30 days
- **`--all-tasks` flag**: Show archived tasks when explicitly requested
- **Age calculation**: Based on `updated_date` field

## 🐛 Minor Bugs to Fix

### Dashboard Display Issue:
- **Problem**: Dashboard hangs or has display issues with notification section
- **Status**: Core functionality works (notifications, broadcasts, training all work)
- **Impact**: Low priority - workaround is to use `notifications @AGENT` directly

### Current Workaround:
- Use `taskdb.sh notifications @USER` instead of dashboard for notification review
- All other dashboard functionality (tasks, broadcasts) works correctly

## ✅ Recently Completed Features (Reference)

### Color System (COMPLETED ✨):
- **Configurable color mapping** at top of file with purple for COLD
- **`--color` flag support** (no noise without it)
- **`colorize()` helper function** for consistent coloring
- **Heat level colors** applied to notifications (red BLAZ, purple COLD, etc.)

### Help System Enhancements (COMPLETED):
- **`taskdb.sh help heat`** shows heat legend (moved from notifications)
- **Clean notification display** with help reference

### Core Feature Set (STABLE):
- **Counter Orchestrator** with disaster recovery and collision resolution
- **Auto-generated Task IDs** (TASK-007, TASK-008, etc.)
- **Broadcast System** with multi-agent notifications  
- **Training Guide** (`taskdb.sh training`) with workflow documentation
- **Individual Notification Resolution** with heat-based prioritization

## 📋 Implementation Priority:
1. **HIGH**: Color system implementation (user experience enhancement)
2. **MEDIUM**: Archived task filtering with --all-tasks flag
3. **LOW**: Dashboard display bug fix (workaround available)

## 🔧 Technical Notes:
- All core functionality is working and stable
- Counter orchestrator uses proper countx two-step initialization
- Separate file handling for notifications vs broadcasts resolved parsing issues
- taskdb data properly namespaced at `~/.local/share/taskdb/` independent of fx-padlock