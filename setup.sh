#!/bin/bash
#
# Antigravity Optimizer Setup Script (Linux/macOS)
# Version: 1.1.0
#
# Usage:
#   ./setup.sh                    # Interactive setup
#   ./setup.sh --mode essentials  # Non-interactive essentials
#   ./setup.sh --mode update      # Quick skill update
#   ./setup.sh --help             # Show help
#

set -e

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_REPO="https://github.com/sickn33/antigravity-awesome-skills.git"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SKILLS_ROOT="${ANTIGRAVITY_SKILLS_ROOT:-$CODEX_HOME/skills}"
SKILLS_CACHE="$SCRIPT_DIR/.cache/antigravity-awesome-skills"
GEMINI_DIR="$HOME/.gemini"
GLOBAL_RULES_PATH="$GEMINI_DIR/GEMINI.md"
WORKFLOW_DIR="$GEMINI_DIR/antigravity/global_workflows"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Defaults
MODE=""
SILENT=false
SKIP_GLOBAL_ROOT=false

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

show_banner() {
    echo -e "${CYAN}"
    echo "    _    _   _ _____ ___ ____ ____      ___ __     __ ___ _____ __ __"
    echo "   / \\  | \\ | |_   _|_ _/ ___|  _ \\    /   |\\ \\   / /|_ _|_   _|\\ \\ / /"
    echo "  / _ \\ |  \\| | | |  | | |  _| |_) |  / /| | \\ \\ / /  | |  | |   \\ V / "
    echo " / ___ \\| |\\  | | |  | | |_| |  _ <  / ___ |  \\ V /   | |  | |    | |  "
    echo "/_/   \\_\\_| \\_| |_| |___\\____|_| \\_\\/_/  |_|   \\_/   |___| |_|    |_|  "
    echo -e "${NC}"
    echo -e "${GREEN}         >> ANTIGRAVITY OPTIMIZER SETUP v${VERSION} <<${NC}"
    echo "-----------------------------------------------------------"
    echo ""
}

log_step() {
    local type="$1"
    local msg="$2"
    case "$type" in
        success) echo -e "${GREEN}[+]${NC} $msg" ;;
        progress) echo -e "${YELLOW}[*]${NC} $msg" ;;
        warning) echo -e "${YELLOW}[!]${NC} $msg" ;;
        error) echo -e "${RED}[X]${NC} $msg" ;;
        info) echo -e "${GRAY}[i]${NC} $msg" ;;
    esac
}

show_help() {
    echo "Antigravity Optimizer Setup v${VERSION}"
    echo ""
    echo "Usage: ./setup.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --mode <MODE>      Installation mode: essentials, full, update"
    echo "  --silent           Run without prompts (for automation)"
    echo "  --skip-global      Skip global root setup"
    echo "  --help             Show this help"
    echo "  --version          Show version"
    echo ""
    echo "Examples:"
    echo "  ./setup.sh                        # Interactive setup"
    echo "  ./setup.sh --mode essentials      # Quick essentials install"
    echo "  ./setup.sh --mode update --silent # CI/CD update"
    echo ""
}

check_prerequisites() {
    log_step progress "Checking prerequisites..."
    
    if ! command -v git &> /dev/null; then
        log_step error "Git is required but not installed."
        exit 1
    fi
    
    log_step success "Prerequisites OK"
}

# -----------------------------------------------------------------------------
# Core Functions
# -----------------------------------------------------------------------------

install_skills() {
    log_step progress "Installing skills..."
    
    # Clone or update skills cache
    if [ -d "$SKILLS_CACHE/.git" ]; then
        log_step info "Updating skills cache..."
        cd "$SKILLS_CACHE"
        git pull --ff-only 2>/dev/null || log_step warning "Could not update, using existing"
        cd "$SCRIPT_DIR"
    else
        log_step info "Cloning skills repository..."
        mkdir -p "$(dirname "$SKILLS_CACHE")"
        git clone "$SKILLS_REPO" "$SKILLS_CACHE"
    fi
    
    # Copy to Codex home
    mkdir -p "$SKILLS_ROOT"
    
    if [ -d "$SKILLS_CACHE/skills" ]; then
        cp -r "$SKILLS_CACHE/skills/"* "$SKILLS_ROOT/" 2>/dev/null || true
        cp "$SKILLS_CACHE/skills_index.json" "$SKILLS_ROOT/" 2>/dev/null || true
        
        SKILL_COUNT=$(find "$SKILLS_ROOT" -maxdepth 1 -type d | wc -l)
        log_step success "Skills installed to: $SKILLS_ROOT ($SKILL_COUNT skills)"
    fi
    
    # Copy to .agent/skills (for Antigravity IDE)
    AGENT_SKILLS="$SCRIPT_DIR/.agent/skills"
    mkdir -p "$AGENT_SKILLS"
    cp -r "$SKILLS_CACHE/skills" "$AGENT_SKILLS/" 2>/dev/null || true
    cp "$SKILLS_CACHE/skills_index.json" "$AGENT_SKILLS/" 2>/dev/null || true
    log_step success "Skills also installed to: $AGENT_SKILLS"
}

