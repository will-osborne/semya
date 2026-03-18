import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

/// Limits for media uploads to keep storage costs low.
class MediaLimits {
  static const int maxImageBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxVideoBytes = 25 * 1024 * 1024; // 25 MB
  static const Duration maxVideoDuration = Duration(minutes: 3);
  static const double imageMaxDimension = 1920;
  static const int imageQuality = 80;
}

/// Result of picking and preparing a media file for upload.
class PreparedMedia {
  const PreparedMedia({
    required this.file,
    required this.isVideo,
    this.thumbnail,
    this.width,
    this.height,
  });

  final File file;
  final bool isVideo;
  final Uint8List? thumbnail;
  final int? width;
  final int? height;
}

/// Result of uploading media to Firebase Storage.
class MediaUploadResult {
  const MediaUploadResult({
    required this.downloadUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  final String downloadUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
}

class MediaService {
  final ImagePicker _picker = ImagePicker();

  // ---------------------------------------------------------------------------
  // Picking
  // ---------------------------------------------------------------------------

  Future<PreparedMedia?> pickImageFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: MediaLimits.imageMaxDimension,
      maxHeight: MediaLimits.imageMaxDimension,
      imageQuality: MediaLimits.imageQuality,
    );
    if (file == null) return null;
    return _prepareImage(File(file.path));
  }

  Future<PreparedMedia?> pickImageFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: MediaLimits.imageMaxDimension,
      maxHeight: MediaLimits.imageMaxDimension,
      imageQuality: MediaLimits.imageQuality,
    );
    if (file == null) return null;
    return _prepareImage(File(file.path));
  }

  Future<PreparedMedia?> pickVideoFromGallery() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: MediaLimits.maxVideoDuration,
    );
    if (file == null) return null;
    return _prepareVideo(File(file.path));
  }

  Future<PreparedMedia?> pickVideoFromCamera() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: MediaLimits.maxVideoDuration,
    );
    if (file == null) return null;
    return _prepareVideo(File(file.path));
  }

  // ---------------------------------------------------------------------------
  // Preparation
  // ---------------------------------------------------------------------------

  Future<PreparedMedia> _prepareImage(File file) async {
    final decodedImage = await _decodeImage(await file.readAsBytes());
    return PreparedMedia(
      file: file,
      isVideo: false,
      width: decodedImage.width,
      height: decodedImage.height,
    );
  }

  Future<PreparedMedia> _prepareVideo(File rawFile) async {
    final stat = await rawFile.stat();

    File outputFile = rawFile;

    // Compress if over the limit.
    if (stat.size > MediaLimits.maxVideoBytes) {
      final info = await VideoCompress.compressVideo(
        rawFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );
      if (info != null && info.file != null) {
        outputFile = info.file!;
      }
    }

    // Final size check.
    final finalSize = await outputFile.length();
    if (finalSize > MediaLimits.maxVideoBytes) {
      // Try lower quality.
      final info = await VideoCompress.compressVideo(
        rawFile.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );
      if (info != null && info.file != null) {
        outputFile = info.file!;
      }
      final recheck = await outputFile.length();
      if (recheck > MediaLimits.maxVideoBytes) {
        throw MediaTooLargeException(
          'Video is too large (${(recheck / 1024 / 1024).toStringAsFixed(1)} MB). '
          'Maximum is ${MediaLimits.maxVideoBytes ~/ 1024 ~/ 1024} MB.',
        );
      }
    }

    // Generate thumbnail.
    Uint8List? thumbnail;
    int? width;
    int? height;
    try {
      final thumbFile = await VideoCompress.getFileThumbnail(
        rawFile.path,
        quality: 75,
        position: -1, // default frame
      );
      thumbnail = await thumbFile.readAsBytes();
      final decoded = await _decodeImage(thumbnail);
      width = decoded.width;
      height = decoded.height;
    } catch (_) {
      // Thumbnail generation failed — not critical.
    }

    return PreparedMedia(
      file: outputFile,
      isVideo: true,
      thumbnail: thumbnail,
      width: width,
      height: height,
    );
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  Future<MediaUploadResult> uploadMedia({
    required PreparedMedia media,
    required String conversationId,
    required String messageId,
  }) async {
    final storage = FirebaseStorage.instance;
    final ext = media.isVideo ? 'mp4' : 'jpg';
    final contentType = media.isVideo ? 'video/mp4' : 'image/jpeg';
    final storagePath = 'media/$conversationId/$messageId.$ext';

    final ref = storage.ref(storagePath);
    await ref.putFile(
      media.file,
      SettableMetadata(contentType: contentType),
    );
    final downloadUrl = await ref.getDownloadURL();

    // Upload thumbnail for videos.
    String? thumbnailUrl;
    if (media.isVideo && media.thumbnail != null) {
      final thumbPath = 'media/$conversationId/${messageId}_thumb.jpg';
      final thumbRef = storage.ref(thumbPath);
      await thumbRef.putData(
        media.thumbnail!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      thumbnailUrl = await thumbRef.getDownloadURL();
    }

    return MediaUploadResult(
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      width: media.width,
      height: media.height,
    );
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  void dispose() {
    VideoCompress.dispose();
  }
}

class MediaTooLargeException implements Exception {
  const MediaTooLargeException(this.message);
  final String message;

  @override
  String toString() => message;
}
