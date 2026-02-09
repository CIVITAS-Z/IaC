#!/bin/bash
# 2026-02-06T12:15:00+08:00 check_php_session.sh
#
# [基本信息/Basic Information]
# 程序描述: PHP 会话超时检测与配置工具 (CLI)。
# PHP Session Timeout Auditor & Configurator following Enterprise SSH Output Standards.
# 模型名称: Gemini-2.5-Flash
# 文件名称: check_php_session.sh
# 版本信息: v1.1.0 (Config Modification Support)
# 北京时间: 2026-02-06T12:15:00+08:00
# 代码类型: Bash Shell Script
#
# [修改摘要/Modification Summary]
# - 新增功能: 支持传入可选参数 $1 (单位: 小时)。
# - 逻辑增强: 若传入参数，脚本将自动计算秒数并修改 php.ini 配置。
# - 安全特性: 修改配置前自动创建 .bak 备份文件。
# - 样式维护: 保持 SSH Enterprise 结构化输出及天蓝色时间戳。
#
# [程序概述/Program Overview]
# 本脚本用于审计或修改 PHP 环境的 Session 超时设置。
# 不带参数运行：仅执行审计并显示当前配置。
# 带参数运行（例如 ./script.sh 1）：将超时时间修改为 1 小时，并显示修改后的结果。

# ==============================================================================
# Configuration: ANSI Colors
# ==============================================================================
C_RESET='\033[0m'
C_GREY='\033[1;30m'
C_CYAN_B='\033[1;36m' # Sky Blue
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_GREEN_B='\033[1;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'

# Map "Sky Blue" to Cyan Bold for high visibility
C_SKYBLUE="$C_CYAN_B"

# Timestamp function
get_ts() {
    date "+%H:%M:%S"
}

# ==============================================================================
# Helper: Print Structured Blocks
# ==============================================================================
print_section_header() {
    local title="$1"
    echo -e "${C_CYAN_B}┌────┐ $title └────┘${C_RESET}"
}

print_kv() {
    local key="$1"
    local val="$2"
    printf "${C_SKYBLUE}%s${C_RESET} ├─ %-20s ${C_CYAN}%s${C_RESET}\n" "$(get_ts)" "$key" "$val"
}

print_log() {
    local level="$1"
    local msg="$2"
    local icon=""
    local color=""
    case "$level" in
        "SUCCESS") icon="✓"; color="$C_GREEN" ;;
        "ERROR")   icon="✗"; color="$C_RED" ;;
        "WARNING") icon="!"; color="$C_YELLOW" ;;
        "INFO")    icon="ℹ"; color="$C_CYAN" ;;
        *)         icon="?"; color="$C_RESET" ;;
    esac
    printf "${C_SKYBLUE}%s${C_RESET} [%s%s${C_RESET}] %s\n" "$(get_ts)" "$color" "$icon" "$msg"
}

print_banner() {
    local status="$1"
    echo ""
    if [ "$status" == "SUCCESS" ]; then
        echo -e "${C_GREEN_B}ALL OPERATIONS COMPLETED SUCCESSFULLY.${C_RESET}"
    else
        echo -e "${C_RED}OPERATIONS COMPLETED WITH ERRORS. Check logs above.${C_RESET}"
    fi
    echo ""
}

# ==============================================================================
# Main Logic
# ==============================================================================

# 1. System Check
if ! command -v php &> /dev/null; then
    print_section_header "SYSTEM CHECK"
    print_log "ERROR" "PHP binary not found in \$PATH"
    print_banner "FAIL"
    exit 1
fi

# 2. Pre-Check: Identify Config File
# We need to know where the file is BEFORE we try to modify it
LOADED_INI=$(php -r 'echo php_ini_loaded_file() ?: "None";')
FINAL_STATUS="SUCCESS"

