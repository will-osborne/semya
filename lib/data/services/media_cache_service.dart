import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caches downloaded media files (images, videos) locally to avoid
/// re-downloading on every view. Uses a dedicated cache with a 7-day
/// max age and 200-file cap to keep disk usage reasonable.
class MediaCacheService {
  MediaCacheService()
    : _cacheManager = CacheManager(
        Config(
          'semya_media_cache',
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 200,
        ),
      );

  final CacheManager _cacheManager;

  /// Returns a cached [File] for the given [url]. Downloads the file
  /// if it is not already cached.
  Future<File> getFile(String url) async {
    final fileInfo = await _cacheManager.getFileFromCache(url);
    if (fileInfo != null) return fileInfo.file;

    final downloaded = await _cacheManager.getSingleFile(url);
    return downloaded;
  }

  /// Returns a cached [File] if available, otherwise `null`.
  Future<File?> getCachedFile(String url) async {
    final fileInfo = await _cacheManager.getFileFromCache(url);
    return fileInfo?.file;
  }

  /// Downloads and caches a file, returning a stream of download progress
  /// (0.0 to 1.0) and the final [File].
  Stream<FileResponse> getFileStream(String url) {
    return _cacheManager.getFileStream(url, withProgress: true);
  }

  /// Removes a specific file from the cache.
  Future<void> removeFile(String url) async {
    await _cacheManager.removeFile(url);
  }

  /// Clears the entire media cache.
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  void dispose() {
    _cacheManager.dispose();
  }
}
