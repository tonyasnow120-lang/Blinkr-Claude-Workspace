import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../matchmaking_error.dart';
import '../matchmaking_service.dart';

/// A device contact matched to a Blinkr user. Display name and photo come
/// from the device; identity comes from the server (matched by hash).
class MatchedContact {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String contactName;

  const MatchedContact({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.contactName,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'contactName': contactName,
      };

  factory MatchedContact.fromJson(Map<String, dynamic> json) => MatchedContact(
        userId: json['userId'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        contactName: json['contactName'] as String,
      );
}

/// Contact discovery (Feature 2).
///
/// Privacy invariants (non-negotiable):
///  - raw phone numbers NEVER leave the device — only SHA-256 hashes of
///    E.164-normalised numbers are sent to the server
///  - raw numbers are never logged or cached; the 24h cache holds only the
///    matched results (which contain no phone data)
///  - the OS permission prompt is only fired after the user has seen the
///    in-app rationale (the screen gates on [hasPermission] first)
class ContactsService {
  final MatchmakingService _api;

  static const _cacheKey = 'contacts_match_cache_v1';
  static const _cacheTtl = Duration(hours: 24);

  ContactsService(this._api);

  Future<bool> hasPermission() => Permission.contacts.isGranted;

  /// Fires the system prompt. Call only after showing the rationale UI.
  Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    if (status.isPermanentlyDenied) {
      throw const MatchmakingPermissionDenied(
        'Contacts access is disabled. Enable it in Settings to find friends.',
      );
    }
    return status.isGranted;
  }

  /// Normalises a contact phone to E.164. Prefers the platform-provided
  /// normalised form (Android supplies E.164 when it can); falls back to
  /// digit-stripping. Numbers without a country code that can't be
  /// normalised are skipped rather than guessed.
  String? _normalize(Phone phone) {
    final normalized = phone.normalizedNumber;
    if (normalized.isNotEmpty && normalized.startsWith('+')) return normalized;
    final digits = phone.number.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+') && digits.length >= 9) return digits;
    if (digits.length >= 11 && !digits.startsWith('0')) return '+$digits';
    return null;
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  /// Reads contacts, hashes numbers on-device, asks the server which are on
  /// Blinkr, and merges in device display names. Results are cached for 24h;
  /// pass [forceRefresh] for the manual refresh button.
  Future<List<MatchedContact>> findFriendsOnBlinkr({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) return cached;
    }

    if (!await hasPermission()) {
      throw const MatchmakingPermissionDenied('Contacts permission not granted.');
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);

    // hash → contact display name (first contact wins on collisions)
    final hashToName = <String, String>{};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final e164 = _normalize(phone);
        if (e164 == null) continue;
        hashToName.putIfAbsent(_sha256(e164), () => contact.displayName);
      }
    }
    if (hashToName.isEmpty) return [];

    final matched = await _api.matchContacts(hashToName.keys.toList());

    final results = <MatchedContact>[];
    for (final user in matched) {
      final hash = user['phoneHash'] as String?;
      results.add(MatchedContact(
        userId: user['id'] as String,
        username: user['username'] as String,
        displayName: user['displayName'] as String?,
        avatarUrl: user['avatarUrl'] as String?,
        contactName: hashToName[hash] ?? user['username'] as String,
      ));
    }
    results.sort((a, b) => a.contactName.compareTo(b.contactName));

    await _writeCache(results);
    return results;
  }

  /// Hashes the user's own number on-device and registers only the hash,
  /// so contacts who have this number can discover them.
  Future<void> registerMyNumber(String e164Number) async {
    final cleaned = e164Number.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(cleaned)) {
      throw const MatchmakingUnknown(
        'Enter your number in international format, e.g. +14155551234.',
      );
    }
    await _api.setPhoneHash(_sha256(cleaned));
  }

  Future<List<MatchedContact>?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.parse(decoded['cachedAt'] as String);
      if (DateTime.now().difference(at) > _cacheTtl) return null;
      return (decoded['results'] as List)
          .cast<Map<String, dynamic>>()
          .map(MatchedContact.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(List<MatchedContact> results) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'cachedAt': DateTime.now().toIso8601String(),
        'results': results.map((r) => r.toJson()).toList(),
      }),
    );
  }
}
