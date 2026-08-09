#!/usr/bin/env bash
#
# Comprehensive test suite for shesha-desktop
# Tests syntax, help output, dry-run behavior, and functional correctness
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
TEST_RESULTS=()
FAILED=0

log_test() {
    local status="$1"
    local name="$2"
    local detail="${3:-}"
    echo -e "[$status] $name"
    if [[ -n "$detail" ]]; then
        echo "       $detail"
    fi
    if [[ "$status" == "FAIL" ]]; then
        FAILED=$((FAILED + 1))
    fi
}

# =============================================================================
# 1. Syntax validation
# =============================================================================
echo "=== 1. Bash syntax validation ==="
bash_files=$(find "$PROJECT_DIR/tools" "$PROJECT_DIR/sdata" -type f -name '*.sh' 2>/dev/null | sort)
for script in $bash_files; do
    if bash -n "$script" 2>/dev/null; then
        log_test "PASS" "$script"
    else
        log_test "FAIL" "$script" "Syntax error"
    fi
done

# =============================================================================
# 2. Python syntax validation
# =============================================================================
echo ""
echo "=== 2. Python syntax validation ==="
py_files=$(find "$PROJECT_DIR/tools" "$PROJECT_DIR/sdata" -type f -name '*.py' 2>/dev/null | sort)
for pyfile in $py_files; do
    if python3 -m py_compile "$pyfile" 2>/dev/null; then
        log_test "PASS" "$pyfile"
    else
        log_test "FAIL" "$pyfile" "Syntax error"
    fi
done

# =============================================================================
# 3. Help output validation
# =============================================================================
echo ""
echo "=== 3. Help output validation ==="
tools=(
    "tools/smart-organizer/smart-organizer.sh"
    "tools/maintenance/maintenance.sh"
    "tools/backup/backup.sh"
)
for tool in "${tools[@]}"; do
    if bash "$PROJECT_DIR/$tool" --help >/dev/null 2>&1; then
        log_test "PASS" "$tool --help"
    else
        log_test "FAIL" "$tool --help"
    fi
done

if python3 "$PROJECT_DIR/tools/mux-switcher/msi-mux-switcher.py" --help >/dev/null 2>&1; then
    log_test "PASS" "tools/mux-switcher/msi-mux-switcher.py --help"
else
    log_test "FAIL" "tools/mux-switcher/msi-mux-switcher.py --help"
fi

# =============================================================================
# 4. Dry-run safety tests
# =============================================================================
echo ""
echo "=== 4. Dry-run safety tests ==="

# Setup test directory
TEST_DIR="$HOME/.smart-organizer-test-$$"
mkdir -p "$TEST_DIR"
trap 'rm -rf "$TEST_DIR"' EXIT

# Test: dry-run should not modify files
echo "test content" > "$TEST_DIR/report.pdf"
original_hash=$(md5sum "$TEST_DIR/report.pdf" | awk '{print $1}')

cd "$PROJECT_DIR"
bash tools/smart-organizer/smart-organizer.sh --dry-run --once --organize "$TEST_DIR" >/dev/null 2>&1 || true

after_hash=$(md5sum "$TEST_DIR/report.pdf" 2>/dev/null | awk '{print $1}' || echo "FILE_MISSING")
if [[ "$original_hash" == "$after_hash" ]]; then
    log_test "PASS" "Dry-run does not modify files"
else
    log_test "FAIL" "Dry-run does not modify files" "File changed: $original_hash -> $after_hash"
fi

# Test: protected paths should not be touched
mkdir -p "$TEST_DIR/.ssh" "$TEST_DIR/.gnupg" "$TEST_DIR/Workspace"
touch "$TEST_DIR/.ssh/id_rsa" "$TEST_DIR/.gnupg/secret" "$TEST_DIR/Workspace/project"

bash tools/smart-organizer/smart-organizer.sh --dry-run --once --all "$TEST_DIR" >/dev/null 2>&1 || true

if [[ -f "$TEST_DIR/.ssh/id_rsa" ]] && [[ -f "$TEST_DIR/.gnupg/secret" ]] && [[ -f "$TEST_DIR/Workspace/project" ]]; then
    log_test "PASS" "Protected paths are not touched"
else
    log_test "FAIL" "Protected paths are not touched"
fi

# =============================================================================
# 5. Functional tests
# =============================================================================
echo ""
echo "=== 5. Functional tests ==="

# Test: file classification
cd "$PROJECT_DIR"
source tools/smart-organizer/lib/content.sh >/dev/null 2>&1 || true

test_classify() {
    local file="$1"
    local expected="$2"
    local result
    result=$(bash -c "source tools/smart-organizer/lib/content.sh >/dev/null 2>&1 && classify_by_content '$file'" 2>/dev/null || echo "unknown")
    if [[ "$result" == "$expected" ]]; then
        log_test "PASS" "Classify $(basename "$file")" "Got: $result"
    else
        log_test "FAIL" "Classify $(basename "$file")" "Expected: $expected, Got: $result"
    fi
}

# Create test files with content
echo '#!/bin/bash' > "$TEST_DIR/script.sh"
echo 'echo hello' >> "$TEST_DIR/script.sh"
echo '%PDF-1.4' > "$TEST_DIR/doc.pdf"
python3 -c "
import base64
png_b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
with open('$TEST_DIR/image.png', 'wb') as f:
    f.write(base64.b64decode(png_b64))
"

test_classify "$TEST_DIR/script.sh" "code"
test_classify "$TEST_DIR/doc.pdf" "documents"
test_classify "$TEST_DIR/image.png" "images"

# Test: hard-link deduplication
echo "duplicate content" > "$TEST_DIR/file1.txt"
cp "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt"
cp "$TEST_DIR/file1.txt" "$TEST_DIR/file3.txt"
dd if=/dev/zero of="$TEST_DIR/large1.bin" bs=1M count=15 2>/dev/null
cp "$TEST_DIR/large1.bin" "$TEST_DIR/large2.bin"
cp "$TEST_DIR/large1.bin" "$TEST_DIR/large3.bin"

bash tools/smart-organizer/smart-organizer.sh --dry-run --once --dedupe-hardlink "$TEST_DIR" >/dev/null 2>&1 || true

# Check that dry-run showed hard-link actions
output=$(bash tools/smart-organizer/smart-organizer.sh --dry-run --once --dedupe-hardlink "$TEST_DIR" 2>&1 || true)
if echo "$output" | grep -q "Would hard-link"; then
    log_test "PASS" "Hard-link deduplication detects duplicates"
else
    log_test "FAIL" "Hard-link deduplication detects duplicates"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================"
echo " Test Summary"
echo "========================================"
echo ""
echo "Total failures: $FAILED"
if [[ $FAILED -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed. Please review the output above."
    exit 1
fi
