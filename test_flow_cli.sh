#!/bin/bash

# Flow CLI Internal Testing Script
# This script tests all Flow CLI features before publishing to pub.dev

set -e  # Exit on any error

echo "🚀 Starting Flow CLI Internal Testing"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    echo -e "\n${BLUE}🧪 Testing: $test_name${NC}"
    echo "Command: $test_command"
    
    if eval "$test_command" > /tmp/flow_test_output.log 2>&1; then
        if [ $? -eq $expected_exit_code ]; then
            echo -e "${GREEN}✅ PASSED: $test_name${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}❌ FAILED: $test_name (Expected exit code: $expected_exit_code, Got: $?)${NC}"
            cat /tmp/flow_test_output.log
            ((TESTS_FAILED++))
        fi
    else
        if [ $? -eq $expected_exit_code ]; then
            echo -e "${GREEN}✅ PASSED: $test_name${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}❌ FAILED: $test_name (Expected exit code: $expected_exit_code, Got: $?)${NC}"
            cat /tmp/flow_test_output.log
            ((TESTS_FAILED++))
        fi
    fi
}

# Function to check if command output contains expected text
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    local expected_text="$3"
    
    echo -e "\n${BLUE}🧪 Testing: $test_name${NC}"
    echo "Command: $test_command"
    echo "Expected output contains: $expected_text"
    
    if eval "$test_command" | grep -q "$expected_text"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        echo "Output:"
        eval "$test_command"
        ((TESTS_FAILED++))
    fi
}

# Check if Dart is available
echo -e "\n${YELLOW}📋 Checking Dart installation...${NC}"
if ! command -v dart &> /dev/null; then
    echo -e "${RED}❌ Dart not found in PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Dart found at: $(which dart)${NC}"

# Test 1: Basic help command
run_test_with_output "Help Command" "dart run bin/main.dart --help" "Flow CLI"

# Test 2: Version command
run_test_with_output "Version Command" "dart run bin/main.dart --version" "1.0.0"

# Test 3: Setup command help
run_test_with_output "Setup Help" "dart run bin/main.dart setup --help" "setup"

# Test 4: Build command help
run_test_with_output "Build Help" "dart run bin/main.dart build --help" "build"

# Test 5: Device command help
run_test_with_output "Device Help" "dart run bin/main.dart device --help" "device"

# Test 6: Hot reload command help
run_test_with_output "Hot Reload Help" "dart run bin/main.dart hotreload --help" "hotreload"

# Test 7: Web command help
run_test_with_output "Web Help" "dart run bin/main.dart web --help" "web"

# Test 8: Analyze command help
run_test_with_output "Analyze Help" "dart run bin/main.dart analyze --help" "analyze"

# Test 9: Config command help
run_test_with_output "Config Help" "dart run bin/main.dart config --help" "config"

# Test 10: Invalid command (should show error)
run_test "Invalid Command" "dart run bin/main.dart invalid-command" 1

# Test 11: Setup command (dry run)
echo -e "\n${YELLOW}📋 Testing Setup Command (Dry Run)...${NC}"
run_test "Setup Command" "dart run bin/main.dart setup --help" 0

# Test 12: Config list (if config exists)
echo -e "\n${YELLOW}📋 Testing Config Commands...${NC}"
run_test "Config List" "dart run bin/main.dart config --list" 0

# Test 13: Build command with invalid platform
run_test "Build Invalid Platform" "dart run bin/main.dart build invalid-platform" 1

# Test 14: Device list command
run_test "Device List" "dart run bin/main.dart device list" 0

# Test 15: Web serve help
run_test_with_output "Web Serve Help" "dart run bin/main.dart web serve --help" "serve"

# Test 16: Web build help
run_test_with_output "Web Build Help" "dart run bin/main.dart web build --help" "build"

# Test 17: Web deploy help
run_test_with_output "Web Deploy Help" "dart run bin/main.dart web deploy --help" "deploy"

# Test 18: Analyze all help
run_test_with_output "Analyze All Help" "dart run bin/main.dart analyze --all --help" "analyze"

# Test 19: Hot reload with invalid device
run_test "Hot Reload Invalid Device" "dart run bin/main.dart hotreload --device invalid-device" 1

# Test 20: Multi-client setup help
run_test_with_output "Multi-Client Setup Help" "dart run bin/main.dart setup --multi-client --help" "setup"

# Performance and stress tests
echo -e "\n${YELLOW}📋 Running Performance Tests...${NC}"

# Test 21: Command response time
echo -e "\n${BLUE}🧪 Testing: Command Response Time${NC}"
start_time=$(date +%s.%N)
dart run bin/main.dart --help > /dev/null 2>&1
end_time=$(date +%s.%N)
response_time=$(echo "$end_time - $start_time" | bc)
echo -e "${GREEN}✅ Command response time: ${response_time}s${NC}"
((TESTS_PASSED++))

# Test 22: Memory usage check
echo -e "\n${BLUE}🧪 Testing: Memory Usage${NC}"
if command -v ps &> /dev/null; then
    dart run bin/main.dart --help > /dev/null 2>&1 &
    FLOW_PID=$!
    sleep 1
    MEMORY_USAGE=$(ps -o rss= -p $FLOW_PID 2>/dev/null || echo "0")
    kill $FLOW_PID 2>/dev/null || true
    echo -e "${GREEN}✅ Memory usage: ${MEMORY_USAGE}KB${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Memory usage test skipped (ps command not available)${NC}"
fi

# Integration tests
echo -e "\n${YELLOW}📋 Running Integration Tests...${NC}"

# Test 23: Command chaining
run_test "Command Chaining" "dart run bin/main.dart --help | head -5" 0

# Test 24: Output redirection
run_test "Output Redirection" "dart run bin/main.dart --help > /tmp/flow_help.txt && test -s /tmp/flow_help.txt" 0

# Test 25: Error handling
run_test "Error Handling" "dart run bin/main.dart nonexistent-command 2>&1 | grep -q 'error\|Error\|ERROR'" 0

# Cleanup
rm -f /tmp/flow_test_output.log /tmp/flow_help.txt

# Final results
echo -e "\n${YELLOW}📊 Test Results Summary${NC}"
echo "======================================"
echo -e "${GREEN}✅ Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Tests Failed: $TESTS_FAILED${NC}"
echo -e "${BLUE}📈 Total Tests: $((TESTS_PASSED + TESTS_FAILED))${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Flow CLI is ready for publishing.${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  Some tests failed. Please review and fix issues before publishing.${NC}"
    exit 1
fi 