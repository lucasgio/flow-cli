import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/config_service.dart';

class AnalyzeUseCase {
  final ConfigService _configService = ConfigService.instance;

  Future<Map<String, dynamic>> runBasicAnalysis() async {
    try {
      final flutterPath = _configService.flutterPath!;
      final projectPath = _configService.projectPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      final result = await Process.run(
        flutterBin,
        ['analyze'],
        workingDirectory: projectPath,
      );

      return {
        'exitCode': result.exitCode,
        'stdout': result.stdout.toString(),
        'stderr': result.stderr.toString(),
        'hasIssues': result.exitCode != 0,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'hasIssues': true,
      };
    }
  }

  Future<Map<String, dynamic>> analyzeOptimizations() async {
    final recommendations = <String>[];

    try {
      final projectPath = _configService.projectPath!;

      // Check pubspec.yaml for optimization opportunities
      final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
      if (await pubspecFile.exists()) {
        final pubspecContent = await pubspecFile.readAsString();
        final pubspec = loadYaml(pubspecContent) as Map;

        // Check for build optimizations
        final flutter = pubspec['flutter'] as Map?;
        if (flutter != null) {
          if (flutter['uses-material-design'] != true) {
            recommendations.add(
                'Consider enabling Material Design for better performance');
          }

          if (flutter['generate'] != true) {
            recommendations
                .add('Enable code generation for better build performance');
          }
        }

        // Check dependencies for optimization opportunities
        final dependencies = pubspec['dependencies'] as Map?;
        if (dependencies != null) {
          _checkDependencyOptimizations(dependencies, recommendations);
        }
      }

      // Check for Android-specific optimizations
      await _checkAndroidOptimizations(recommendations);

      // Check for iOS-specific optimizations
      await _checkIOSOptimizations(recommendations);

      // Check for general Flutter optimizations
      await _checkFlutterOptimizations(recommendations);

      return {
        'recommendations': recommendations,
        'totalCount': recommendations.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'recommendations': recommendations,
      };
    }
  }

  Future<Map<String, dynamic>> analyzePerformance() async {
    final issues = <String>[];

    try {
      final projectPath = _configService.projectPath!;

      // Check for common performance issues in Dart code
      await _checkDartPerformanceIssues(projectPath, issues);

      // Check for image optimization issues
      await _checkImageOptimization(projectPath, issues);

      // Check for dependency performance issues
      await _checkDependencyPerformance(projectPath, issues);

      return {
        'issues': issues,
        'totalCount': issues.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'issues': issues,
      };
    }
  }

