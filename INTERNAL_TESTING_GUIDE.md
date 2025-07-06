# Flow CLI Internal Testing Guide

This guide helps you thoroughly test the Flow CLI before publishing to pub.dev.

## 🚀 Quick Start Testing

### 1. Install Flow CLI Locally
```bash
# Activate from source
dart pub global activate --source path .

# Add to PATH (add this to your shell config)
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

### 2. Run Automated Tests
```bash
# Run the comprehensive test script
./test_flow_cli.sh

# Run Dart unit tests
dart test

# Run analysis
dart analyze --fatal-infos
```

## 📋 Manual Testing Checklist

### ✅ Basic Functionality Tests

#### Help and Version
- [ ] `flow --help` - Shows comprehensive help
- [ ] `flow --version` - Shows correct version (1.0.0)
- [ ] `flow` (no args) - Shows help or usage

#### Setup Commands
- [ ] `flow setup --help` - Shows setup options
- [ ] `flow setup --multi-client --help` - Shows multi-client setup
- [ ] `flow setup` - Interactive setup (test in a temp directory)

#### Build Commands
- [ ] `flow build --help` - Shows build options
- [ ] `flow build android --help` - Shows Android build options
- [ ] `flow build ios --help` - Shows iOS build options
- [ ] `flow build web --help` - Shows web build options
- [ ] `flow build invalid-platform` - Shows appropriate error

#### Device Commands
- [ ] `flow device --help` - Shows device options
- [ ] `flow device list` - Lists available devices
- [ ] `flow device run --help` - Shows run options
- [ ] `flow device logs --help` - Shows logs options

#### Hot Reload Commands
- [ ] `flow hotreload --help` - Shows hot reload options
- [ ] `flow hotreload --device invalid-device` - Shows error for invalid device

#### Web Commands
- [ ] `flow web --help` - Shows web options
- [ ] `flow web serve --help` - Shows serve options
- [ ] `flow web build --help` - Shows build options
- [ ] `flow web deploy --help` - Shows deploy options
- [ ] `flow web analyze --help` - Shows analyze options

#### Analysis Commands
- [ ] `flow analyze --help` - Shows analysis options
- [ ] `flow analyze --all --help` - Shows all analysis options

#### Configuration Commands
- [ ] `flow config --help` - Shows config options
- [ ] `flow config --list` - Lists current configuration
- [ ] `flow config flutter-path --help` - Shows path config

### ✅ Error Handling Tests

#### Invalid Commands
- [ ] `flow invalid-command` - Shows appropriate error message
- [ ] `flow build invalid-platform` - Shows platform error
- [ ] `flow device run --device invalid-device` - Shows device error

#### Missing Arguments
- [ ] `flow build` - Shows missing platform error
- [ ] `flow device run` - Shows missing device error
- [ ] `flow web serve` - Shows missing port or project error

#### File System Errors
- [ ] Run commands in non-Flutter directory - Shows appropriate error
- [ ] Run with missing Flutter SDK - Shows SDK error

### ✅ Performance Tests

#### Response Time
- [ ] `flow --help` - Responds within 2 seconds
- [ ] `flow setup --help` - Responds within 2 seconds
- [ ] `flow build --help` - Responds within 2 seconds

#### Memory Usage
- [ ] Check memory usage during command execution
- [ ] Verify no memory leaks in long-running commands

### ✅ Integration Tests

#### Real Flutter Project Testing
Create a test Flutter project and test:

```bash
# Create test project
flutter create test_flow_project
cd test_flow_project

# Test setup
flow setup

# Test configuration
flow config --list

# Test device detection
flow device list

# Test build commands (dry run)
flow build android --help
flow build ios --help
flow build web --help

# Test web development
flow web serve --help
flow web build --help

# Test analysis
flow analyze --help
```

#### Multi-Client Testing
- [ ] Test multi-client setup
- [ ] Test client-specific configurations
- [ ] Test client switching

### ✅ Cross-Platform Testing

#### macOS Testing
- [ ] All commands work on macOS
- [ ] Device detection works
- [ ] Build commands work

#### Linux Testing (if available)
- [ ] All commands work on Linux
- [ ] Device detection works
- [ ] Build commands work

#### Windows Testing (if available)
- [ ] All commands work on Windows
- [ ] Device detection works
- [ ] Build commands work

## 🔧 Advanced Testing

### Interactive Commands
Test interactive features:
- [ ] Setup wizard
- [ ] Device selection
- [ ] Hot reload controls
- [ ] Web server controls

### Configuration Persistence
- [ ] Test config saving and loading
- [ ] Test config validation
- [ ] Test config migration

### Error Recovery
- [ ] Test recovery from network errors
- [ ] Test recovery from file system errors
- [ ] Test recovery from Flutter SDK errors

## 📊 Test Results Tracking

### Create Test Report
```bash
# Run tests and save results
./test_flow_cli.sh > test_results.log 2>&1

# Check exit code
echo "Test exit code: $?"
```

### Test Coverage
- [ ] All commands tested
- [ ] All error cases tested
- [ ] All platforms tested
- [ ] Performance benchmarks recorded

## 🚨 Common Issues to Check

### Installation Issues
- [ ] PATH configuration
- [ ] Dart SDK compatibility
- [ ] Dependencies resolution

### Runtime Issues
- [ ] Flutter SDK detection
- [ ] Device detection
- [ ] Network connectivity
- [ ] File permissions

### Output Issues
- [ ] Help text formatting
- [ ] Error message clarity
- [ ] Progress indicators
- [ ] Color output

## ✅ Pre-Publishing Checklist

Before publishing to pub.dev, ensure:

### Code Quality
- [ ] All tests pass
- [ ] Analysis passes without warnings
- [ ] Code is properly formatted
- [ ] Documentation is complete

### Functionality
- [ ] All commands work as expected
- [ ] Error handling is robust
- [ ] Performance is acceptable
- [ ] Cross-platform compatibility verified

### Package Quality
- [ ] pubspec.yaml is complete
- [ ] README.md is comprehensive
- [ ] CHANGELOG.md is updated
- [ ] LICENSE file is present
- [ ] .pubignore excludes unnecessary files

### CI/CD
- [ ] GitHub Actions workflows work
- [ ] Build jobs complete successfully
- [ ] Release process tested
- [ ] Publishing process verified

## 🎯 Testing Commands Summary

```bash
# Basic testing
./test_flow_cli.sh

# Manual testing
flow --help
flow setup --help
flow build --help
flow device --help
flow hotreload --help
flow web --help
flow analyze --help
flow config --help

# Error testing
flow invalid-command
flow build invalid-platform

# Performance testing
time flow --help

# Integration testing
cd /path/to/flutter/project
flow setup
flow device list
flow config --list
```

## 📝 Test Report Template

After testing, create a report with:

1. **Test Environment**: OS, Dart version, Flutter version
2. **Test Results**: Pass/fail counts, specific failures
3. **Performance Metrics**: Response times, memory usage
4. **Issues Found**: Description and severity
5. **Recommendations**: What to fix before publishing

This comprehensive testing ensures your Flow CLI is ready for public release! 🚀 