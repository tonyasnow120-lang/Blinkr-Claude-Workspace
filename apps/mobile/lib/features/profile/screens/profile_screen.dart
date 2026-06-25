import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ink_enter.dart';
import '../../../shared/widgets/ink_scaffold.dart';
import '../../../shared/widgets/stat_strip.dart';
import '../../../shared/widgets/watching_eye.dart';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _auraCtrl;

  bool _uploadingPrivate = false;
  bool _uploadingPublic = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _auraCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
  }

  @override
  void dispose() {
    _auraCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto({required String visibility}) async {
    final isPrivate = visibility == 'private';
    if (isPrivate ? _uploadingPrivate : _uploadingPublic) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;

    setState(() {
      if (isPrivate) {
        _uploadingPrivate = true;
      } else {
        _uploadingPublic = true;
      }
    });
    try {
      await ref
          .read(photoServiceProvider)
          .uploadPhoto(file, visibility: visibility);
      ref.invalidate(isPrivate ? privatePhotosProvider : publicPhotosProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dark.surfaceRaised,
            content: Text(
              'UPLOAD FAILED.',
              style: AppText.label(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.red,
                letterSpacing: 2,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isPrivate) {
            _uploadingPrivate = false;
          } else {
            _uploadingPublic = false;
          }
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(photoServiceProvider).uploadAvatar(file);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dark.surfaceRaised,
            content: Text(
              'UPLOAD FAILED.',
              style: AppText.label(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.red,
                letterSpacing: 2,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _confirmDeletePhoto(String id,
      {required String visibility}) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'REMOVE PHOTO?',
          style: AppText.label(
            size: 16,
            weight: FontWeight.w700,
            color: colors.foreground,
            letterSpacing: 2,
          ),
        ),
        content: Text(
          'THIS PHOTO WILL BE PERMANENTLY REMOVED.',
          style: AppText.body(size: 13, color: colors.ink(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: AppText.label(
                size: 12,
                weight: FontWeight.w600,
                color: colors.ink(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'REMOVE',
              style: AppText.label(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(photoServiceProvider).deletePhoto(id);
      ref.invalidate(visibility == 'private'
          ? privatePhotosProvider
          : publicPhotosProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dark.surfaceRaised,
            content: Text(
              'FAILED TO REMOVE.',
              style: AppText.label(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.red,
                letterSpacing: 2,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final privatePhotos = ref.watch(privatePhotosProvider);
    final publicPhotos = ref.watch(publicPhotosProvider);
    final colors = context.colors;

    return InkScaffold(
      splatSeed: 55,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back,
                        color: colors.foreground, size: 20),
                  ),
                  Text(
                    'PROFILE',
                    style: AppText.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: colors.foreground,
                      letterSpacing: 3,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MusicToggleButton(),
                      GestureDetector(
                        onTap: () async {
                          await ref.read(authServiceProvider).signOut();
                          if (context.mounted) context.go('/');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text(
                            'OUT',
                            style: AppText.label(
                              size: 11,
                              weight: FontWeight.w600,
                              color: colors.ink(0.45),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _buildBody(
                  profile, privatePhotos, publicPhotos, colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<Map<String, dynamic>> profile,
    AsyncValue<List<dynamic>> privatePhotos,
    AsyncValue<List<dynamic>> publicPhotos,
    AppColors colors,
  ) {
    return profile.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.55,
              child: WatchingEye(
                height: 100,
                color: colors.foreground,
                background: colors.background,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'LOADING...',
              style: AppText.label(
                size: 11,
                weight: FontWeight.w600,
                color: colors.ink(0.4),
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          e.toString(),
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, color: AppColors.red),
        ),
      ),
      data: (data) {
        final user = data['users'] as Map<String, dynamic>?;
        final stats = data['user_stats'] as Map<String, dynamic>?;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Avatar + name
              InkEnter(
                child: Row(
                  children: [
                    _AnimatedAvatar(
                      rotation: _auraCtrl,
                      avatarUrl: (user?['avatarUrl'] ??
                          user?['avatar_url']) as String?,
                      uploading: _uploadingAvatar,
                      onAddPhoto: _pickAndUploadAvatar,
                      colors: colors,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ((user?['displayName'] ??
                                        user?['display_name'] ??
                                        user?['username'] ??
                                        '') as String)
                                .toUpperCase(),
                            style: AppText.display(
                              size: 28,
                              color: colors.foreground,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '@${user?['username'] ?? ''}',
                            style: AppText.label(
                              size: 12,
                              weight: FontWeight.w500,
                              color: colors.ink(0.45),
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stat strip
              if (stats != null)
                InkEnter(
                  delay: const Duration(milliseconds: 80),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: StatStrip(
                      stats: [
                        StatItem(
                            label: 'WINS',
                            value: '${_toInt(stats['wins'])}'),
                        StatItem(
                            label: 'LOSSES',
                            value: '${_toInt(stats['losses'])}'),
                        StatItem(
                            label: 'STREAK',
                            value:
                                '${_toInt(stats['currentStreak'] ?? stats['current_streak'])}'),
                        StatItem(
                            label: 'BEST',
                            value:
                                '${_toInt(stats['longestStreak'] ?? stats['longest_streak'])}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // Private photos — owner only
              InkEnter(
                delay: const Duration(milliseconds: 160),
                child: _PhotoSection(
                  title: 'MY PHOTOS',
                  subtitle: 'ONLY YOU CAN SEE THESE',
                  icon: Icons.lock_outline,
                  photos: privatePhotos,
                  uploading: _uploadingPrivate,
                  onAdd: () =>
                      _pickAndUploadPhoto(visibility: 'private'),
                  onDelete: (id) => _confirmDeletePhoto(id,
                      visibility: 'private'),
                  colors: colors,
                ),
              ),
              const SizedBox(height: 32),

              // Public photos — visible to friends
              InkEnter(
                delay: const Duration(milliseconds: 240),
                child: _PhotoSection(
                  title: 'SHARED PHOTOS',
                  subtitle: 'VISIBLE TO FRIENDS',
                  icon: Icons.people_outline,
                  photos: publicPhotos,
                  uploading: _uploadingPublic,
                  onAdd: () =>
                      _pickAndUploadPhoto(visibility: 'public'),
                  onDelete: (id) => _confirmDeletePhoto(id,
                      visibility: 'public'),
                  colors: colors,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  int _toInt(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
}

// -- Avatar with animated rotating ring + pulse aura -------------------------
class _AnimatedAvatar extends StatelessWidget {
  final Animation<double> rotation;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onAddPhoto;
  final AppColors colors;

  const _AnimatedAvatar({
    required this.rotation,
    this.avatarUrl,
    required this.uploading,
    required this.onAddPhoto,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: rotation,
            builder: (_, child) => CustomPaint(
              painter: _AvatarAuraPainter(
                rotation: rotation.value,
                color: colors.foreground,
              ),
              child: child,
            ),
            child: Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.surfaceInsetDark,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? Icon(Icons.person, color: colors.ink(0.4), size: 36)
                    : null,
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: GestureDetector(
              onTap: uploading ? null : onAddPhoto,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.acid,
                  shape: BoxShape.circle,
                ),
                child: uploading
                    ? const Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.acidInk),
                      )
                    : const Icon(Icons.add,
                        color: AppColors.acidInk, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarAuraPainter extends CustomPainter {
  final double rotation;
  final Color color;

  const _AvatarAuraPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final pulseT = (math.sin(rotation * math.pi * 2) + 1) / 2;
    canvas.drawCircle(
      center,
      radius + 6 + pulseT * 4,
      Paint()..color = color.withOpacity(0.03 + pulseT * 0.05),
    );

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi * 2);
    const dashCount = 28;
    for (int i = 0; i < dashCount; i++) {
      final a = i * (2 * math.pi / dashCount);
      final isMajor = i % 7 == 0;
      ringPaint.color = color.withAlpha(isMajor ? 153 : 38);
      final len = isMajor ? 8.0 : 3.0;
      canvas.drawLine(
        Offset(math.cos(a) * radius, math.sin(a) * radius),
        Offset(math.cos(a) * (radius - len), math.sin(a) * (radius - len)),
        ringPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarAuraPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.color != color;
}

// -- Photo section (reused for private + public) -----------------------------
class _PhotoSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final AsyncValue<List<dynamic>> photos;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(String id) onDelete;
  final AppColors colors;

  const _PhotoSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.photos,
    required this.uploading,
    required this.onAdd,
    required this.onDelete,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(icon, color: AppColors.acid, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppText.label(
                size: 13,
                weight: FontWeight.w700,
                color: colors.foreground,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppText.label(
            size: 10,
            weight: FontWeight.w500,
            color: colors.ink(0.35),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'HOLD A PHOTO TO REMOVE IT.',
          style: AppText.body(size: 11, color: colors.ink(0.3)),
        ),
        const SizedBox(height: 12),
        // Photo grid
        photos.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.acid, strokeWidth: 2),
            ),
          ),
          error: (e, _) => Text(
            'COULD NOT LOAD PHOTOS.',
            style: AppText.body(size: 12, color: colors.ink(0.4)),
          ),
          data: (items) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _AddPhotoTile(
                    uploading: uploading, onTap: onAdd, colors: colors);
              }
              final photo = items[index - 1] as Map<String, dynamic>;
              return _PhotoTile(
                url: photo['url'] as String,
                onLongPress: () => onDelete(photo['id'] as String),
                colors: colors,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final bool uploading;
  final VoidCallback onTap;
  final AppColors colors;

  const _AddPhotoTile(
      {required this.uploading, required this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.acid.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(2),
          color: AppColors.surfaceInsetDark,
        ),
        child: Center(
          child: uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.acid),
                )
              : Icon(Icons.add, color: AppColors.acid.withOpacity(0.6), size: 24),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String url;
  final VoidCallback onLongPress;
  final AppColors colors;

  const _PhotoTile(
      {required this.url, required this.onLongPress, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(color: AppColors.surfaceInsetDark),
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surfaceInsetDark,
            child: Icon(Icons.broken_image, color: colors.ink(0.2)),
          ),
        ),
      ),
    );
  }
}
