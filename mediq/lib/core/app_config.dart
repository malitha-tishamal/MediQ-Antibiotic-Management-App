import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Cloudinary Cloud Name
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME']?.trim() ?? 'dqeptzlsb';

  /// Cloudinary Upload Preset
  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET']?.trim() ?? 'flutter_mediq_upload';

  /// Default Admin Profile Image URL
  static String get defaultAdminProfileUrl =>
      dotenv.env['CLOUDINARY_ADMIN_DEFAULT_URL']?.trim() ??
      'https://res.cloudinary.com/$cloudinaryCloudName/image/upload/v1776579551/admin-default_rloii1.jpg';

  /// Default Pharmacist Profile Image URL
  static String get defaultPharmacistProfileUrl =>
      dotenv.env['CLOUDINARY_PHARMACIST_DEFAULT_URL']?.trim() ??
      'https://res.cloudinary.com/$cloudinaryCloudName/image/upload/v1776579551/pharmizist-default_weoaaq.jpg';

  /// Cloudinary Image Upload API Endpoint
  static String get cloudinaryUploadApiUrl =>
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';
}
