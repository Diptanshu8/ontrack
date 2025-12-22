#!/bin/bash

# Unified Test Runner for OnTrack iOS UI tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_PROJECT_DIR="/Users/djamgade/personal/ontrack/ontrack/OnTrack-iOS/OnTrack"
PROJECT_FILE="$IOS_PROJECT_DIR/OnTrack.xcodeproj"
SCHEME_NAME="OnTrack"
SIMULATOR_NAME="iPhone 17"
UITESTS_DIR="$IOS_PROJECT_DIR/OnTrackUITests/Flows"
COVERAGE_FILE="/Users/djamgade/personal/ontrack/ontrack/OnTrack-iOS/COVERAGE_SUMMARY.txt"
SERVER_COMMAND="$SCRIPT_DIR/test_server.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${BLUE}▶${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

usage() {
    cat <<EOF

======================================
🧪 OnTrack iOS Unified Test Runner
======================================

Usage: $(basename "$0") [options] [tests...]

Tests arguments:
  - Provide zero arguments to run the entire UI test suite.
  - Provide a single test identifier (e.g. "LoginTest/testLogout").
  - Provide multiple tests separated by commas or spaces.
  - Identifiers can omit the "OnTrackUITests/" prefix.

Options:
  --list               List available test classes and methods
  --isolated           Run tests in isolated mode (each test boots a fresh simulator)
  --serial             Disable Xcode parallel testing
  --verbose            Show full xcodebuild output instead of filtered logs
  --coverage           Enable code coverage (only valid when running full test suite)
  --suite              Explicitly run the entire test suite (alias for no test arguments)
  --tests <list>       Comma or space separated list of tests (same as positional tests)
  --help               Show this help message

Examples:
  $(basename "$0") --list
  $(basename "$0") LoginTest/testLogout
  $(basename "$0") --tests LoginTest,NavigationTest/testNavigateToDashboard
  $(basename "$0") --suite --isolated
  $(basename "$0") --suite --coverage

EOF
}

ensure_commands() {
    local missing=0
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warn "Required command '$cmd' not found"
            missing=1
        fi
    done
    if [ "$missing" -ne 0 ]; then
        error "Missing required dependencies"
        exit 1
    fi
}

list_tests() {
    if [ ! -d "$UITESTS_DIR" ]; then
        error "UI test directory not found: $UITESTS_DIR"
        exit 1
    fi

    echo ""
    echo "======================================"
    echo "📋 Available UI Tests"
    echo "======================================"
    echo ""

    local test_files
    # shellcheck disable=SC2038
    test_files=$(find "$UITESTS_DIR" -name "*Test*.swift" -type f | sort)
    if [ -z "$test_files" ]; then
        warn "No tests discovered under $UITESTS_DIR"
        return
    fi

    echo "Test Classes:"
    while IFS= read -r file; do
        local class_name
        class_name="$(basename "$file" .swift)"
        echo "  • $class_name"
    done <<< "$test_files"

    echo ""
    echo "Test Methods:"
    echo ""

    while IFS= read -r file; do
        local class_name
        class_name="$(basename "$file" .swift)"
        local methods
        methods=$(grep -E "^\s*func test[A-Za-z0-9_]+\(\)" "$file" | sed -E 's/.*func (test[A-Za-z0-9_]+).*/\1/' | sort)
        if [ -n "$methods" ]; then
            echo "$class_name:"
            while IFS= read -r method; do
                echo "  • $class_name/$method"
            done <<< "$methods"
            echo ""
        fi
    done <<< "$test_files"

    echo "======================================"
}

ensure_server_running() {
    if lsof -i :3001 -t >/dev/null 2>&1; then
        return 0
    fi
    error "Test server not running on port 3001"
    echo ""
    info "Start the server first: $SERVER_COMMAND start"
    exit 1
}

normalize_identifier() {
    local raw="$1"
    raw="${raw//[[:space:]]/}"
    raw="${raw#OnTrackUITests/}"
    raw="${raw#,}"
    echo "$raw"
}

split_tests_argument() {
    local input="$1"
    local IFS=','
    read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        if [ -n "$part" ]; then
            NORMALIZED_TESTS+=("$(normalize_identifier "$part")")
        fi
    done
}

collect_all_test_classes() {
    if [ ! -d "$UITESTS_DIR" ]; then
        return
    fi
    # shellcheck disable=SC2038
    while IFS= read -r file; do
        local class_name
        class_name="$(basename "$file" .swift)"
        NORMALIZED_TESTS+=("$class_name")
    done < <(find "$UITESTS_DIR" -name "*Test*.swift" -type f | sort)
}

