import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/app_config.dart';

class CloudinaryService {
  static const int maxFileSizeBytes = 1000000; // 1MB

  /// Uploads an image to Cloudinary using credentials from AppConfig/.env
  /// Returns the secure URL of the uploaded image, or null on failure.
  static Future<String?> uploadImage(
    XFile imageFile, {
    void Function(String message)? onMessage,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.length > maxFileSizeBytes) {
        onMessage?.call('Image is too large. Max 1MB allowed.');
        return null;
      }

      final url = Uri.parse(AppConfig.cloudinaryUploadApiUrl);
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Upload timed out'),
      );

      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData['secure_url'] as String?;
      } else {
        final errorMsg = responseData['error']?['message'] ?? 'Upload failed';
        onMessage?.call('Upload failed: $errorMsg');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      onMessage?.call('Upload failed. Please try again.');
      return null;
    }
  }
}
