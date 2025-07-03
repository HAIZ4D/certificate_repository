import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class LoggerService {
  static LoggerService? _instance;
  late final Logger _logger;
  
  LoggerService._internal() {
    _logger = Logger(
      level: AppConfig.isDebugMode ? Level.debug : Level.warning,
      printer: PrettyPrinter(
        methodCount: AppConfig.isDebugMode ? 2 : 0,
        errorMethodCount: 3,
        lineLength: 80,
        colors: true,
        printEmojis: true,
        dateTimeFormat: AppConfig.enableDetailedLogging 
            ? DateTimeFormat.onlyTimeAndSinceStart 
            : DateTimeFormat.none,
      ),
      filter: ProductionFilter(),
    );
  }
  
  static LoggerService get instance {
    _instance ??= LoggerService._internal();
    return _instance!;
  }
  
  // Production-safe logging methods
  static void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    if (AppConfig.isDebugMode && kDebugMode) {
      instance._logger.d(message, error: error, stackTrace: stackTrace);
    }
  }
  
  static void info(String message, {dynamic error, StackTrace? stackTrace}) {
    if (AppConfig.enableDetailedLogging || kDebugMode) {
      instance._logger.i(message, error: error, stackTrace: stackTrace);
    }
  }
  
  static void warning(String message, {dynamic error, StackTrace? stackTrace}) {
    instance._logger.w(message, error: error, stackTrace: stackTrace);
  }
  
  static void error(String message, {dynamic error, StackTrace? stackTrace}) {
    instance._logger.e(message, error: error, stackTrace: stackTrace);
  }
  
  static void fatal(String message, {dynamic error, StackTrace? stackTrace}) {
    instance._logger.f(message, error: error, stackTrace: stackTrace);
  }
  
  // Network logging for debugging
  static void network(String method, String url, {int? statusCode, dynamic body}) {
    if (AppConfig.isDebugMode && kDebugMode) {
      debug('[$method] $url ${statusCode != null ? '($statusCode)' : ''}', 
            error: body);
    }
  }
  
  // Authentication logging
  static void auth(String event, {String? userId, String? email}) {
    if (AppConfig.enableDetailedLogging) {
      info('Auth: $event', error: {'userId': userId, 'email': email});
    }
  }
  
  // Performance logging
  static void performance(String operation, Duration duration) {
    if (AppConfig.isDebugMode && kDebugMode) {
      debug('Performance: $operation took ${duration.inMilliseconds}ms');
    }
  }
}

class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In production, only log warnings and above
    if (!kDebugMode && !AppConfig.isDebugMode) {
      return event.level.index >= Level.warning.index;
    }
    
    // In debug mode, log everything based on configuration
    if (AppConfig.enableDetailedLogging) {
      return true;
    }
    
    // Default: log info and above
    return event.level.index >= Level.info.index;
  }
} 