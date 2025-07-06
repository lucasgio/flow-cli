import 'dart:io';
import 'package:args/args.dart';
import 'package:flow_cli/core/utils/cli_utils.dart';
import 'package:flow_cli/shared/services/localization_service.dart';
import 'package:flow_cli/shared/services/config_service.dart';
import 'package:flow_cli/features/analyze/domain/analyze_usecase.dart';

class AnalyzeHandler {
  final AnalyzeUseCase _analyzeUseCase = AnalyzeUseCase();
  final LocalizationService _localization = LocalizationService.instance;
  final ConfigService _configService = ConfigService.instance;
  
  Future<void> handle(List<String> args) async {
    final parser = ArgParser()
      ..addFlag('optimize', help: 'Show optimization recommendations', negatable: false)
      ..addFlag('performance', help: 'Analyze performance issues', negatable: false)
      ..addFlag('size', help: 'Analyze app size', negatable: false)
      ..addFlag('dependencies', help: 'Analyze dependencies', negatable: false)
      ..addFlag('security', help: 'Security analysis', negatable: false)
      ..addFlag('all', help: 'Run all analyses', negatable: false)
      ..addOption('output', help: 'Output file for analysis report')
      ..addFlag('help', abbr: 'h', help: 'Show help for analyze command', negatable: false);
    
    try {
      final results = parser.parse(args);
      
      if (results['help']) {
        _showHelp(parser);
        return;
      }
      
      if (!_configService.isConfigured) {
        CliUtils.printError('Flow CLI is not configured. Please run: flow setup');
        exit(1);
      }
      
      CliUtils.printInfo(_localization.translate('analyze.starting'));
      
      final runAll = results['all'] as bool;
      final outputFile = results['output'] as String?;
      
      final analysisResults = <String, dynamic>{};
      
      // Run basic analysis
      final basicAnalysis = await _analyzeUseCase.runBasicAnalysis();
      analysisResults['basic'] = basicAnalysis;
      
      // Run specific analyses
      if (runAll || results['optimize']) {
        final optimizationAnalysis = await _analyzeUseCase.analyzeOptimizations();
        analysisResults['optimization'] = optimizationAnalysis;
        _printOptimizationResults(optimizationAnalysis);
      }
      
      if (runAll || results['performance']) {
        final performanceAnalysis = await _analyzeUseCase.analyzePerformance();
        analysisResults['performance'] = performanceAnalysis;
        _printPerformanceResults(performanceAnalysis);
      }
      
      if (runAll || results['size']) {
        final sizeAnalysis = await _analyzeUseCase.analyzeSize();
        analysisResults['size'] = sizeAnalysis;
        _printSizeResults(sizeAnalysis);
      }
      
      if (runAll || results['dependencies']) {
        final dependencyAnalysis = await _analyzeUseCase.analyzeDependencies();
        analysisResults['dependencies'] = dependencyAnalysis;
        _printDependencyResults(dependencyAnalysis);
      }
      
      if (runAll || results['security']) {
        final securityAnalysis = await _analyzeUseCase.analyzeSecurity();
        analysisResults['security'] = securityAnalysis;
        _printSecurityResults(securityAnalysis);
      }
      
      // Save report if output file is specified
      if (outputFile != null) {
        await _analyzeUseCase.saveReport(analysisResults, outputFile);
        CliUtils.printSuccess('Analysis report saved to: $outputFile');
      }
      
      CliUtils.printSuccess(_localization.translate('analyze.complete'));
      
    } catch (e) {
      CliUtils.printError('Analysis failed: $e');
      exit(1);
    }
  }
  
  void _printOptimizationResults(Map<String, dynamic> results) {
    CliUtils.printSeparator();
    print(CliUtils.formatTitle(_localization.translate('analyze.recommendations')));
    
    final recommendations = results['recommendations'] as List<String>? ?? [];
    if (recommendations.isEmpty) {
      CliUtils.printSuccess('No optimization recommendations found!');
    } else {
      for (final recommendation in recommendations) {
        CliUtils.printInfo(recommendation);
      }
    }
  }
  
  void _printPerformanceResults(Map<String, dynamic> results) {
    CliUtils.printSeparator();
    print(CliUtils.formatTitle('Performance Analysis'));
    
    final issues = results['issues'] as List<String>? ?? [];
    if (issues.isEmpty) {
      CliUtils.printSuccess('No performance issues found!');
    } else {
      for (final issue in issues) {
        CliUtils.printWarning(issue);
      }
    }
  }
  
  void _printSizeResults(Map<String, dynamic> results) {
    CliUtils.printSeparator();
    print(CliUtils.formatTitle('Size Analysis'));
    
    final appSize = results['appSize'] as String?;
    if (appSize != null) {
      CliUtils.printInfo('App size: $appSize');
    }
    
    final largeDependencies = results['largeDependencies'] as List<String>? ?? [];
    if (largeDependencies.isNotEmpty) {
      CliUtils.printInfo('Large dependencies:');
      for (final dep in largeDependencies) {
        print('  - $dep');
      }
    }
  }
  
  void _printDependencyResults(Map<String, dynamic> results) {
    CliUtils.printSeparator();
    print(CliUtils.formatTitle('Dependency Analysis'));
    
    final outdatedDeps = results['outdated'] as List<String>? ?? [];
    if (outdatedDeps.isEmpty) {
      CliUtils.printSuccess('All dependencies are up to date!');
    } else {
      CliUtils.printWarning('Outdated dependencies:');
      for (final dep in outdatedDeps) {
        print('  - $dep');
      }
    }
    
    final unusedDeps = results['unused'] as List<String>? ?? [];
    if (unusedDeps.isNotEmpty) {
      CliUtils.printInfo('Potentially unused dependencies:');
      for (final dep in unusedDeps) {
        print('  - $dep');
      }
    }
  }
  
  void _printSecurityResults(Map<String, dynamic> results) {
    CliUtils.printSeparator();
    print(CliUtils.formatTitle('Security Analysis'));
    
    final securityIssues = results['issues'] as List<String>? ?? [];
    if (securityIssues.isEmpty) {
      CliUtils.printSuccess('No security issues found!');
    } else {
      for (final issue in securityIssues) {
        CliUtils.printError(issue);
      }
    }
  }
  
  void _showHelp(ArgParser parser) {
    print('''
${CliUtils.formatTitle('Flow CLI Analysis')}

${_localization.translate('commands.analyze')}

${CliUtils.formatSubtitle('Usage:')}
  flow analyze [options]

${CliUtils.formatSubtitle('Options:')}
${parser.usage}

${CliUtils.formatSubtitle('Examples:')}
  flow analyze --all
  flow analyze --optimize
  flow analyze --performance --size
  flow analyze --all --output analysis_report.json
''');
  }
}