build_for_testing() {
    log "Building UI test target..."
    cd "$IOS_PROJECT_DIR"
    xcodebuild build-for-testing \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
        > /tmp/xcode_build.log 2>&1
    success "Build succeeded"
}

boot_simulator() {
    log "Ensuring simulator '$SIMULATOR_NAME' is booted..."
    local sim_id
    sim_id=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -v "unavailable" | head -1 | grep -o '[A-F0-9-]\{36\}' || true)
    if [ -z "$sim_id" ]; then
        error "Simulator $SIMULATOR_NAME not found"
        exit 1
    fi
    xcrun simctl boot "$sim_id" 2>/dev/null || true
    sleep 2
    open -a Simulator >/dev/null 2>&1 || true
    success "Simulator ready"
}

generate_xcodebuild_cmd() {
    local action="$1"
    shift
    local parallel_flag=()
    if [ "$SERIAL_MODE" = true ]; then
        parallel_flag=(-parallel-testing-enabled NO)
    else
        parallel_flag=(-parallel-testing-enabled YES)
    fi
    local extra=("$@")
    echo "xcodebuild $action -project \"$PROJECT_FILE\" -scheme \"$SCHEME_NAME\" -destination \"platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest\" ${parallel_flag[*]:-} ${extra[*]:-}"
}

run_xcodebuild() {
    local action="$1"
    shift
    local filtered_output="$1"
    shift
    local log_file="$1"
    shift
    local cmd
    cmd=$(generate_xcodebuild_cmd "$action" "$@")

    if [ "$VERBOSE_MODE" = true ]; then
        eval "$cmd" 2>&1 | tee "$log_file"
        return "${PIPESTATUS[0]}"
    fi

    # Capture xcodebuild exit code while allowing pipe to grep
    set +e
    eval "$cmd" 2>&1 | tee "$log_file" | grep --line-buffered -E "$filtered_output"
    local exit_code=${PIPESTATUS[0]}
    set -e
    return $exit_code
}