remove_optimizer_git() {
    log_step progress "Removing optimizer's .git folder..."
    echo -e "${GRAY}    (So your project stays pointed to YOUR repo, not ours!)${NC}"
    
    if [ -d "$SCRIPT_DIR/.git" ]; then
        rm -rf "$SCRIPT_DIR/.git"
        log_step success ".git removed - your project's Git is safe!"
    else
        log_step info ".git already removed"
    fi
}

install_workflow() {
    log_step progress "Installing workflow..."
    
    mkdir -p "$WORKFLOW_DIR"
    
    if [ -f "$SCRIPT_DIR/workflows/activate-skills.md" ]; then
        # Copy template as-is (no path replacement needed - template is now dynamic)
        cp "$SCRIPT_DIR/workflows/activate-skills.md" "$WORKFLOW_DIR/activate-skills.md"
        log_step success "Workflow installed: $WORKFLOW_DIR/activate-skills.md"
    fi
}

install_global_rules() {
    RULES_BLOCK='## Activate Skills Router (Preferred)

For non-trivial tasks, prefer routing with the optimizer instead of manual skill loading.

- IDE: /activate-skills <task>
- CLI: @activate-skills "<task>" or activate-skills "<task>"

The router outputs the /skill line + task line. Use that output as-is.
If the router is unavailable, fall back to manual skill loading below.
'

    # Check if already installed
    if [ -f "$GLOBAL_RULES_PATH" ]; then
        if grep -q "Activate Skills Router" "$GLOBAL_RULES_PATH" 2>/dev/null; then
            log_step info "Global rules already contain Activate Skills Router section."
            return
        fi
    fi
    
    # Show user what we want to add
    echo ""
    echo "-----------------------------------------------------------"
    echo -e "${CYAN}GLOBAL RULES UPDATE${NC}"
    echo "-----------------------------------------------------------"
    echo ""
    echo -e "${YELLOW}We'd like to add this to your global AI rules:${NC}"
    echo -e "${GRAY}Location: $GLOBAL_RULES_PATH${NC}"
    echo ""
    echo -e "${CYAN}--- What will be added ---${NC}"
    echo "$RULES_BLOCK"
    echo -e "${CYAN}--------------------------${NC}"
    echo ""
    echo "This teaches AI to use /activate-skills automatically."
    echo ""
    
    if [ "$SILENT" = true ]; then
        response="y"
    else
        read -p "Add to global rules? [Y/n/skip] " response
    fi
    
    case "$response" in
        [sS]*) 
            log_step info "Skipped global rules."
            return
            ;;
        [nN]*) 
            log_step info "Skipped global rules."
            return
            ;;
    esac
    
    # User approved
    mkdir -p "$GEMINI_DIR"
    if [ -f "$GLOBAL_RULES_PATH" ]; then
        echo -e "\n$RULES_BLOCK" >> "$GLOBAL_RULES_PATH"
    else
        echo "$RULES_BLOCK" > "$GLOBAL_RULES_PATH"
    fi
    log_step success "Updated global rules: $GLOBAL_RULES_PATH"
}

