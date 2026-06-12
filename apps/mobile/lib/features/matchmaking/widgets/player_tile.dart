import 'package:flutter/material.dart';
import '../../../shared/widgets/line_eye.dart';

/// Standard player row used across matchmaking lists: avatar, name,
/// optional subtitle (record / distance), and a trailing action.
class PlayerTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final Widget? trailing;

  const PlayerTile({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white.withOpacity(0.15),
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        child: avatarUrl == null
            ? Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
      trailing: trailing,
    );
  }
}

/// The standard "Challenge" pill button with the line-art eye icon.
class ChallengeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ChallengeButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Challenge', style: TextStyle(fontSize: 13)),
          SizedBox(width: 6),
          LineEyeIcon(size: 15, color: Colors.black),
        ],
      ),
    );
  }
}
