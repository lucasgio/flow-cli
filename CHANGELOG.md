# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2024-07-06

### Fixed
- Fixed executable name from `flowtest` to `flow` in pubspec.yaml
- CLI now installs with correct command name: `flow` instead of `flowtest`

## [1.0.1] - 2024-07-06

### Fixed
- Fixed missing `build` feature files in published package
- Corrected `.pubignore` to exclude only root `/build/` directory, not `lib/features/build/`
- All CLI commands now work correctly including `build` command

## [1.0.0] - 2024-07-06

### Added
- Initial release of Flow CLI
- Comprehensive Flutter CLI tool for project management
- Features: setup, build, device, analyze, config, hotreload, web
- Multi-client support
- Localization (English/Spanish)
- Interactive setup wizard
- Real-time hot reload with logging
- Web development server
- Device management for Android and iOS
- Configuration management
- Analysis and optimization tools

### Features
- **Setup**: Interactive project initialization with multi-client support
- **Build**: Cross-platform build management with various configurations
- **Device**: Device detection, deployment, and management
- **Hot Reload**: Interactive development with real-time feedback
- **Web**: Full-featured web development and deployment tools
- **Analysis**: Performance and optimization analysis
- **Configuration**: Flutter SDK and project settings management

### Technical
- Dart 3.0+ compatibility
- Cross-platform support (Windows, macOS, Linux)
- Modular architecture with clean separation of concerns
- Comprehensive error handling and logging
- Interactive CLI with keyboard shortcuts
- Automated testing and CI/CD pipeline 