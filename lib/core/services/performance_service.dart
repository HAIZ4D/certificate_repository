import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../config/app_config.dart';
import 'logger_service.dart';

class PerformanceService {
  static PerformanceService? _instance;
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<Duration>> _operationDurations = {};
  
  PerformanceService._internal();
  
  static PerformanceService get instance {
    _instance ??= PerformanceService._internal();
    return _instance!;
  }
  
  /// Start tracking an operation
  static void startOperation(String operationName) {
    if (AppConfig.isDebugMode && kDebugMode) {
      instance._operationStartTimes[operationName] = DateTime.now();
    }
  }
  
  /// End tracking an operation and log the duration
  static void endOperation(String operationName) {
    if (AppConfig.isDebugMode && kDebugMode) {
      final startTime = instance._operationStartTimes.remove(operationName);
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        
        // Store duration for analytics
        instance._operationDurations.putIfAbsent(operationName, () => []);
        instance._operationDurations[operationName]!.add(duration);
        
        // Log performance
        LoggerService.performance(operationName, duration);
        
        // Warn about slow operations
        if (duration.inMilliseconds > 1000) {
          LoggerService.warning('Slow operation detected: $operationName took ${duration.inMilliseconds}ms');
        }
      }
    }
  }
  
  /// Track widget build performance
  static T trackBuildPerformance<T>(String widgetName, T Function() buildFunction) {
    if (!AppConfig.isDebugMode || !kDebugMode) {
      return buildFunction();
    }
    
    final stopwatch = Stopwatch()..start();
    final result = buildFunction();
    stopwatch.stop();
    
    if (stopwatch.elapsedMilliseconds > 16) { // More than one frame (60fps)
      LoggerService.warning('Slow widget build: $widgetName took ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return result;
  }
  
  /// Track async operations
  static Future<T> trackAsyncOperation<T>(String operationName, Future<T> Function() operation) async {
    if (!AppConfig.isDebugMode || !kDebugMode) {
      return await operation();
    }
    
    startOperation(operationName);
    try {
      final result = await operation();
      endOperation(operationName);
      return result;
    } catch (e) {
      endOperation(operationName);
      LoggerService.error('Operation failed: $operationName', error: e);
      rethrow;
    }
  }
  
  /// Get performance statistics
  static Map<String, Map<String, dynamic>> getPerformanceStats() {
    if (!AppConfig.isDebugMode || !kDebugMode) {
      return {};
    }
    
    final stats = <String, Map<String, dynamic>>{};
    
    for (final entry in instance._operationDurations.entries) {
      final durations = entry.value;
      if (durations.isNotEmpty) {
        final totalMs = durations.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
        final avgMs = totalMs / durations.length;
        final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
        
        stats[entry.key] = {
          'count': durations.length,
          'avgMs': avgMs.round(),
          'maxMs': maxMs,
          'minMs': minMs,
          'totalMs': totalMs,
        };
      }
    }
    
    return stats;
  }
  
  /// Log performance summary
  static void logPerformanceSummary() {
    if (!AppConfig.isDebugMode || !kDebugMode) {
      return;
    }
    
    final stats = getPerformanceStats();
    if (stats.isNotEmpty) {
      LoggerService.info('Performance Summary:', error: stats);
    }
  }
  
  /// Clear performance data
  static void clearPerformanceData() {
    instance._operationStartTimes.clear();
    instance._operationDurations.clear();
  }
  
  /// Monitor memory usage (debug only)
  static void logMemoryUsage(String context) {
    if (AppConfig.isDebugMode && kDebugMode) {
      // This is a simplified memory monitoring
      // In production, you might want to use more sophisticated tools
      LoggerService.debug('Memory check at: $context');
    }
  }
  
  /// Track frame rendering issues
  static void trackFramePerformance() {
    if (AppConfig.isDebugMode && kDebugMode) {
      WidgetsBinding.instance.addPersistentFrameCallback((timeStamp) {
        // Monitor for frame drops
        final frameDuration = timeStamp.inMilliseconds;
        if (frameDuration > 16) { // 60fps threshold
          LoggerService.warning('Frame drop detected: ${frameDuration}ms');
        }
      });
    }
  }
} 