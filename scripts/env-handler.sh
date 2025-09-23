#!/usr/bin/env bash

# Generate .env file from 1Password template
# Usage: ./scripts/env-handler.sh
#
# This script reads a 1Password template file and generates a .env file
# by resolving 1Password references (op://) to actual values.

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Secure Internal Field Separator

# Script metadata
readonly SCRIPT_NAME="${0##*/}"

# Determine script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_DIR

# File paths
readonly TEMPLATE_FILE="${PROJECT_DIR}/config/env.1password.template"
readonly ENV_FILE="${PROJECT_DIR}/config/.env"
readonly BACKUP_FILE="${PROJECT_DIR}/config/.env.backup"
readonly TEMP_FILE="${PROJECT_DIR}/config/.env.tmp.$$"

# ANSI color codes
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# Global variables
declare -a REQUIRED_VARS=("LINEAR_API_TOKEN")
declare -a CONDITIONAL_VARS=()
declare -a MISSING_VARS=()

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
    fi
    exit $exit_code
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Logging functions
print_status() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1" >&2
}

print_warning() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# Usage function
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Generate .env file from 1Password template.

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    --dry-run       Show what would be done without making changes

REQUIREMENTS:
    - 1Password CLI installed and signed in
    - Template file: ${TEMPLATE_FILE}

EXAMPLES:
    $SCRIPT_NAME                    # Generate .env file
    $SCRIPT_NAME --dry-run          # Preview changes
    $SCRIPT_NAME --verbose          # Verbose output

EOF
}

# Command line argument parsing
parse_arguments() {
    local verbose=0
    local dry_run=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                verbose=1
                shift
                ;;
            --dry-run)
                dry_run=1
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Export for use in other functions
    export VERBOSE=$verbose
    export DRY_RUN=$dry_run
}

# Validation functions
validate_op_cli_installed() {
    if ! command -v op >/dev/null 2>&1; then
        print_error "1Password CLI is not installed. Please install it first:"
        printf "  %s\n" "brew install --cask 1password/tap/1password-cli"
        exit 1
    fi
    
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        print_status "✓ 1Password CLI found: $(command -v op)"
    fi
}

validate_op_signed_in() {
    if ! op account list >/dev/null 2>&1; then
        print_error "Not signed in to 1Password. Please sign in first:"
        printf "  %s\n" "op signin"
        exit 1
    fi
    
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        print_status "✓ Signed in to 1Password"
    fi
}

validate_template_exists() {
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        print_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        print_status "✓ Template file found: $TEMPLATE_FILE"
    fi
}

validate_prerequisites() {
    print_status "Validating prerequisites..."
    validate_op_cli_installed
    validate_op_signed_in
    validate_template_exists
}

# Backup function
backup_existing_env() {
    if [[ -f "$ENV_FILE" ]]; then
        if [[ "${DRY_RUN:-0}" == "1" ]]; then
            print_status "[DRY RUN] Would backup existing .env file to .env.backup"
        else
            cp "$ENV_FILE" "$BACKUP_FILE"
            print_warning "Existing .env file backed up to .env.backup"
        fi
    fi
}

# Check if line is a comment or empty
is_comment_or_empty() {
    local line="$1"
    # Remove leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]
}

