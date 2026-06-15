import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/audio/background_music.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _auraCtrl;

  late final Animation<double> _avatarFade;
  late final Animation<double> _avatarScale;
  late final Animation<double> _statsFade;
  late final Animation<double> _statsSlide;
  late final Animation<double> _collageFade;
  late final Animation<double> _collageSlide;

  bool _uploading = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _auraCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    _avatarFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _avatarScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _statsFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.25, 0.75, curve: Curves.easeOut),
    );
    _statsSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _collageFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _collageSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _auraCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_uploading) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      await ref.read(photoServiceProvider).uploadPhoto(file);
      ref.invalidate(userPhotosProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
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
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _confirmDeletePhoto(String id) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Remove photo?',
            style: TextStyle(color: colors.foreground)),
        content: Text(
          'This photo will be removed from your collage.',
          style: TextStyle(color: colors.ink(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(photoServiceProvider).deletePhoto(id);
      ref.invalidate(userPhotosProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final photos = ref.watch(userPhotosProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        title: const Text('Profile'),
        actions: [
          const MusicToggleButton(),
          const ThemeToggleButton(),
          TextButton(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/');
            },
            child: Text('Sign out', style: TextStyle(color: colors.ink(0.7))),
          ),
        ],
      ),
      // Primary post-login landing page: profile details up top, start
      // challenge pinned below so it's reachable even while the profile
      // request is still loading.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildProfileBody(profile, photos, colors)),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 36),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.push('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.foreground,
                  foregroundColor: colors.background,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'START CHALLENGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileBody(
    AsyncValue<Map<String, dynamic>> profile,
    AsyncValue<List<dynamic>> photos,
    AppColors colors,
  ) {
    return profile.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colors.foreground)),
      error: (e, _) => Center(
        child: Text(e.toString(), style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (data) {
        final user = data['users'] as Map<String, dynamic>?;
        final stats = data['user_stats'] as Map<String, dynamic>?;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedBuilder(
                animation: _entranceCtrl,
                builder: (_, child) => Opacity(
                  opacity: _avatarFade.value,
                  child: Transform.scale(scale: _avatarScale.value, child: child),
                ),
                child: Row(
                  children: [
                    _AnimatedAvatar(
                      rotation: _auraCtrl,
                      // Drizzle serializes columns with camelCase keys
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
                            (user?['displayName'] ??
                                user?['display_name'] ??
                                user?['username'] ??
                                '') as String,
                            style: TextStyle(
                              color: colors.foreground,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '@${user?['username'] ?? ''}',
                            style: TextStyle(color: colors.ink(0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              if (stats != null)
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, child) => Opacity(
                    opacity: _statsFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _statsSlide.value),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stats',
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatTile(
                              label: 'Wins',
                              value: _toInt(stats['wins']),
                              colors: colors),
                          _StatTile(
                              label: 'Losses',
                              value: _toInt(stats['losses']),
                              colors: colors),
                          _StatTile(
                              label: 'Streak',
                              value: _toInt(stats['currentStreak'] ??
                                  stats['current_streak']),
                              colors: colors),
                          _StatTile(
                              label: 'Best',
                              value: _toInt(stats['longestStreak'] ??
                                  stats['longest_streak']),
                              colors: colors),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _entranceCtrl,
                builder: (_, child) => Opacity(
                  opacity: _collageFade.value,
                  child: Transform.translate(
                    offset: Offset(0, _collageSlide.value),
                    child: child,
                  ),
                ),
                child: _PhotoCollage(
                  photos: photos,
                  uploading: _uploading,
                  onAdd: _pickAndUploadPhoto,
                  onDelete: _confirmDeletePhoto,
                  colors: colors,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _toInt(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
}

// ── Avatar with animated rotating ring + pulse aura ───────────────────────────
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
                backgroundColor: colors.ink(0.07),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? Icon(Icons.person, color: colors.foreground, size: 36)
                    : null,
              ),
            ),
          ),
          // Small "+" badge to set/replace the profile picture
          Positioned(
            right: 4,
            bottom: 4,
            child: Material(
              color: colors.foreground,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: uploading ? null : onAddPhoto,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: uploading
                      ? Padding(
                          padding: const EdgeInsets.all(5),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: colors.background),
                        )
                      : Icon(Icons.add, color: colors.background, size: 16),
                ),
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

    // Pulsing glow behind the avatar
    final pulseT = (math.sin(rotation * math.pi * 2) + 1) / 2;
    canvas.drawCircle(
      center,
      radius + 6 + pulseT * 4,
      Paint()..color = color.withOpacity(0.03 + pulseT * 0.05),
    );

    // Rotating dashed ring
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

// ── Stats with count-up animation ─────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final AppColors colors;

  const _StatTile({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            '$v',
            style: TextStyle(
              color: colors.foreground,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: colors.ink(0.5), fontSize: 12),
        ),
      ],
    );
  }
}

// ── Photo collage ──────────────────────────────────────────────────────────────
class _PhotoCollage extends StatelessWidget {
  final AsyncValue<List<dynamic>> photos;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(String id) onDelete;
  final AppColors colors;

  const _PhotoCollage({
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
        Text(
          'Photos',
          style: TextStyle(
            color: colors.foreground,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hold a photo to remove it.',
          style: TextStyle(color: colors.ink(0.4), fontSize: 12),
        ),
        const SizedBox(height: 16),
        photos.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(
                    color: colors.ink(0.14), strokeWidth: 2)),
          ),
          error: (e, _) => Text(
            'Could not load photos',
            style: TextStyle(color: colors.ink(0.4)),
          ),
          data: (items) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _AddPhotoTile(uploading: uploading, onTap: onAdd, colors: colors);
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

  const _AddPhotoTile({required this.uploading, required this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.ink(0.18)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: uploading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.ink(0.33)),
                )
              : Icon(Icons.add, color: colors.ink(0.5)),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String url;
  final VoidCallback onLongPress;
  final AppColors colors;

  const _PhotoTile({required this.url, required this.onLongPress, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : Container(color: colors.ink(0.06)),
          errorBuilder: (_, __, ___) => Container(
            color: colors.ink(0.06),
            child: Icon(Icons.broken_image, color: colors.ink(0.2)),
          ),
        ),
      ),
    );
  }
}
