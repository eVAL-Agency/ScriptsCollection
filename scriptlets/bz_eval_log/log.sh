##
# log helper by eval.bz
#
# Facilitates a basic logging system for Bash to print messages to stderr
#
# Using:
#
# Include this file (or however your import system works)
# # scriptlet: bz_eval_log/log.sh
#
# Change logging level
# LOG_LEVEL=3 - Set logging level to DEBUG so all messages are displayed
# LOG_LEVEL=2 - (DEFAULT) - Set logging to info, warnings, and errors
# LOG_LEVEL=1 - Only display warnings and errors
# LOG_LEVEL=0 - Only display errors
#
# Disable coloration
# By default this script renders messages with colors.  Disable this with the following
# LOG_COLORS=0
#
# Logging messages
# log_debug "This is a debug statement"
# log_info "This is an informational statement"
# log_warning "This is a warning message"
# log_error "This is an error message"
#

# Set the verbosity level: 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG
LOG_LEVEL=${LOG_LEVEL:-2}

# Set to '0' to disable ANSI colors
LOG_COLORS=1

# ANSI Color Codes
LOG_RED='\033[0;31m'
LOG_GREEN='\033[0;32m'
LOG_YELLOW='\033[1;33m'
LOG_BLUE='\033[0;34m'
LOG_NC='\033[0m' # No Color

##
# Print a header message
#
# CHANGELOG:
#   2026.04.30 - Initial version
#
function bz_eval_log() {
    local level_name="$1"
    local color
    local message="$2"
    local numeric_level=0

    # Map level names to numbers for comparison
    case "${level_name^^}" in
        "ERROR") numeric_level=0; color="$LOG_RED" ;;
        "WARN")  numeric_level=1; color="$LOG_YELLOW" ;;
        "INFO")  numeric_level=2; color="" ;;
        "DEBUG") numeric_level=3; color="$LOG_BLUE" ;;
    esac

    # Only print if the current log level is high enough
    if [ "$numeric_level" -le "$LOG_LEVEL" ]; then
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        # Print to stderr (&2)
        if [ $LOG_COLORS -eq 1 ] && [ "$color" != "" ]; then
        	printf "${color}[%s] [%s] %s${LOG_NC}\n" "$timestamp" "$level_name" "$message" >&2
		else
        	printf "[%s] [%s] %s\n" "$timestamp" "$level_name" "$message" >&2
        fi
    fi
}

# Helper wrappers for convenience
function log_error()   { bz_eval_log "ERROR" "$1"; }
function log_warning() { bz_eval_log "WARN"  "$1"; }
function log_info()    { bz_eval_log "INFO"  "$1"; }
function log_debug()   { bz_eval_log "DEBUG" "$1"; }
