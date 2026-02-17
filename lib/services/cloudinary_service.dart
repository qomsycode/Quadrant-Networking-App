import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ==========================================
/// CLOUDINARY SERVICE
/// ==========================================
///
/// This service handles the heavy lifting of media management:
/// 1. Direct Uploads: Uses MultipartRequest to send files to the
///    Cloudinary REST API without requiring a backend.
/// 2. Dynamic Optimization: Automatically injects 'q_auto' (quality) 
///    and 'f_auto' (format) flags into URLs to ensure fast delivery.
/// 3. Responsive Resizing: Provides 'optimizeUrl' to request specific
///    pixel widths from the CDN, preventing mobile devices from 
///    downloading unnecessarily large images.
///
/// CONFIGURATION:
/// ------------------------------------------
/// Relies on .env for 'CLOUDINARY_CLOUD_NAME' and 'CLOUDINARY_UPLOAD_PRESET'.
///
class CloudinaryService {
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'daulovm2u';
  static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'quadrant_upload';

  /// Uploads a file to Cloudinary and returns the secure URL
  /// Returns null if upload fails
  static Future<String?> uploadFile({
    required XFile file,
    String? mediaType, // 'image' or 'video'
  }) async {
    try {
      print('DEBUG: Cloudinary Config:');
      print('Cloud Name: $_cloudName');
      print('Preset: $_uploadPreset');

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/${mediaType ?? 'auto'}/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                await file.readAsBytes(),
                filename: file.name,
              ),
            );

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(responseString);
        String url = jsonMap['secure_url'];
        // Inject optimization parameters into the URL for fast delivery
        // This ensures videos and images are compressed when viewed
        if (url.contains('/upload/')) {
          url = url.replaceFirst('/upload/', '/upload/q_auto,f_auto/');
        }
        return url;
      } else {
        // Enhanced error logging for debugging
        print('❌ Cloudinary Upload Failed');
        print('Status Code: ${response.statusCode}');
        print('Response: $responseString');
        
        // Check for CORS error (typically status 0 or 403)
        if (response.statusCode == 0 || response.statusCode == 403) {
          print('⚠️ POSSIBLE CORS ERROR: Check Cloudinary dashboard CORS settings');
          print('⚠️ Add your domain to Allowed Origins in Cloudinary Security settings');
        }
        
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Cloudinary Service Error: $e');
      print('📍 Stack Trace: $stackTrace');
      print('🔍 This error occurred before receiving a response from Cloudinary');
      print('🔍 Possible causes: Network issue, CORS, or file reading problem');
      return null;
    }
  }
  /// Optimizes Cloudinary URLs for specific display sizes
  /// [width] - Target width in pixels (e.g., 200 for thumbnails, 800 for feeds)
  /// Uses 'f_auto' (format auto) and 'q_auto' (quality auto)
  static String optimizeUrl(String url, {int width = 800}) {
    // Only optimize Cloudinary URLs
    if (!url.contains('cloudinary.com') || !url.contains('/upload/')) {
      return url;
    }

    // If already optimized, don't double-optimize (basic check)
    // We look for the /upload/ segment to inject parameters after it
    if (url.contains('/q_auto')) return url;

    // Inject transformations:
    // f_auto = automatic format (webp/avif)
    // q_auto = automatic quality/compression
    // w_$width = resize to width
    // c_limit = scale down only (don't scale up)
    final transformation = 'f_auto,q_auto,w_$width,c_limit';
    
    return url.replaceFirst('/upload/', '/upload/$transformation/');
  }
}