update_coverage_summary() {
    local xcresult_bundle="$1"
    local log_file="$2"

    if ! command -v xcrun >/dev/null 2>&1; then
        warn "xcrun not available; skipping coverage summary update"
        return
    fi

    local report_json
    report_json="$(mktemp /tmp/ontrack_coverage_report_json.XXXXXX)"
    if ! xcrun xccov view --report --json "$xcresult_bundle" > "$report_json" 2>/dev/null; then
        warn "Failed to generate xccov report; skipping coverage summary update"
        rm -f "$report_json"
        return
    fi
    
    # Save JSON report to workspace for HTML exploration
    cp "$report_json" "$SCRIPT_DIR/coverage.json"
    success "Saved coverage JSON to $SCRIPT_DIR/coverage.json"

    local tests_json
    tests_json="$(mktemp /tmp/ontrack_tests_report_json.XXXXXX)"
    if ! xcrun xcresulttool get --path "$xcresult_bundle" --format json --legacy > "$tests_json"; then
        warn "Failed to fetch xcresult metadata; tests summary will be limited"
        rm -f "$tests_json"
        tests_json=""
    fi

    python3 - "$COVERAGE_FILE" "$report_json" "${tests_json:-}" "$log_file" <<'PYCODE'
import json
import datetime
import pathlib
import sys

coverage_path = pathlib.Path(sys.argv[1])
report_path = pathlib.Path(sys.argv[2])
tests_path = pathlib.Path(sys.argv[3]) if sys.argv[3] else None
log_path = pathlib.Path(sys.argv[4])

now = datetime.datetime.now().strftime("%B %d, %Y %H:%M:%S")

def safe_percent(value):
    return f"{value * 100:.2f}%"

def safe_int(value):
    return f"{int(round(value))}"

try:
    report_data = json.loads(report_path.read_text())
except Exception as exc:  # noqa: BLE001
    print(f"Failed to parse coverage report: {exc}", file=sys.stderr)
    sys.exit(0)

targets = report_data.get("targets", [])
target_rows = []
total_lines = 0
covered_lines = 0

for target in targets:
    name = target.get("name", "Unknown")
    coverage = target.get("lineCoverage", 0.0)
    covered = target.get("coveredLines", 0)
    executable = target.get("executableLines", 0)
    total_lines += executable
    covered_lines += covered
    target_rows.append((name, coverage, covered, executable))

tests_executed = "Unavailable"
tests_failed = "Unavailable"
tests_pass_rate = "Unavailable"
test_duration = "Unavailable"

if tests_path and tests_path.exists():
    try:
        root = json.loads(tests_path.read_text())
        metrics = root.get("metrics", {})
        
        def get_val(data, key, default="0"):
            obj = data.get(key)
            if obj is None:
                return default
            if isinstance(obj, dict):
                return obj.get("_value", default)
            return str(obj)

        tests_executed_val = get_val(metrics, "testsCount", "0")
        tests_failed_val = get_val(metrics, "testsFailedCount", "0")
        duration_val = get_val(metrics, "testsDuration", "0")
        
        tests_executed = int(tests_executed_val)
        tests_failed = int(tests_failed_val)
        
        if duration_val != "0":
            test_duration = f"{float(duration_val):.1f} seconds"
            
        passed = tests_executed - tests_failed
        if tests_executed > 0:
            tests_pass_rate = f"{(passed / tests_executed) * 100:.2f}%"
        else:
            tests_pass_rate = "0.00%"
            
        tests_executed = str(tests_executed)
        tests_failed = str(tests_failed)
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to parse tests metadata: {exc}", file=sys.stderr)

overall_coverage = safe_percent(covered_lines / total_lines) if total_lines else "0.00%"

lines = []
lines.append("=" * 80)
lines.append("                    OnTrack iOS App - Coverage Summary")
lines.append("=" * 80)
lines.append(f"Generated: {now}")
lines.append("Log File: " + str(log_path))
lines.append("")
lines.append("=" * 80)
lines.append("                            EXECUTIVE SUMMARY")
lines.append("=" * 80)
lines.append("")
lines.append(f"Overall Coverage: {overall_coverage} ({covered_lines}/{total_lines} lines)")
lines.append(f"Tests Executed:   {tests_executed}")
lines.append(f"Tests Failed:     {tests_failed}")
lines.append(f"Pass Rate:        {tests_pass_rate}")
lines.append(f"Duration:         {test_duration}")
lines.append("")
lines.append("=" * 80)
lines.append("                        TARGET COVERAGE DETAILS")
lines.append("=" * 80)
lines.append("")
lines.append(f"{'Target':35} {'Coverage':>10} {'Covered':>12} {'Total':>12}")
lines.append("-" * 80)

for name, coverage, covered, executable in target_rows:
    lines.append(f"{name:35} {safe_percent(coverage):>10} {safe_int(covered):>12} {safe_int(executable):>12}")

lines.append("")
lines.append("=" * 80)
lines.append("                             TEST METRICS")
lines.append("=" * 80)
lines.append("")
lines.append(f"Log File: {log_path}")
lines.append("")
lines.append("=" * 80)
lines.append("                             CONCLUSION")
lines.append("=" * 80)
lines.append("")
lines.append("Automation summary generated by test.sh --coverage")
lines.append("=" * 80)
lines.append("")

coverage_path.write_text("\n".join(lines) + "\n")
PYCODE

    rm -f "$report_json" 2>/dev/null || true
    if [ -n "$tests_json" ]; then
        rm -f "$tests_json" 2>/dev/null || true
    fi
    success "Coverage summary updated → $COVERAGE_FILE"
}

run_suite() {
    local xcresult_bundle="$1"
    local log_file="$2"
    local filtered_pattern="(Test Suite.*(started|passed|failed)|Test Case.*(started|passed|failed)|Testing started|Executed.*tests|🧪|📋|📝|💰|🎨|💾|✅|↩️|⚠️|✏️|📜|🧹|💵|🔍|🗑️)"
    local extra_args=()

    if [ "$COVERAGE_MODE" = true ]; then
        extra_args+=(-enableCodeCoverage YES -resultBundlePath "$xcresult_bundle")
    fi

    run_xcodebuild "test-without-building" "$filtered_pattern" "$log_file" ${ONLY_TESTING_ARGS[@]+"${ONLY_TESTING_ARGS[@]}"} ${extra_args[@]+"${extra_args[@]}"}
}

run_isolated_tests() {
    local log_file="$1"
    local failures=0
    local passes=0

    for test_id in "${NORMALIZED_TESTS[@]}"; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🧪 Test: $test_id"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        shutdown_simulators
        boot_simulator

        local single_log="/tmp/ontrack_isolated_${test_id//\//_}_$(date +%Y%m%d_%H%M%S).log"
        local filtered="(Test Case.*(passed|failed)|error:|warning:)"
        ONLY_TESTING_ARGS=(-only-testing:OnTrackUITests/"$test_id")
        if run_xcodebuild "test" "$filtered" "$single_log"; then
            success "Test passed: $test_id"
            passes=$((passes + 1))
        else
            error "Test failed: $test_id"
            failures=$((failures + 1))
        fi

        cat "$single_log" >> "$log_file"
        echo "" >> "$log_file"
    done

    echo ""
    echo "======================================"
    echo "📊 Isolated Test Summary"
    echo "======================================"
    echo "  ✅ Passed: $passes"
    echo "  ❌ Failed: $failures"
    echo "  📁 Logs: $log_file"
    echo "======================================"

    if [ "$failures" -ne 0 ]; then
        return 1
    fi
    return 0
}