# ==============================================================================
# Feature: Update Configuration (If Argument Provided)
# ==============================================================================
if [ ! -z "$1" ]; then
    print_section_header "CONFIGURATION UPDATE"
    
    TARGET_HOURS="$1"
    
    # Validation: Check if input is a number (integer or float)
    if [[ ! "$TARGET_HOURS" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        print_log "ERROR" "Invalid time format: $TARGET_HOURS (Expected hours, e.g., 1 or 0.5)"
        FINAL_STATUS="FAIL"
    elif [ "$LOADED_INI" == "None" ]; then
        print_log "ERROR" "Cannot modify config: No loaded php.ini found"
        FINAL_STATUS="FAIL"
    elif [ ! -w "$LOADED_INI" ]; then
        print_log "ERROR" "Permission denied: Cannot write to $LOADED_INI"
        print_log "INFO" "Try running with sudo"
        FINAL_STATUS="FAIL"
    else
        # Calculation: Hours * 3600
        # Use awk for float support, print integer part
        TARGET_SECONDS=$(awk "BEGIN {print int($TARGET_HOURS * 3600)}")
        
        print_kv "INPUT_HOURS" "$TARGET_HOURS"
        print_kv "TARGET_SECONDS" "$TARGET_SECONDS"
        print_kv "TARGET_FILE" "$LOADED_INI"

        # Backup
        cp "$LOADED_INI" "${LOADED_INI}.bak"
        if [ $? -eq 0 ]; then
            print_log "SUCCESS" "Backup created: ${LOADED_INI}.bak"
            
            # Modification using sed
            # Regex explanation:
            # ^;{0,1}  : Start of line, optional semicolon (uncomment if commented)
            # \s* : Optional whitespace
            # session.gc_maxlifetime : Key
            # \s*=\s* : Equals sign with optional whitespace
            # .* : Current value
            
            sed -i "s/^;\{0,1\}\s*session.gc_maxlifetime\s*=.*/session.gc_maxlifetime = ${TARGET_SECONDS}/" "$LOADED_INI"
            
            if [ $? -eq 0 ]; then
                print_log "SUCCESS" "Configuration updated successfully"
            else
                print_log "ERROR" "sed command failed"
                FINAL_STATUS="FAIL"
            fi
        else
            print_log "ERROR" "Failed to create backup"
            FINAL_STATUS="FAIL"
        fi
    fi
    echo ""
fi

# ==============================================================================
# Audit / Verification Logic (Runs always)
# ==============================================================================

print_section_header "PHP SESSION AUDIT"

# Re-extract values (in case they changed)
PHP_FULL_VER=$(php -r 'echo PHP_VERSION;')
PHP_MAJOR_MINOR=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
LOADED_INI=$(php -r 'echo php_ini_loaded_file() ?: "None";')
# Get value directly from INI to confirm persistence
SESSION_LIFETIME=$(php -r 'echo ini_get("session.gc_maxlifetime");')

print_kv "OS_DISTRO" "Debian (Detected)"
print_kv "PHP_VERSION" "$PHP_FULL_VER"
print_kv "PHP_MAJOR_MINOR" "$PHP_MAJOR_MINOR"
print_kv "CONFIG_TYPE" "CLI / SSH Session"

echo "" 
print_section_header "CONFIGURATION PATHS"

if [ "$LOADED_INI" == "None" ]; then
    print_log "ERROR" "No php.ini file is loaded"
    FINAL_STATUS="FAIL"
else
    print_kv "LOADED_INI_PATH" "$LOADED_INI"
    
    SCANNED_DIR=$(php -r 'echo php_ini_scanned_dir() ?: "None";')
    if [ "$SCANNED_DIR" != "None" ]; then
        print_kv "SCANNED_INI_DIR" "$SCANNED_DIR"
    fi
    
    if [ ! -z "$1" ] && [ "$FINAL_STATUS" == "SUCCESS" ]; then
         print_log "SUCCESS" "Verified: Configuration loaded"
    else
         print_log "SUCCESS" "Configuration file located"
    fi
fi

echo ""
print_section_header "SESSION PARAMETERS"

if [[ "$SESSION_LIFETIME" =~ ^[0-9]+$ ]]; then
    # Calculate display values
    MINUTES=$((SESSION_LIFETIME / 60))
    HOURS=$(awk "BEGIN {printf \"%.2f\", $SESSION_LIFETIME / 3600}")
    
    print_kv "GC_MAXLIFETIME" "${SESSION_LIFETIME}s"
    print_kv "READABLE_TIME" "${MINUTES}m / ${HOURS}h"
    
    if [ ! -z "$1" ] && [ "$SESSION_LIFETIME" -eq "$TARGET_SECONDS" ]; then
        print_log "SUCCESS" "Value matches requested update"
    else
        print_log "SUCCESS" "Session timeout value extracted"
    fi
else
    print_kv "GC_MAXLIFETIME" "Unknown/Empty"
    print_log "ERROR" "Failed to retrieve session value"
    FINAL_STATUS="FAIL"
fi

# ==============================================================================
# Summary Table (ASCII Format)
# ==============================================================================
echo ""
echo -e "${C_SKYBLUE}┌──────────────────────┬──────────────────────┬──────────────────────┐${C_RESET}"
printf "${C_SKYBLUE}│${C_RESET} %-20s ${C_SKYBLUE}│${C_RESET} %-20s ${C_SKYBLUE}│${C_RESET} %-20s ${C_SKYBLUE}│${C_RESET}\n" "PHP_VERSION" "CONFIG_SOURCE" "TIMEOUT_SEC"
echo -e "${C_SKYBLUE}├──────────────────────┼──────────────────────┼──────────────────────┤${C_RESET}"
printf "${C_SKYBLUE}│${C_RESET} ${C_CYAN}%-20s${C_RESET} ${C_SKYBLUE}│${C_RESET} %-20s ${C_SKYBLUE}│${C_RESET} %-20s ${C_SKYBLUE}│${C_RESET}\n" "$PHP_MAJOR_MINOR" "php.ini (CLI)" "$SESSION_LIFETIME"
echo -e "${C_SKYBLUE}└──────────────────────┴──────────────────────┴──────────────────────┘${C_RESET}"

# Final Banner
print_banner "$FINAL_STATUS"
