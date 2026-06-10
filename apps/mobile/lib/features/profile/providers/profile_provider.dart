import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/api/api_endpoints.dart';
import '../services/photo_service.dart';

final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.me);
  return response['data'] as Map<String, dynamic>;
});

final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService(ref.watch(apiClientProvider));
});

final userPhotosProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.myPhotos);
  return (response['data'] as List).cast<dynamic>();
});

final myMatchesProvider =
    FutureProvider.family<List<dynamic>, ({int limit, int offset})>(
  (ref, args) async {
    final api = ref.watch(apiClientProvider);
    final response = await api.get(
      ApiEndpoints.myMatches,
      queryParams: {'limit': args.limit, 'offset': args.offset},
    );
    return (response['data'] as List).cast<dynamic>();
  },
);
