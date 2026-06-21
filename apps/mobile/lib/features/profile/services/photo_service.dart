import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

/// Uploads profile collage photos to Supabase Storage and registers the
/// resulting public URL with the backend.
///
/// Requires a public Supabase Storage bucket named "user-photos" with
/// per-user write policies — see apps/backend/db/rls_policies.sql.
class PhotoService {
  final ApiClient _api;

  PhotoService(this._api);

  static const _bucket = 'user-photos';

  Future<String> _uploadToStorage(XFile file, {required String prefix}) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(file.path);
    final ext = (extMatch?.group(1) ?? 'jpg').toLowerCase();
    final storagePath = '$userId/$prefix${const Uuid().v4()}.$ext';
    final bytes = await file.readAsBytes();

    await supabase.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );

    return supabase.storage.from(_bucket).getPublicUrl(storagePath);
  }

  Future<Map<String, dynamic>> uploadPhoto(XFile file) async {
    final url = await _uploadToStorage(file, prefix: '');

    final response = await _api.post(ApiEndpoints.myPhotos, body: {'url': url});
    return response['data'] as Map<String, dynamic>;
  }

  /// Uploads already-encoded image bytes (e.g. an edited in-match capture) to
  /// the collage bucket and registers the public URL with the backend. Mirrors
  /// [uploadPhoto] but skips the file round-trip since the editor hands us raw
  /// PNG bytes from a `RepaintBoundary`.
  Future<Map<String, dynamic>> uploadPhotoBytes(
    Uint8List bytes, {
    String ext = 'png',
  }) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    final storagePath = '$userId/${const Uuid().v4()}.$ext';
    await supabase.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
    final url = supabase.storage.from(_bucket).getPublicUrl(storagePath);

    final response = await _api.post(ApiEndpoints.myPhotos, body: {'url': url});
    return response['data'] as Map<String, dynamic>;
  }

  /// Uploads a new profile picture and sets it as the user's avatar.
  Future<void> uploadAvatar(XFile file) async {
    final url = await _uploadToStorage(file, prefix: 'avatar-');
    await _api.patch(ApiEndpoints.me, body: {'avatarUrl': url});
  }

  Future<void> deletePhoto(String id) async {
    await _api.delete(ApiEndpoints.deletePhoto(id));
  }
}
