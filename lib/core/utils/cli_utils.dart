import 'dart:io';
import 'package:colorize/colorize.dart';
import 'package:flow_cli/core/utils/logger.dart';

class CliUtils {
  static final _logger = AppLogger.instance;

  static void printSuccess(String message) {
    _logger.info(Colorize('✅ $message').green().toString());
  }

  static void printError(String message) {
    _logger.error(Colorize('❌ $message').red().toString());
  }

  static void printWarning(String message) {
    _logger.warning(Colorize('⚠️  $message').yellow().toString());
  }

  static void printInfo(String message) {
    _logger.info(Colorize('ℹ️  $message').blue().toString());
  }

  static String formatTitle(String title) {
    return Colorize(title).bold().toString();
  }

  static String formatSubtitle(String subtitle) {
    return Colorize(subtitle).underline().toString();
  }

  static void printSeparator() {
    _logger.info(Colorize('─' * 50).darkGray().toString());
  }

  static Future<bool> confirm(String message) async {
    stdout.write('$message (y/n): ');
    final input = stdin.readLineSync()?.toLowerCase();
    return input == 'y' || input == 'yes';
  }

  static void showSpinner(String message) {
    stdout.write('⏳ $message...');
  }

  static void clearLine() {
    stdout.write('\r\x1b[K');
  }

  static void printProgressBar(int current, int total, {int width = 50}) {
    final progress = (current / total * width).round();
    final bar = '█' * progress + '░' * (width - progress);
    final percentage = (current / total * 100).round();
    stdout.write('\r[$bar] $percentage% ($current/$total)');
    if (current == total) stdout.write('\n');
  }
}
