#!/bin/bash
# Setup script for Claude Code Quality Hook

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"

echo "🔧 Setting up Claude Code Quality Hook..."
echo "Script directory: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"

# Make scripts executable
echo "📝 Making scripts executable..."
chmod +x "$SCRIPT_DIR/quality-hook.py"
# incremental_linter.py removed - no longer needed
chmod +x "$SCRIPT_DIR/auto_fix.py" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/claude_code_fixer.py" 2>/dev/null || true

# Create .claude directory if it doesn't exist
CLAUDE_DIR="$PROJECT_ROOT/.claude"
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "📁 Creating .claude directory..."
    mkdir -p "$CLAUDE_DIR"
fi

# Check if settings.json exists
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo "⚠️  Found existing $SETTINGS_FILE"
    echo "   Please manually add the hook configuration:"
    echo ""
    cat << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "SCRIPT_PATH/quality-hook.py"
          }
        ]
      }
    ]
  }
}
EOF
    echo ""
    echo "   Replace SCRIPT_PATH with: $SCRIPT_DIR"
else
    echo "📄 Creating $SETTINGS_FILE..."
    cat > "$SETTINGS_FILE" << EOF
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "$SCRIPT_DIR/quality-hook.py"
          }
        ]
      }
    ]
  }
}
EOF
fi

# Create quality configuration if it doesn't exist
LINTER_CONFIG="$PROJECT_ROOT/.quality-hook.json"
if [ ! -f "$LINTER_CONFIG" ]; then
    echo "📄 Creating $LINTER_CONFIG..."
    cp "$SCRIPT_DIR/.quality-hook.json" "$LINTER_CONFIG" 2>/dev/null || \
    cat > "$LINTER_CONFIG" << 'EOF'
{
  "max_fix_iterations": 3,
  "auto_fix": {
    "enabled": true,
    "threshold": 10,
    "linters": {
      "ruff": true,
      "eslint": true,
      "rustfmt": true,
      "pylint": false
    }
  },
  "claude_code": {
    "enabled": true,
    "batch_mode": true,
    "max_issues_per_request": 5,
    "timeout": 600,
    "max_workers": 10,
    "use_for_complex_issues": true,
    "fallback_when_autofix_fails": true,
    "predict_simple_fixes": true,
    "batch_similar_issues": true,
    "cluster_distance": 5,
    "max_fix_attempts": 3,
    "use_git_worktrees": true,
    "worktree_merge_strategy": "claude",
    "cleanup_worktrees": true,
    "max_worktrees": 10
  },
  "severity_overrides": {
    "no-console": "warning",
    "max-line-length": "warning",
    "missing-docstring": "ignore",
    "F841": "error"
  },
  "logging": {
    "enabled": true,
    "level": "INFO"
  }
}
EOF
else
    echo "ℹ️  Found existing $LINTER_CONFIG"
fi

# Install linters
echo ""
echo "📦 Installing linters..."

# Detect OS
IS_MACOS=false
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
fi

# Install ruff
if command -v ruff &> /dev/null; then
    echo "✓ ruff already installed"
else
    echo "Installing ruff..."
    if $IS_MACOS && command -v brew &> /dev/null; then
        brew install ruff
    else
        pip install ruff
    fi
fi

# Install pyright
if command -v pyright &> /dev/null; then
    echo "✓ pyright already installed"
else
    echo "Installing pyright..."
    npm install -g pyright
fi

# Install eslint
if command -v eslint &> /dev/null; then
    echo "✓ eslint already installed"
else
    echo "Installing eslint..."
    npm install -g eslint
fi

# Install markdownlint
if command -v markdownlint &> /dev/null; then
    echo "✓ markdownlint already installed"
else
    echo "Installing markdownlint..."
    npm install -g markdownlint-cli
fi

# Test the installation
echo ""
echo "🧪 Testing installation..."
# Create a temporary test file
TEST_FILE=$(mktemp "${TMPDIR:-/tmp}/test_XXXXXX.py")
echo "x = 1" > "$TEST_FILE"
TEST_OUTPUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TEST_FILE\"}}" | "$SCRIPT_DIR/quality-hook.py" 2>&1 || true)
rm -f "$TEST_FILE"
if [[ $TEST_OUTPUT == *"passed"* ]] || [[ $TEST_OUTPUT == *"suppressOutput"* ]]; then
    echo "✅ Quality hook is working!"
else
    echo "⚠️  Quality hook test produced unexpected output:"
    echo "$TEST_OUTPUT"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit $LINTER_CONFIG to customize linting rules"
echo "2. Make a test edit with Claude Code to verify the hook works"
echo ""
echo "Example configurations:"
echo "  - Hook settings: $CLAUDE_DIR/settings.json.example"
echo "  - Quality config: $SCRIPT_DIR/.quality-hook.json.example"
echo ""
echo "For more information, see README.md"