cleanup_essentials() {
    log_step progress "Cleaning up for Essentials Mode..."
    
    KEEP_LIST=".agent .cache .gitignore .gitattributes assets scripts tools workflows activate-skills.cmd activate-skills.ps1 activate-skills.sh setup.ps1 setup.sh bundles.json LICENSE README.md"
    
    for item in "$SCRIPT_DIR"/*; do
        name=$(basename "$item")
        if [[ ! " $KEEP_LIST " =~ " $name " ]]; then
            echo -e "${GRAY}    Removing: $name${NC}"
            rm -rf "$item"
        fi
    done
    
    log_step success "Cleanup complete"
}

set_global_optimizer_root() {
    if [ "$SKIP_GLOBAL_ROOT" = true ] || [ "$SILENT" = true ]; then
        log_step info "Skipping global root setup"
        return
    fi
    
    echo ""
    echo -e "${CYAN}Make skills available everywhere?${NC}"
    echo "This stores the repo path so activate-skills works from any folder."
    read -p "Set ANTIGRAVITY_OPTIMIZER_ROOT permanently? [y/N] " response
    
    if [[ "$response" =~ ^[yY]$ ]]; then
        # Add to shell profile
        SHELL_RC="$HOME/.bashrc"
        [ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"
        
        if ! grep -q "ANTIGRAVITY_OPTIMIZER_ROOT" "$SHELL_RC" 2>/dev/null; then
            echo "export ANTIGRAVITY_OPTIMIZER_ROOT=\"$SCRIPT_DIR\"" >> "$SHELL_RC"
            log_step success "Added to $SHELL_RC"
            echo -e "${YELLOW}    Restart terminal to apply.${NC}"
        else
            log_step info "Already in $SHELL_RC"
        fi
    else
        log_step info "Skipped."
    fi
}

show_verification_report() {
    echo ""
    echo "-----------------------------------------------------------"
    echo -e "${CYAN}SKILLS VERIFICATION REPORT${NC}"
    echo "-----------------------------------------------------------"
    
    # Count installed skills
    AGENT_SKILLS_INDEX="$SCRIPT_DIR/.agent/skills/skills_index.json"
    SOURCE_INDEX="$SKILLS_CACHE/skills_index.json"
    
    INSTALLED_COUNT=0
    SOURCE_COUNT=0
    
    # Get installed count
    if [ -f "$AGENT_SKILLS_INDEX" ]; then
        INSTALLED_COUNT=$(python3 -c "import json; print(len(json.load(open('$AGENT_SKILLS_INDEX'))))" 2>/dev/null || echo "0")
    fi
    
    # Get source count
    if [ -f "$SOURCE_INDEX" ]; then
        SOURCE_COUNT=$(python3 -c "import json; print(len(json.load(open('$SOURCE_INDEX'))))" 2>/dev/null || echo "0")
    fi
    
    echo ""
    echo "  Source repo (sickn33):    $SOURCE_COUNT skills"
    echo "  Installed locally:        $INSTALLED_COUNT skills"
    
    if [ "$INSTALLED_COUNT" -eq "$SOURCE_COUNT" ] && [ "$INSTALLED_COUNT" -gt 0 ]; then
        echo ""
        echo -e "  Status: ${GREEN}SYNCED${NC} - You have all available skills!"
    elif [ "$INSTALLED_COUNT" -lt "$SOURCE_COUNT" ]; then
        MISSING=$((SOURCE_COUNT - INSTALLED_COUNT))
        echo ""
        echo -e "  Status: ${YELLOW}PARTIAL${NC} - Missing $MISSING skills. Run setup again."
    elif [ "$INSTALLED_COUNT" -eq 0 ]; then
        echo ""
        echo -e "  Status: ${RED}NOT INSTALLED${NC} - Run ./setup.sh to install skills."
    else
        echo ""
        echo -e "  Status: ${GREEN}OK${NC}"
    fi
    
    echo ""
    echo -e "${GRAY}  Tip: Run './activate-skills.sh --verify' for detailed check${NC}"
    echo "-----------------------------------------------------------"
}

show_completion() {
    echo ""
    echo "-----------------------------------------------------------"
    log_step success "Setup Complete!"
    echo ""
    echo -e "${YELLOW}CREDITS:${NC}"
    echo "Skills powered by @sickn33's Antigravity Awesome Skills."
    echo -e "${CYAN}https://github.com/sickn33/antigravity-awesome-skills${NC}"
    echo ""
    echo -e "${GREEN}Try: ./activate-skills.sh \"Build a web app\"${NC}"
    echo ""
}

show_menu() {
    echo "Welcome to the Antigravity Optimizer."
    echo "This script installs skills and sets up Antigravity workflows."
    echo ""
    echo -e "${CYAN}Select Mode:${NC}"
    echo -e "${GREEN}  [1] Essentials Only (Recommended)${NC}"
    echo "      - Installs skills & tools, removes extra files"
    echo ""
    echo -e "${YELLOW}  [2] Full Repository${NC}"
    echo "      - Keeps all documentation and assets"
    echo ""
    echo -e "${CYAN}  [3] Update Skills Only${NC}"
    echo "      - Just check for and install skill updates (quick)"
    echo ""
    
    read -p "Enter selection [1/2/3]: " selection
    echo "$selection"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --silent)
            SILENT=true
            shift
            ;;
        --skip-global)
            SKIP_GLOBAL_ROOT=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        --version)
            echo "Antigravity Optimizer v${VERSION}"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run
show_banner
check_prerequisites

# Determine mode
if [ -z "$MODE" ]; then
    if [ "$SILENT" = true ]; then
        MODE="essentials"
        log_step info "Silent mode: defaulting to 'essentials'"
    else
        selection=$(show_menu)
        case "$selection" in
            1) MODE="essentials" ;;
            2) MODE="full" ;;
            3) MODE="update" ;;
            *) MODE="essentials" ;;
        esac
    fi
fi

echo ""
log_step success "Selected: ${MODE^^}"

case "$MODE" in
    essentials)
        if [ "$SILENT" != true ]; then
            read -p "This will DELETE non-essential files. Continue? [y/N] " confirm
            if [[ ! "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${RED}Aborted.${NC}"
                exit 0
            fi
        fi
        install_skills
        remove_optimizer_git
        install_workflow
        install_global_rules
        set_global_optimizer_root
        cleanup_essentials
        show_verification_report
        ;;
    full)
        install_skills
        remove_optimizer_git
        install_workflow
        install_global_rules
        set_global_optimizer_root
        show_verification_report
        ;;
    update)
        install_skills
        show_verification_report
        show_completion
        exit 0
        ;;
esac

show_completion
