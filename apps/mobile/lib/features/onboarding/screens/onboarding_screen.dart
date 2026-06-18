import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

const _onboardingSeenKey = 'onboarding_seen';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingSeenKey) ?? false;
}

class OnboardingScreen extends StatefulWidget {
  final String nextRoute;
  const OnboardingScreen({super.key, required this.nextRoute});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  late final AnimationController _entranceCtrl;
  late final Animation<double> _contentOpacity;
  late final Animation<double> _contentSlide;

  int _currentPage = 0;

  static const _pages = <_PageData>[
    _PageData(
      icon: Icons.visibility_outlined,
      title: 'STARE DOWN',
      subtitle: 'REAL-TIME BLINK DETECTION',
      body:
          'Challenge opponents to a live staring contest. '
          'Your camera tracks blinks in real time — first '
          'to blink loses.',
    ),
    _PageData(
      icon: Icons.bolt_outlined,
      title: 'CHALLENGE',
      subtitle: 'INVITE ANYONE, ANYWHERE',
      body:
          'Send a link, share a code, or scan a QR to '
          'start a match instantly. No friend request '
          'required.',
    ),
    _PageData(
      icon: Icons.people_outline,
      title: 'FIND PLAYERS',
      subtitle: 'FRIENDS · CONTACTS · NEARBY',
      body:
          'Browse your friends list, discover opponents '
          'from your contacts, or find players nearby '
          'on the map.',
    ),
    _PageData(
      icon: Icons.emoji_events_outlined,
      title: 'CLIMB THE RANKS',
      subtitle: 'WINS · STREAKS · STATS',
      body:
          'Track your record, build win streaks, and '
          'prove you have the steadiest eyes in the game.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _contentSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    if (mounted) context.go(widget.nextRoute);
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _entranceCtrl,
          builder: (_, child) => Opacity(
            opacity: _contentOpacity.value,
            child: Transform.translate(
              offset: Offset(0, _contentSlide.value),
              child: child,
            ),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: TextButton(
                    onPressed: _complete,
                    child: Text(
                      'SKIP',
                      style: TextStyle(
                        color: colors.ink(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _FeaturePage(data: _pages[i]),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: active ? 24 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: active
                            ? colors.foreground
                            : colors.ink(0.18),
                      ),
                    );
                  }),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 36),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.foreground,
                      foregroundColor: colors.background,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        isLast ? 'GET STARTED' : 'NEXT',
                        key: ValueKey(isLast),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;

  const _PageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });
}

class _FeaturePage extends StatelessWidget {
  final _PageData data;
  const _FeaturePage({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.ink(0.12), width: 1),
            ),
            child: Icon(data.icon, size: 40, color: colors.foreground),
          ),

          const SizedBox(height: 48),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 26,
              fontWeight: FontWeight.w200,
              letterSpacing: 10,
            ),
          ),

          const SizedBox(height: 14),

          Container(width: 32, height: 0.5, color: colors.ink(0.25)),

          const SizedBox(height: 14),

          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.ink(0.55),
              fontSize: 9.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 4,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            data.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.ink(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w300,
              height: 1.6,
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
