import 'dart:io';
import 'package:colorize/colorize.dart';

class CliUtils {
  static void printSuccess(String message) {
    print(Colorize('✅ $message').green());
  }
  
  static void printError(String message) {
    print(Colorize('❌ $message').red());
  }
  
  static void printWarning(String message) {
    print(Colorize('⚠️  $message').yellow());
  }
  
  static void printInfo(String message) {
    print(Colorize('ℹ️  $message').blue());
  }
  
  static String formatTitle(String title) {
    return Colorize(title).bold().toString();
  }
  
  static String formatSubtitle(String subtitle) {
    return Colorize(subtitle).underline().toString();
  }
  
  static void printSeparator() {
    print(Colorize('─' * 50).darkGray());
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