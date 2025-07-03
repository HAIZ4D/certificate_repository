import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class WebStorageUtils {
  static final Logger _logger = Logger();

  /// Get Web-compatible download URL
  static String getWebCompatibleUrl(String firebaseStorageUrl) {
    if (!kIsWeb || firebaseStorageUrl.isEmpty) {
      return firebaseStorageUrl;
    }

    try {
      // If already a Firebase Storage URL, convert to direct access link
      if (firebaseStorageUrl.contains('firebasestorage.googleapis.com')) {
        // Extract bucket name and file path
        final uri = Uri.parse(firebaseStorageUrl);
        
        // For Web platform, use method that won't trigger CORS preflight requests
        // Add alt=media parameter to directly download file
        if (!uri.queryParameters.containsKey('alt')) {
          final newParams = Map<String, String>.from(uri.queryParameters);
          newParams['alt'] = 'media';
          
          final newUri = uri.replace(queryParameters: newParams);
          return newUri.toString();
        }
      }
      
      return firebaseStorageUrl;
    } catch (e) {
      _logger.w('Failed to convert Firebase Storage URL: $e');
      return firebaseStorageUrl;
    }
  }

  /// Check if URL can be safely accessed on Web
  static bool isWebSafeUrl(String url) {
    if (!kIsWeb || url.isEmpty) {
      return true;
    }

    // Check if it's a Firebase Storage URL
    if (url.contains('firebasestorage.googleapis.com')) {
      // Check if it contains correct parameters
      final uri = Uri.tryParse(url);
      if (uri != null) {
        return uri.queryParameters.containsKey('alt');
      }
    }

    return true;
  }

  /// Add CORS proxy for image URL (if needed)
  static String getImageProxyUrl(String imageUrl) {
    if (!kIsWeb || isWebSafeUrl(imageUrl)) {
      return imageUrl;
    }

    // For unsafe URLs, return placeholder or use proxy
    return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzk5OSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkRvY3VtZW50PC90ZXh0Pjwvc3ZnPg==';
  }

  /// Get safe preview URL
  static String getSafePreviewUrl(String originalUrl) {
    if (!kIsWeb) {
      return originalUrl;
    }

    final webSafeUrl = getWebCompatibleUrl(originalUrl);
    
    // If still unsafe after conversion, return placeholder
    if (!isWebSafeUrl(webSafeUrl)) {
      return getImageProxyUrl(webSafeUrl);
    }

    return webSafeUrl;
  }

  /// Safely preload images (avoid CORS errors)
  static Future<bool> canLoadImage(String imageUrl) async {
    if (!kIsWeb) {
      return true;
    }

    try {
      final webSafeUrl = getSafePreviewUrl(imageUrl);
      // Here you can add actual image loading tests
      return webSafeUrl.isNotEmpty;
    } catch (e) {
      _logger.w('Cannot load image safely: $e');
      return false;
    }
  }
} 