# Check if line contains 1Password reference
is_onepassword_reference() {
    local line="$1"
    [[ "$line" =~ op://([^/]+)/([^/]+)/([^[:space:]]+) ]]
}

# Extract 1Password reference components
extract_op_reference() {
    local line="$1"
    if [[ "$line" =~ op://([^/]+)/([^/]+)/([^[:space:]]+) ]]; then
        local vault="${BASH_REMATCH[1]}"
        local item="${BASH_REMATCH[2]}"
        local field="${BASH_REMATCH[3]}"
        printf "%s|%s|%s" "$vault" "$item" "$field"
        return 0
    fi
    return 1
}

# Fetch value from 1Password
fetch_from_onepassword() {
    local item="$1"
    local vault="$2"
    local field="$3"
    
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        print_status "Fetching ${field} from ${item} in ${vault} vault..."
    fi
    
    local value
    if value=$(op item get "$item" --vault "$vault" --field "$field" --reveal 2>/dev/null); then
        printf "%s" "$value"
        return 0
    else
        return 1
    fi
}

# Process a single line from the template
process_template_line() {
    local line="$1"
    local temp_file="$2"
    
    # Handle comments and empty lines
    if is_comment_or_empty "$line"; then
        printf "%s\n" "$line" >> "$temp_file"
        return 0
    fi
    
    # Handle 1Password references
    if is_onepassword_reference "$line"; then
        local var_name="${line%%=*}"
        local op_reference
        
        if op_reference=$(extract_op_reference "$line"); then
            IFS='|' read -r vault item field <<< "$op_reference"
            
            print_status "Resolving $var_name from 1Password..."
            
            local value
            if value=$(fetch_from_onepassword "$item" "$vault" "$field"); then
                printf "%s=%s\n" "$var_name" "$value" >> "$temp_file"
                print_status "✓ Successfully resolved $var_name"
            else
                local original_ref="${line#*=}"
                printf "%s=# FAILED_TO_RESOLVE: %s\n" "$var_name" "$original_ref" >> "$temp_file"
                print_warning "Failed to resolve $var_name from 1Password. Adding placeholder..."
            fi
        else
            printf "%s\n" "$line" >> "$temp_file"
        fi
    else
        # Regular environment variable line
        printf "%s\n" "$line" >> "$temp_file"
    fi
}

# Generate the .env file
generate_env_file() {
    print_status "Generating .env file from 1Password template..."
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_status "[DRY RUN] Would process template and generate .env file"
        return 0
    fi
    
    # Create temporary file
    : > "$TEMP_FILE"
    
    # Process each line in the template
    while IFS= read -r line || [[ -n "$line" ]]; do
        process_template_line "$line" "$TEMP_FILE"
    done < "$TEMPLATE_FILE"
    
    # Move temp file to final location
    mv "$TEMP_FILE" "$ENV_FILE"
    
    print_status "✓ .env file generated successfully!"
}

# Determine conditional variables based on .env content
determine_conditional_vars() {
    if [[ ! -f "$ENV_FILE" ]]; then
        return 0
    fi
    
    local env_content
    env_content=$(cat "$ENV_FILE")
    
    # Check for API provider
    if echo "$env_content" | grep -q "^API_PROVIDER=anthropic"; then
        CONDITIONAL_VARS+=("ANTHROPIC_API_KEY")
    elif echo "$env_content" | grep -q "^API_PROVIDER=dust"; then
        CONDITIONAL_VARS+=("DUST_API_KEY" "DUST_WORKSPACE_ID" "DUST_AGENT_ID")
    fi
    
    # Check for GitHub repository
    if echo "$env_content" | grep -q "^GITHUB_REPOSITORY=.\\+" && 
       ! echo "$env_content" | grep -q "^GITHUB_REPOSITORY=\\s*$"; then
        CONDITIONAL_VARS+=("GITHUB_TOKEN")
    fi
}

# Check for missing variables
check_missing_variables() {
    local -a vars_to_check=("${REQUIRED_VARS[@]}")
    if [[ ${#CONDITIONAL_VARS[@]} -gt 0 ]]; then
        vars_to_check+=("${CONDITIONAL_VARS[@]}")
    fi
    
    if [[ ! -f "$ENV_FILE" ]]; then
        MISSING_VARS=("${vars_to_check[@]}")
        return 0
    fi
    
    local env_content
    env_content=$(cat "$ENV_FILE")
    
    for var in "${vars_to_check[@]}"; do
        if ! echo "$env_content" | grep -q "^${var}=.\\+" || 
           echo "$env_content" | grep -q "^${var}=.*FAILED_TO_RESOLVE"; then
            MISSING_VARS+=("$var")
        fi
    done
}

# Validate the generated .env file
validate_env_file() {
    print_status "Validating .env file..."
    
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        print_status "[DRY RUN] Would validate .env file"
        return 0
    fi
    
    determine_conditional_vars
    check_missing_variables
    
    if [[ ${#MISSING_VARS[@]} -eq 0 ]]; then
        print_status "✓ All required variables are present"
    else
        print_error "Missing or failed to resolve required variables:"
        printf "  - %s\n" "${MISSING_VARS[@]}"
        printf "\n"
        printf "Please check your 1Password vault and ensure the items exist with correct field names.\n"
        exit 1
    fi
}

# Print success message
print_success_message() {
    printf "\n"
    printf "📋 Summary:\n"
    printf "  Template: %s\n" "$(basename "$TEMPLATE_FILE")"
    printf "  Output:   %s\n" "$(basename "$ENV_FILE")"
    if [[ -f "$BACKUP_FILE" ]]; then
        printf "  Backup:   %s\n" "$(basename "$BACKUP_FILE")"
    fi
    printf "\n"
    print_status "🚀 Ready to use! You can now run your application:"
    printf "  ./bin/kanban_metrics\n"
    printf "  bundle exec rspec\n"
}

# Main function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    print_status "Starting .env generation from 1Password template..."
    
    # Run the main workflow
    validate_prerequisites
    backup_existing_env
    generate_env_file
    validate_env_file
    
    if [[ "${DRY_RUN:-0}" == "0" ]]; then
        print_success_message
    else
        print_status "[DRY RUN] Completed successfully - no changes made"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi