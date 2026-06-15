import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

/// Which legal document to display.
enum LegalDocument { terms, privacy }

class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection(this.heading, this.body);
}

const String _lastUpdated = 'Last updated: June 10, 2026';

const List<_LegalSection> _termsSections = [
  _LegalSection(
    '1. ACCEPTANCE OF TERMS',
    'By creating an account or using Blinkr, you agree to these Terms of '
        'Service. If you do not agree, do not use the app. We may update '
        'these terms from time to time; continued use after changes take '
        'effect constitutes acceptance of the revised terms.',
  ),
  _LegalSection(
    '2. THE SERVICE',
    'Blinkr is a real-time staring contest game. Players connect over live '
        'video and compete to see who blinks first. Blink detection runs on '
        'your device using your camera; match results are recorded to your '
        'profile.',
  ),
  _LegalSection(
    '3. ELIGIBILITY',
    'You must be at least 13 years old to use Blinkr. If you are under the '
        'age of majority in your jurisdiction, you may only use Blinkr with '
        'the consent of a parent or guardian.',
  ),
  _LegalSection(
    '4. YOUR ACCOUNT',
    'You are responsible for the activity on your account and for keeping '
        'access to your email account secure, since sign-in links and codes '
        'are delivered there. Choose a username that does not impersonate '
        'others or infringe anyone’s rights. We may reclaim usernames '
        'or suspend accounts that violate these terms.',
  ),
  _LegalSection(
    '5. CONDUCT',
    'During matches your camera feed is visible to your opponent. You agree '
        'not to broadcast content that is unlawful, harassing, hateful, '
        'sexually explicit, or otherwise objectionable, and not to use '
        'Blinkr to record other players. Cheating — including automated '
        'play, modified clients, or interfering with blink detection — is '
        'prohibited.',
  ),
  _LegalSection(
    '6. FAIR PLAY & MATCH RESULTS',
    'Match outcomes are determined by on-device blink detection and '
        'server-side adjudication. Results are final. We may void matches '
        'or adjust records where we detect cheating or technical fault.',
  ),
  _LegalSection(
    '7. INTELLECTUAL PROPERTY',
    'Blinkr, including its design, graphics, and software, is owned by us '
        'and protected by applicable law. We grant you a personal, '
        'non-exclusive, non-transferable license to use the app for its '
        'intended purpose.',
  ),
  _LegalSection(
    '8. TERMINATION',
    'You may stop using Blinkr and request deletion of your account at any '
        'time. We may suspend or terminate accounts that violate these '
        'terms or where required by law.',
  ),
  _LegalSection(
    '9. DISCLAIMERS',
    'Blinkr is provided "as is" without warranties of any kind. We do not '
        'guarantee uninterrupted or error-free service. To the maximum '
        'extent permitted by law, our liability arising from your use of '
        'the app is limited to the amount you paid us (currently nothing).',
  ),
  _LegalSection(
    '10. CONTACT',
    'Questions about these terms can be sent to support@blinkr.app.',
  ),
];

const List<_LegalSection> _privacySections = [
  _LegalSection(
    '1. OVERVIEW',
    'This policy explains what data Blinkr collects, how it is used, and '
        'the choices you have. The short version: blink detection happens '
        'entirely on your device, your camera feed is never recorded, and '
        'we only store what is needed to run the game.',
  ),
  _LegalSection(
    '2. CAMERA & BLINK DETECTION',
    'Blinkr uses your camera to detect blinks during a match. Facial '
        'landmark analysis runs entirely on your device. Raw camera frames '
        'and facial landmark data never leave your phone and are never '
        'stored. The only thing sent to our servers is a blink event — a '
        'timestamp and an eye-openness value — used to decide the match. '
        'No biometric templates or identifiers are created or retained.',
  ),
  _LegalSection(
    '3. LIVE VIDEO',
    'During a match your camera feed is streamed in real time to your '
        'opponent over an encrypted connection. The stream is live only: '
        'it is not recorded and not stored on our servers, and it ends '
        'when the match ends.',
  ),
  _LegalSection(
    '4. WHAT WE COLLECT',
    'Email address — used to sign you in; stored until you delete your '
        'account.\n\n'
        'Username and avatar — your in-game identity; stored until you '
        'delete your account.\n\n'
        'Device push token — used to deliver challenge invites and match '
        'results; refreshed each time you sign in.\n\n'
        'Blink events — timestamp and eye-openness value during a match; '
        'used for adjudication and kept with the match record.\n\n'
        'Win/loss record — used for your stats and leaderboards; stored '
        'until you delete your account.',
  ),
  _LegalSection(
    '5. WHAT WE DO NOT COLLECT',
    'We do not collect your camera footage, facial geometry, contacts, '
        'location, or advertising identifiers, and we do not sell or share '
        'your personal data with third parties for marketing.',
  ),
  _LegalSection(
    '6. SERVICE PROVIDERS',
    'Blinkr runs on infrastructure providers that process data on our '
        'behalf: authentication and database hosting, real-time video '
        'transport, and push notification delivery. These providers '
        'process data only as needed to operate the service.',
  ),
  _LegalSection(
    '7. YOUR RIGHTS',
    'You can request a copy of your data or deletion of your account and '
        'associated data at any time by contacting us. Depending on where '
        'you live, you may have additional rights under laws such as the '
        'GDPR or CCPA, including the rights to access, correct, and erase '
        'your data.',
  ),
  _LegalSection(
    '8. CHILDREN',
    'Blinkr is not directed at children under 13, and we do not knowingly '
        'collect personal data from them. If you believe a child under 13 '
        'has created an account, contact us and we will delete it.',
  ),
  _LegalSection(
    '9. CHANGES',
    'We may update this policy as the app evolves. Material changes will '
        'be announced in the app before they take effect.',
  ),
  _LegalSection(
    '10. CONTACT',
    'Privacy questions and data requests: support@blinkr.app.',
  ),
];

/// Legal document page in the app's typographic style.
/// Public route — reachable from the login screen before sign-in.
class LegalScreen extends StatefulWidget {
  final LegalDocument document;
  const LegalScreen({super.key, required this.document});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _opacity = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTerms = widget.document == LegalDocument.terms;
    final title = isTerms ? 'TERMS OF SERVICE' : 'PRIVACY POLICY';
    final sections = isTerms ? _termsSections : _privacySections;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: TextButton.icon(
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back,
                    color: colors.foreground, size: 16),
                label: Text(
                  'BACK',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colors.ink(0.45),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
              ),
            ),
            Expanded(
              child: FadeTransition(
                opacity: _opacity,
                child: SlideTransition(
                  position: _slide,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(36, 16, 36, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: colors.foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _lastUpdated,
                          style: TextStyle(
                            color: colors.ink(0.3),
                            fontSize: 9,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 32),
                        for (final section in sections) ...[
                          Text(
                            section.heading,
                            style: TextStyle(
                              color: colors.foreground,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            section.body,
                            style: TextStyle(
                              color: colors.ink(150 / 255),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w300,
                              height: 1.65,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
