# Flow CLI Publishing Guide

This document outlines the requirements and process for publishing the Flow CLI package to pub.dev.

## Changes Made for Publishing

### 1. Added Required Files

- **LICENSE**: MIT License file (required for all packages)
- **CHANGELOG.md**: Version history tracking
- **.pubignore**: Excludes large files and unnecessary content from the published package

### 2. Updated pubspec.yaml

Added required metadata fields:
- `repository`: GitHub repository URL
- `issue_tracker`: GitHub issues URL  
- `documentation`: README link

### 3. Fixed CI/CD Workflow

- **Build Matrix**: Now builds executables for all platforms (Linux, macOS, Windows)
- **Artifact Management**: Proper artifact upload/download for release assets
- **Release Assets**: All platform executables are uploaded to GitHub releases
- **Publishing**: Automated publishing to pub.dev on release

## Publishing Requirements ✅

Based on the [Dart publishing documentation](https://dart.dev/tools/pub/publishing), all requirements are met:

### ✅ Required Files
- [x] LICENSE file (MIT License)
- [x] Valid pubspec.yaml with complete metadata
- [x] README.md with comprehensive documentation
- [x] CHANGELOG.md for version tracking

### ✅ Package Structure
- [x] Follows Dart package conventions
- [x] Proper directory structure (lib/, bin/, test/)
- [x] Executable defined in pubspec.yaml
- [x] Analysis passes without issues

### ✅ Size and Content
- [x] Package size under 100MB (current: 37KB compressed)
- [x] .pubignore excludes large files (flow executable, build artifacts)
- [x] Only hosted dependencies from default pub server
- [x] No unnecessary files included

### ✅ CI/CD Pipeline
- [x] Automated testing on multiple platforms
- [x] Code formatting and analysis checks
- [x] Build verification for all platforms
- [x] Automated publishing to pub.dev
- [x] GitHub release asset creation

## Publishing Process

### Manual Publishing
```bash
# Test the package
dart pub publish --dry-run

# Publish to pub.dev (requires PUB_TOKEN)
dart pub publish --force
```

### Automated Publishing
The package will be automatically published when:
1. A GitHub release is created
2. All CI/CD tests pass
3. The `PUB_TOKEN` secret is configured in GitHub

## Required Secrets

### GitHub Repository Secrets
- `PUB_TOKEN`: Your pub.dev authentication token

### How to Get PUB_TOKEN
1. Go to https://pub.dev
2. Sign in with your Google account
3. Go to your profile settings
4. Generate an API token
5. Add it to your GitHub repository secrets

## Version Management

### Semantic Versioning
- **MAJOR.MINOR.PATCH** format
- Update version in `pubspec.yaml`
- Document changes in `CHANGELOG.md`
- Create GitHub release with matching version tag

### Release Process
1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md` with new version
3. Commit and push changes
4. Create GitHub release with version tag
5. CI/CD will automatically:
   - Run tests
   - Build executables
   - Publish to pub.dev
   - Upload release assets

## Package Information

- **Name**: flow_cli
- **Description**: A comprehensive Flutter CLI tool for project management, building, and deployment
- **Homepage**: https://github.com/Flowstore/flow-cli
- **License**: MIT
- **SDK**: >=3.0.0 <4.0.0
- **Executable**: flow

## Installation

After publishing, users can install the package with:
```bash
dart pub global activate flow_cli
```

## Support

- **Issues**: https://github.com/Flowstore/flow-cli/issues
- **Documentation**: https://github.com/Flowstore/flow-cli#readme
- **Repository**: https://github.com/Flowstore/flow-cli 