shutdown_simulators() {
    xcrun simctl shutdown all 2>/dev/null || true
}

#############################
# Argument parsing
#############################

LIST_MODE=false
ISOLATED_MODE=false
SERIAL_MODE=false
VERBOSE_MODE=false
COVERAGE_MODE=false
RUN_SUITE=false
declare -a NORMALIZED_TESTS=()
declare -a ONLY_TESTING_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --list|-l)
            LIST_MODE=true
            shift
            ;;
        --isolated|-i)
            ISOLATED_MODE=true
            shift
            ;;
        --serial|-s)
            SERIAL_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE_MODE=true
            shift
            ;;
        --coverage|-c)
            COVERAGE_MODE=true
            shift
            ;;
        --suite)
            RUN_SUITE=true
            shift
            ;;
        --tests|-t)
            if [ -z "${2:-}" ]; then
                error "Missing value for --tests"
                exit 1
            fi
            split_tests_argument "$2"
            shift 2
            ;;
        --*)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            split_tests_argument "$1"
            shift
            ;;
    esac
done

if [ "$LIST_MODE" = true ]; then
    list_tests
    exit 0
fi

if [ "$RUN_SUITE" = true ] && [ "${#NORMALIZED_TESTS[@]}" -gt 0 ]; then
    warn "--suite flag ignored because specific tests were provided"
fi

if [ "${#NORMALIZED_TESTS[@]}" -eq 0 ]; then
    RUN_SUITE=true
fi

#    if [ "$COVERAGE_MODE" = true ] && [ "$RUN_SUITE" = false ]; then
#        error "--coverage can only be used when running the full test suite"
#        exit 1
#    fi
if [ "$COVERAGE_MODE" = true ] && [ "$ISOLATED_MODE" = true ]; then
    warn "--coverage is not supported in isolated mode; disabling coverage"
    COVERAGE_MODE=false
fi

if [ "$RUN_SUITE" = true ] && [ "${#NORMALIZED_TESTS[@]}" -eq 0 ]; then
    collect_all_test_classes
fi

ensure_commands xcodebuild xcrun find grep sed awk jq python3

if [ "$RUN_SUITE" = true ]; then
    info "Selected mode: full suite"
else
    info "Selected mode: targeted tests (${#NORMALIZED_TESTS[@]} provided)"
fi

if [ "$ISOLATED_MODE" = true ]; then
    info "Isolation: enabled (each test boots a fresh simulator)"
else
    info "Isolation: disabled (tests run within a single xcodebuild invocation)"
fi

if [ "$SERIAL_MODE" = true ]; then
    info "Parallel testing: disabled"
else
    info "Parallel testing: enabled"
fi

if [ "$VERBOSE_MODE" = true ]; then
    info "Verbose output: enabled"
else
    info "Verbose output: disabled"
fi

if [ "$COVERAGE_MODE" = true ]; then
    info "Code coverage: enabled"
fi

ensure_server_running
build_for_testing

LOG_FILE="/tmp/ontrack_tests_$(date +%Y%m%d_%H%M%S).log"
XCRESULT_BUNDLE="/tmp/OnTrackTestResults_$(date +%Y%m%d_%H%M%S).xcresult"

if [ "$ISOLATED_MODE" = true ]; then
    if run_isolated_tests "$LOG_FILE"; then
        success "All isolated tests passed!"
        exit 0
    else
        error "Some isolated tests failed"
        exit 1
    fi
else
    boot_simulator
    ONLY_TESTING_ARGS=()

    if [ "$RUN_SUITE" = false ]; then
        for test_id in "${NORMALIZED_TESTS[@]}"; do
            ONLY_TESTING_ARGS+=(-only-testing:OnTrackUITests/"$test_id")
        done
        # TODO: Revert this to disable coverage for targeted tests after verification
        # COVERAGE_MODE=false
    fi

    exit_code=0
    if run_suite "$XCRESULT_BUNDLE" "$LOG_FILE"; then
        success "Tests completed successfully"
        exit_code=0
    else
        error "Tests failed (see $LOG_FILE)"
        exit_code=1
    fi

    if [ "$COVERAGE_MODE" = true ]; then
        update_coverage_summary "$XCRESULT_BUNDLE" "$LOG_FILE"
    fi

    exit "$exit_code"
fi