  Future<Map<String, dynamic>> analyzeSize() async {
    try {
      final projectPath = _configService.projectPath!;

      // Get app size information
      final appSize = await _getAppSize(projectPath);
      final largeDependencies = await _getLargeDependencies(projectPath);

      return {
        'appSize': appSize,
        'largeDependencies': largeDependencies,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> analyzeDependencies() async {
    try {
      final projectPath = _configService.projectPath!;

      // Get outdated dependencies
      final outdatedDeps = await _getOutdatedDependencies(projectPath);

      // Get unused dependencies (simplified check)
      final unusedDeps = await _getUnusedDependencies(projectPath);

      return {
        'outdated': outdatedDeps,
        'unused': unusedDeps,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> analyzeSecurity() async {
    final issues = <String>[];

    try {
      final projectPath = _configService.projectPath!;

      // Check for security issues
      await _checkSecurityIssues(projectPath, issues);

      return {
        'issues': issues,
        'totalCount': issues.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'issues': issues,
      };
    }
  }

  Future<void> saveReport(
      Map<String, dynamic> results, String outputFile) async {
    try {
      final file = File(outputFile);
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    } catch (e) {
      CliUtils.printError('Failed to save report: $e');
    }
  }

  void _checkDependencyOptimizations(
      Map dependencies, List<String> recommendations) {
    // Check for heavy dependencies
    final heavyDependencies = [
      'firebase_core',
      'firebase_auth',
      'cloud_firestore',
      'camera',
      'image_picker',
      'video_player'
    ];

    for (final dep in heavyDependencies) {
      if (dependencies.containsKey(dep)) {
        recommendations.add('Consider lazy loading for heavy dependency: $dep');
      }
    }
  }

  Future<void> _checkAndroidOptimizations(List<String> recommendations) async {
    try {
      final projectPath = _configService.projectPath!;
      final buildGradle =
          File(path.join(projectPath, 'android', 'app', 'build.gradle'));

      if (await buildGradle.exists()) {
        final content = await buildGradle.readAsString();

        if (!content.contains('shrinkResources true')) {
          recommendations
              .add('Enable resource shrinking in Android build.gradle');
        }

        if (!content.contains('minifyEnabled true')) {
          recommendations
              .add('Enable code minification in Android build.gradle');
        }
      }
    } catch (e) {
      // Ignore errors for optional checks
    }
  }

  Future<void> _checkIOSOptimizations(List<String> recommendations) async {
    try {
      final projectPath = _configService.projectPath!;
      final infoPlist =
          File(path.join(projectPath, 'ios', 'Runner', 'Info.plist'));

      if (await infoPlist.exists()) {
        final content = await infoPlist.readAsString();

        if (!content.contains('NSAppTransportSecurity')) {
          recommendations
              .add('Consider configuring App Transport Security for iOS');
        }
      }
    } catch (e) {
      // Ignore errors for optional checks
    }
  }

  Future<void> _checkFlutterOptimizations(List<String> recommendations) async {
    try {
      final projectPath = _configService.projectPath!;

      // Check for const constructors usage
      final libDir = Directory(path.join(projectPath, 'lib'));
      if (await libDir.exists()) {
        recommendations.add(
            'Review widget constructors for const optimization opportunities');
      }

      // Check for build methods that are too complex
      recommendations.add(
          'Consider breaking down complex build methods into smaller widgets');
    } catch (e) {
      // Ignore errors for optional checks
    }
  }

  Future<void> _checkDartPerformanceIssues(
      String projectPath, List<String> issues) async {
    try {
      final libDir = Directory(path.join(projectPath, 'lib'));
      if (await libDir.exists()) {
        // This is a simplified check - in a real implementation,
        // you would analyze the AST or use static analysis tools
        issues.add('Consider using const constructors where possible');
        issues.add('Review build methods for unnecessary rebuilds');
      }
    } catch (e) {
      // Ignore errors for optional checks
    }
  }

  Future<void> _checkImageOptimization(
      String projectPath, List<String> issues) async {
    try {
      final assetsDir = Directory(path.join(projectPath, 'assets'));
      if (await assetsDir.exists()) {
        final imageFiles = await assetsDir
            .list(recursive: true)
            .where((file) =>
                file.path.endsWith('.png') || file.path.endsWith('.jpg'))
            .toList();

        if (imageFiles.length > 10) {
          issues.add('Consider optimizing image assets for better performance');
        }
      }
    } catch (e) {
      // Ignore errors for optional checks
    }
  }

  Future<void> _checkDependencyPerformance(
      String projectPath, List<String> issues) async {
    try {
      final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
      if (await pubspecFile.exists()) {
        final content = await pubspecFile.readAsString();
        final pubspec = loadYaml(content) as Map;

        final dependencies = pubspec['dependencies'] as Map?;
        if (dependencies != null && dependencies.length > 20) {
          issues.add('Large number of dependencies may impact performance');
        }
      }
    } catch (e) {
      // Ignore errors for optional checks
    }
  }

  Future<String?> _getAppSize(String projectPath) async {
    try {
      // This is a simplified implementation
      // In a real scenario, you would analyze the built APK/IPA files
      final buildDir = Directory(path.join(projectPath, 'build'));
      if (await buildDir.exists()) {
        return 'Analysis requires built APK/IPA files';
      }
      return 'No build files found';
    } catch (e) {
      return 'Error analyzing app size: $e';
    }
  }

  Future<List<String>> _getLargeDependencies(String projectPath) async {
    try {
      // This is a simplified implementation
      // In a real scenario, you would analyze dependency sizes
      return [
        'firebase_core (estimated 2MB)',
        'camera (estimated 1.5MB)',
      ];
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> _getOutdatedDependencies(String projectPath) async {
    try {
      final flutterPath = _configService.flutterPath!;
      final flutterBin = path.join(flutterPath, 'bin', 'flutter');

      final result = await Process.run(
        flutterBin,
        ['pub', 'outdated', '--json'],
        workingDirectory: projectPath,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final data = jsonDecode(output) as Map<String, dynamic>;
        final packages = data['packages'] as List?;

        if (packages != null) {
          return packages.map((p) => p['package'] as String).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> _getUnusedDependencies(String projectPath) async {
    try {
      // This is a simplified implementation
      // In a real scenario, you would analyze import statements
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> _checkSecurityIssues(
      String projectPath, List<String> issues) async {
    try {
      final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
      if (await pubspecFile.exists()) {
        final content = await pubspecFile.readAsString();

        if (content.contains('http:')) {
          issues.add('HTTP URLs found - consider using HTTPS');
        }

        if (content.contains('debug:')) {
          issues.add(
              'Debug configurations found - ensure they are not in production');
        }
      }
    } catch (e) {
      // Ignore errors for optional checks
    }
  }
}
