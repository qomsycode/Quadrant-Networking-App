import 'dart:async';
import 'dart:js_interop'; 
import 'package:web/web.dart' as web;

/// ==========================================
/// CLOUDINARY WIDGET SERVICE (JS Interop)
/// ==========================================
///
/// This service provides a Dart interface to the official Cloudinary 
/// JavaScript Upload Widget.
///
/// WHY JS INTEROP?
/// ------------------------------------------
/// Cloudinary's official upload widget is a browser-based tool. To 
/// use it in Flutter Web (especially with WASM), we must:
/// 1. Use 'dart:js_interop' to bridge Dart and JavaScript.
/// 2. Poll for results from the window-level JS listener.
///
/// ADVANTAGES:
/// ------------------------------------------
/// - Multi-File Support: Handles selective file uploads natively.
/// - Platform Consistency: Works reliably on mobile browsers where
///   standard file pickers often fail due to CORS.
/// - Security: Handles signatures and presets securely via JS.
///
@JS('triggerCloudinaryUpload')
external void _triggerCloudinaryUpload(JSString mediaType);

@JS('isCloudinaryDone')
external bool _isCloudinaryDone();

@JS('getCloudinaryResult')
external JSString? _getCloudinaryResult();

class CloudinaryWidgetService {
  /// Opens the Cloudinary Upload Widget and returns the secure URL of the
  /// uploaded file, or `null` if the user cancelled or an error occurred.
  static Future<String?> uploadFile({String? mediaType}) async {
    try {
      print('🎨 Opening Cloudinary Upload Widget (WASM/JS)...');

      // Call the JS function defined in index.html
      _triggerCloudinaryUpload((mediaType ?? 'auto').toJS);

      // Poll for result
      String? result;
      while (true) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        final done = _isCloudinaryDone();
        if (done) {
          result = _getCloudinaryResult()?.toDart;
          break;
        }
      }

      // Parse the result
      if (result == null || result == 'CANCELLED') {
        print('🚫 Upload cancelled or no result');
        return null;
      }
      
      if (result.startsWith('ERROR:')) {
        print('❌ Upload error: ${result.substring(6)}');
        return null;
      }

      // It's a URL
      print('✅ Upload successful: $result');
      return result;
    } catch (e, stackTrace) {
      print('❌ Cloudinary Widget Service Error: $e');
      print('📍 Stack Trace: $stackTrace');
      return null;
    }
  }
}
