import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class ErrorHandlerService {
  static final Logger _logger = Logger();
  static ErrorHandlerService? _instance;
  
  ErrorHandlerService._internal();
  
  factory ErrorHandlerService() {
    _instance ??= ErrorHandlerService._internal();
    return _instance!;
  }

  /// Handle and log errors with appropriate user feedback
  static void handleError({
    required dynamic error,
    required BuildContext context,
    StackTrace? stackTrace,
    String? customMessage,
    bool showSnackBar = true,
  }) {
    // Log the error
    _logger.e('Error occurred: $error', error: error, stackTrace: stackTrace);
    
    // Determine user-friendly message
    String userMessage = customMessage ?? _getUserFriendlyMessage(error);
    
    // Show user feedback if requested and context is valid
    if (showSnackBar && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  /// Convert technical errors to user-friendly messages
  static String _getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorString.contains('permission')) {
      return 'Permission denied. Please check your access rights.';
    } else if (errorString.contains('not found')) {
      return 'The requested resource was not found.';
    } else if (errorString.contains('unauthorized') || errorString.contains('authentication')) {
      return 'Authentication failed. Please log in again.';
    } else if (errorString.contains('firebase')) {
      return 'Service unavailable. Please try again later.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Handle async operations with error handling
  static Future<T?> handleAsyncOperation<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
    bool showLoading = false,
  }) async {
    try {
      if (showLoading && loadingMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loadingMessage),
            duration: const Duration(seconds: 30), // Long duration for loading
          ),
        );
      }

      final result = await operation();

      if (context.mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        if (successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      return result;
    } catch (error, stackTrace) {
      if (context.mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        handleError(
          error: error,
          context: context,
          stackTrace: stackTrace,
          customMessage: errorMessage,
        );
      }
      return null;
    }
  }

  /// Safe navigation with error handling
  static void safeNavigate({
    required BuildContext context,
    required VoidCallback navigation,
    String? errorMessage,
  }) {
    try {
      if (context.mounted) {
        navigation();
      }
    } catch (error, stackTrace) {
      handleError(
        error: error,
        context: context,
        stackTrace: stackTrace,
        customMessage: errorMessage ?? 'Navigation failed.',
      );
    }
  }
} 