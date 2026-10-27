import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();
  bool _isScrolled = false;
  bool _showBackToTop = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Background slideshow (configured from admin site settings, or clean geometric default)
  List<String> _bgImages = [];
  int _currentBgIndex = 0;
  Timer? _bgTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _landingSettingsSub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
          ),
        );

    _animController.forward();

    // Slideshow transition every 6 seconds
    _bgTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _bgImages.isNotEmpty) {
        setState(() {
          _currentBgIndex = (_currentBgIndex + 1) % _bgImages.length;
        });
      }
    });

    // Load & listen to Admin Site Settings for landing page hero slideshow images
    _landingSettingsSub = FirebaseFirestore.instance
        .collection('settings')
        .doc('landing_page')
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data() ?? {};
        final raw = data['hero_images'];
        if (raw is List && raw.isNotEmpty) {
          final customUrls = List<String>.from(raw.whereType<String>())
              .where((url) => url.trim().isNotEmpty)
              .toList();
          if (customUrls.isNotEmpty) {
            setState(() {
              _bgImages = customUrls;
              if (_currentBgIndex >= _bgImages.length) {
                _currentBgIndex = 0;
              }
            });
            return;
          }
        }
      }
      // Fallback if no custom admin images configured
      setState(() {
        _bgImages = [];
        _currentBgIndex = 0;
      });
    }, onError: (err) {
      debugPrint('Error listening to landing settings: $err');
    });

    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      if (offset > 10 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (offset <= 10 && _isScrolled) {
        setState(() => _isScrolled = false);
      }

      final shouldShow = offset > 300;
      if (shouldShow != _showBackToTop) {
        setState(() => _showBackToTop = shouldShow);
      }
    });
  }

  @override
  void dispose() {
    _landingSettingsSub?.cancel();
    _bgTimer?.cancel();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 960;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: _buildNavbar(isDesktop),
      ),
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
              mini: true,
              backgroundColor: const Color(0xFF81B655),
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Back to Top',
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                );
              },
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(isDesktop),
            _buildBannerStrip(isDesktop),
            _buildFeaturesSection(isDesktop),
            _buildHowItWorksSection(isDesktop),
            _buildAboutGrammaticaSection(isDesktop),
            _buildFAQSection(isDesktop),
            _buildCTASection(isDesktop),
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  // ─── NAVBAR ──────────────────────────────────────────────────────────────

  Widget _buildNavbar(bool isDesktop) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isScrolled ? 0.10 : 0.05),
            blurRadius: _isScrolled ? 16 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 60 : 20,
            vertical: 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              InkWell(
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/logotext.png',
                      height: 36,
                      errorBuilder: (ctx, err, st) => Row(
                        children: [
                          Icon(
                            Icons.language_rounded,
                            color: const Color(0xFF81B655),
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Grammatica',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Desktop nav links
              if (isDesktop) ...[
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    textStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Log In'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81B655),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ] else ...[
                // Mobile hamburger
                IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF334155),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/register');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81B655),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                child: const Text('Get Started'),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/login');
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF81B655),
                                  side: const BorderSide(
                                    color: Color(0xFF81B655),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                child: const Text('Log In'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }



  // ─── HERO ─────────────────────────────────────────────────────────────────

  Widget _buildHeroImage(int index) {
    if (_bgImages.isEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
      );
    }
    final safeIndex = index % _bgImages.length;
    final imagePath = _bgImages[safeIndex];
    final isNetwork =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');

    if (isNetwork) {
      return Image.network(
        imagePath,
        key: ValueKey<String>('hero_bg_net_$imagePath'),
        fit: BoxFit.cover,
        alignment: const Alignment(0, 0.35),
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF0F172A),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0F172A),
    );
  }

  Widget _buildHeroSection(bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 680 : 580,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image slideshow (NO photo of solo woman)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1500),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _buildHeroImage(_currentBgIndex),
          ),

          // Dark gradient overlay (stronger on left for text legibility)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0B1120).withValues(alpha: 0.90),
                  const Color(0xFF0B1120).withValues(alpha: 0.78),
                  const Color(0xFF0B1120).withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.40, 0.65, 1.0],
              ),
            ),
          ),
          // Bottom fade
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF0B1120).withValues(alpha: 0.70),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.75, 1.0],
              ),
            ),
          ),

          // Content row
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60 : 20,
                vertical: 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Main hero text
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main headline
                            Text(
                              'Master Grammar\nWith Confidence.',
                              style: GoogleFonts.outfit(
                                fontSize: isDesktop ? 68 : 38,
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                                letterSpacing: -2.0,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Subtitle
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Text(
                                'Join learners improving their language skills daily with verified educators, interactive quizzes, and community-driven lessons.',
                                style: GoogleFonts.inter(
                                  fontSize: isDesktop ? 17 : 15,
                                  height: 1.65,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),

                            const SizedBox(height: 36),

                            // CTA Buttons with Pointer Cursors
                            Wrap(
                              spacing: 14,
                              runSpacing: 12,
                              children: [
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pushNamed(context, '/register'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF81B655),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 32 : 24,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Start Learning Free',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.pushNamed(context, '/login'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 32 : 24,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Log In to Account',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ─── BANNER STRIP (STI "enrollment" style) ─────────────────────────────────

  Widget _buildBannerStrip(bool isDesktop) {
    final bullets = [
      'Free to join as a Learner',
      'Verified Educators only',
      'Interactive Quizzes & Certificates',
      'Real-time Progress Tracking',
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D6A1A), Color(0xFF81B655)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 24,
        vertical: isDesktop ? 40 : 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: heading + bullets
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ENROLLMENT OPEN',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start Learning Today — It\'s Free!',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 32,
                            runSpacing: 10,
                            children: bullets
                                .map((b) => _buildBullet(b))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right: CTA button
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2D6A1A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      child: const Text('Enroll Now | Free'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENROLLMENT OPEN',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start Learning Today\n— It\'s Free!',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...bullets.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildBullet(b),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2D6A1A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Enroll Now | Free'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  // ─── FEATURES SECTION ─────────────────────────────────────────────────────

  Widget _buildFeaturesSection(bool isDesktop) {
    final features = [
      {
        'icon': Icons.library_books_rounded,
        'title': 'Curated Lessons',
        'desc':
            'Access hundreds of grammar rules and vocabulary lessons created by certified experts.',
        'color': const Color(0xFF81B655),
      },
      {
        'icon': Icons.quiz_rounded,
        'title': 'Interactive Quizzes',
        'desc':
            'Test your knowledge with dynamic multiple-choice, spelling, and pronunciation exercises.',
        'color': const Color(0xFF4A90D9),
      },
      {
        'icon': Icons.verified_rounded,
        'title': 'Verified Educators',
        'desc':
            'Learn only from approved and certified language professionals — quality guaranteed.',
        'color': const Color(0xFFF5A623),
      },
      {
        'icon': Icons.insights_rounded,
        'title': 'Track Progress',
        'desc':
            'Visualize your learning streaks, quiz scores, and track your mastery over time.',
        'color': const Color(0xFFE05C5C),
      },
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 24,
        vertical: 100,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              ScrollReveal(
                child: Text(
                  'WHY CHOOSE GRAMMATICA',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF81B655),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ScrollReveal(
                delay: 100.ms,
                child: Text(
                  'Everything You Need to Excel',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 44 : 34,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ScrollReveal(
                delay: 150.ms,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Text(
                    'A complete platform built for learners and educators alike.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1.6,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 64),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: List.generate(features.length, (index) {
                  return ScrollReveal(
                    delay: Duration(milliseconds: 200 + (index * 80)),
                    child: _buildFeatureCard(features[index], isDesktop),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, Object> f, bool isDesktop) {
    final color = f['color'] as Color;
    return Container(
      width: isDesktop ? 265 : double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(f['icon'] as IconData, color: color, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            f['title'] as String,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            f['desc'] as String,
            style: GoogleFonts.inter(
              height: 1.65,
              color: const Color(0xFF64748B),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ─── HOW IT WORKS ─────────────────────────────────────────────────────────

  Widget _buildHowItWorksSection(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 24,
        vertical: 100,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              ScrollReveal(
                child: Text(
                  'SIMPLE WORKFLOW',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF81B655),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ScrollReveal(
                delay: 100.ms,
                child: Text(
                  'How Grammatica Works',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 44 : 34,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(height: 72),
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ScrollReveal(
                            delay: 200.ms,
                            child: _buildStepCard(
                              '1',
                              'Create Account',
                              'Sign up in seconds for free as a Learner or an Educator.',
                            ),
                          ),
                        ),
                        ScrollReveal(
                          delay: 300.ms,
                          slide: false,
                          child: _buildConnector(),
                        ),
                        Expanded(
                          child: ScrollReveal(
                            delay: 400.ms,
                            child: _buildStepCard(
                              '2',
                              'Browse Content',
                              'Read through comprehensive lessons and grammar rules.',
                            ),
                          ),
                        ),
                        ScrollReveal(
                          delay: 500.ms,
                          slide: false,
                          child: _buildConnector(),
                        ),
                        Expanded(
                          child: ScrollReveal(
                            delay: 600.ms,
                            child: _buildStepCard(
                              '3',
                              'Take Quizzes',
                              'Challenge yourself and earn certificates upon completion.',
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        ScrollReveal(
                          delay: 200.ms,
                          child: _buildStepCard(
                            '1',
                            'Create Account',
                            'Sign up in seconds for free as a Learner or an Educator.',
                          ),
                        ),
                        const SizedBox(height: 48),
                        ScrollReveal(
                          delay: 300.ms,
                          child: _buildStepCard(
                            '2',
                            'Browse Content',
                            'Read through comprehensive lessons and grammar rules.',
                          ),
                        ),
                        const SizedBox(height: 48),
                        ScrollReveal(
                          delay: 400.ms,
                          child: _buildStepCard(
                            '3',
                            'Take Quizzes',
                            'Challenge yourself and earn certificates upon completion.',
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(String number, String title, String desc) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF81B655).withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: const Color(0xFF81B655), width: 3),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF81B655),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              height: 1.65,
              color: const Color(0xFF64748B),
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 56,
      height: 3,
      margin: const EdgeInsets.only(top: 38, left: 8, right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDCEDD0),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ─── CTA SECTION ──────────────────────────────────────────────────────────

  Widget _buildCTASection(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D6A1A), Color(0xFF81B655)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 24,
        vertical: 100,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              ScrollReveal(
                child: Text(
                  'Ready to master your grammar?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 52 : 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ScrollReveal(
                delay: 100.ms,
                child: Text(
                  'Join our community today and get unlimited access to all verified lessons and interactive quizzes.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.65,
                  ),
                ),
              ),
              const SizedBox(height: 44),
              ScrollReveal(
                delay: 200.ms,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2D6A1A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Get Started for Free',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
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

  // ─── FOOTER ───────────────────────────────────────────────────────────────

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // ─── ABOUT GRAMMATICA SECTION ──────────────────────────────────────────────

  Widget _buildAboutGrammaticaSection(bool isDesktop) {
    return Container(
      key: _aboutKey,
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 88,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              ScrollReveal(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81B655).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF81B655).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'ABOUT GRAMMATICA',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF5A8E30),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ScrollReveal(
                delay: 80.ms,
                child: Text(
                  'Bridging Traditional Learning with Interactive Mastery',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 40 : 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.8,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ScrollReveal(
                delay: 150.ms,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 920),
                  padding: EdgeInsets.all(isDesktop ? 32 : 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF81B655).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Our project, Grammatica, is a language learning application created to help individuals improve their English proficiency through dynamic grammar challenges challenges and engaging activities. It is designed to make learning more engaging, effective, and accessible by allowing users to practice different aspects of the language. The application not only enhances grammar knowledge but also develops overall communication skills, comprehension, and critical thinking. The project aims to solve the gap between traditional methods of learning English and user engagement, supporting individuals in gaining confidence and mastery of the language.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: isDesktop ? 16 : 14.5,
                          height: 1.75,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showAboutGrammaticaDialog(context),
                            icon: const Icon(Icons.info_outline_rounded, size: 18),
                            label: const Text('Read Full Overview'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF81B655),
                              side: const BorderSide(color: Color(0xFF81B655)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAboutUsDialog(context),
                            icon: const Icon(Icons.people_outline_rounded, size: 18),
                            label: const Text('About Us'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF81B655),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // 3 Core Pillars
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildAboutPillarCard(
                    icon: Icons.bolt_rounded,
                    title: 'Dynamic Challenges',
                    description:
                        'Interactive quizzes, real-time feedback, and adaptive exercises to solidify core grammar rules.',
                    width: isDesktop ? 350 : double.infinity,
                  ),
                  _buildAboutPillarCard(
                    icon: Icons.psychology_rounded,
                    title: 'Critical Thinking',
                    description:
                        'Go beyond rote repetition with exercises designed to boost reading comprehension and analytical skills.',
                    width: isDesktop ? 350 : double.infinity,
                  ),
                  _buildAboutPillarCard(
                    icon: Icons.public_rounded,
                    title: 'Accessible Learning',
                    description:
                        'Empowering learners anywhere, anytime with structured educator playlists and guided community hubs.',
                    width: isDesktop ? 350 : double.infinity,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutPillarCard({
    required IconData icon,
    required String title,
    required String description,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF81B655).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF81B655), size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.55,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FAQ SECTION ──────────────────────────────────────────────────────────

  Widget _buildFAQSection(bool isDesktop) {
    final List<Map<String, String>> faqs = [
      {
        'q': 'What is Grammatica and who is it created for?',
        'a':
            'Grammatica is a dynamic language learning application created to help individuals of all levels improve their English proficiency. It features interactive grammar challenges, verified educator lessons, and engaging activities tailored for learners, students, and educators.',
      },
      {
        'q': 'How does Grammatica bridge the gap with traditional learning?',
        'a':
            'Traditional methods often focus on passive memorization. Grammatica combines dynamic grammar challenges, interactive notebook sessions, instant feedback, and educator-curated playlists to turn theoretical grammar into active, confident communication and critical thinking.',
      },
      {
        'q': 'Can I learn at my own pace with educator playlists?',
        'a':
            'Yes! You can explore curated playlists organized by topics, join interactive conference sessions with educators, review notebook presentations, and track your ongoing learning progress at your own pace.',
      },
      {
        'q': 'How do I access quizzes and practice activities?',
        'a':
            'Simply create a free account or log in. From your dashboard, you can browse all learning hubs, enroll in educator playlists, take interactive quizzes, and join community discussions.',
      },
      {
        'q': 'Is Grammatica accessible on mobile and desktop devices?',
        'a':
            'Yes, Grammatica is fully responsive and designed to deliver a seamless learning experience across modern web browsers on desktops, tablets, and mobile devices.',
      },
    ];

    return Container(
      key: _faqKey,
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 88,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              ScrollReveal(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81B655).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF81B655).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'FAQ',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF5A8E30),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ScrollReveal(
                delay: 80.ms,
                child: Text(
                  'Frequently Asked Questions',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 40 : 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ScrollReveal(
                delay: 140.ms,
                child: Text(
                  'Answers to common questions about using Grammatica for your language journey.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 44),
              ...faqs.map(
                (faq) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _LandingFaqAccordion(
                    question: faq['q']!,
                    answer: faq['a']!,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FOOTER ───────────────────────────────────────────────────────────────

  Widget _buildFooter(bool isDesktop) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 24,
        vertical: 72,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Column
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF81B655),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.language_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Grammatica',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Grammatica is a language learning platform designed to bridge the gap between traditional learning and user engagement with dynamic grammar challenges.',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                    // Navigation / About
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFooterHeading('About'),
                          const SizedBox(height: 16),
                          _buildFooterLink('About Grammatica', () => _showAboutGrammaticaDialog(context)),
                          _buildFooterLink('About Us', () => _showAboutUsDialog(context)),
                        ],
                      ),
                    ),
                    // Support & FAQ
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFooterHeading('Support & FAQ'),
                          const SizedBox(height: 16),
                          _buildFooterLink('FAQ', () => _scrollToKey(_faqKey)),
                        ],
                      ),
                    ),
                    // Legal
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFooterHeading('Legal'),
                          const SizedBox(height: 16),
                          _buildFooterLink('Privacy Policy', () => _showPrivacyPolicyDialog(context)),
                          _buildFooterLink('Terms and Condition', () => _showTermsDialog(context)),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // Mobile layout
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF81B655),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Grammatica',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Grammatica helps individuals improve English proficiency through dynamic challenges and engaging activities.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildFooterHeading('Quick Links'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      children: [
                        _buildFooterLink('About Grammatica', () => _showAboutGrammaticaDialog(context)),
                        _buildFooterLink('About Us', () => _showAboutUsDialog(context)),
                        _buildFooterLink('FAQ', () => _scrollToKey(_faqKey)),
                        _buildFooterLink('Privacy Policy', () => _showPrivacyPolicyDialog(context)),
                        _buildFooterLink('Terms and Condition', () => _showTermsDialog(context)),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 48),
              Divider(color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 24),

              // Bottom copyright & quick legal links
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text(
                    '© 2026 Grammatica. All rights reserved.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _showPrivacyPolicyDialog(context),
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '  •  ',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      InkWell(
                        onTap: () => _showTermsDialog(context),
                        child: Text(
                          'Terms and Condition',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '  •  ',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      InkWell(
                        onTap: () => _scrollToKey(_faqKey),
                        child: Text(
                          'FAQ',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterHeading(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ─── MODAL DIALOGS ────────────────────────────────────────────────────────

  void _showInfoModal({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF81B655).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: const Color(0xFF81B655), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81B655),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAboutGrammaticaDialog(BuildContext context) {
    _showInfoModal(
      context: context,
      title: 'About Grammatica',
      icon: Icons.menu_book_rounded,
      children: [
        Text(
          'Our Project',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Our project, Grammatica, is a language learning application created to help individuals improve their English proficiency through dynamic grammar challenges challenges and engaging activities. It is designed to make learning more engaging, effective, and accessible by allowing users to practice different aspects of the language. The application not only enhances grammar knowledge but also develops overall communication skills, comprehension, and critical thinking. The project aims to solve the gap between traditional methods of learning English and user engagement, supporting individuals in gaining confidence and mastery of the language.',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            height: 1.7,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Specific Objectives',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        _buildBulletPoint('To provide an effective and improved learning method application to strengthen individuals’ grammar efficiency that help them to reduce grammatical errors in writing and communication.'),
        _buildBulletPoint('To develop and implement engaging features within the application that enhance users’ comprehension, retention, and understanding of grammar rules.'),
        _buildBulletPoint('To provide an innovative and engaging learning technology alternative to traditional learning methods.'),
        _buildBulletPoint('To develop exercises that ensure understanding and proper application rather than rote memorization.'),
      ],
    );
  }

  void _showAboutUsDialog(BuildContext context) {
    _showInfoModal(
      context: context,
      title: 'About Us',
      icon: Icons.groups_rounded,
      children: [
        Text(
          'Development Team',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'The developers behind Grammatica:',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        _buildDeveloperTile(
          name: 'Ybañez, Nathalie V.',
          role: 'Project Manager',
          icon: Icons.person_rounded,
          color: const Color(0xFFF59E0B),
        ),
        _buildDeveloperTile(
          name: 'Espeña, Amiel',
          role: 'Programmer Specialist',
          icon: Icons.person_rounded,
          color: const Color(0xFF81B655),
        ),
        _buildDeveloperTile(
          name: 'Sadie, Sophia Beatrice S.',
          role: 'Quality Assurance',
          icon: Icons.person_rounded,
          color: const Color(0xFF3B82F6),
        ),
        _buildDeveloperTile(
          name: 'Fajardo, Juan Paolo',
          role: 'System Analyst',
          icon: Icons.person_rounded,
          color: const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 18),
        Text(
          'Our Mission & Vision',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Our mission is to make high-quality English grammar instruction accessible to every learner regardless of location or background. Through technology, structured lessons, and vibrant community learning, we help users unlock their full communicative potential.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.65,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperTile({
    required String name,
    required String role,
    IconData icon = Icons.person_rounded,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    _showInfoModal(
      context: context,
      title: 'Privacy Policy',
      icon: Icons.privacy_tip_outlined,
      children: [
        Text(
          'Last Updated: 2026',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '1. Information We Collect',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'We collect information you provide directly to us when creating an account, such as your name, email address, user role, and study progress data (quiz results, completed lessons, and notebook activity).',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.6,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '2. How We Use Your Information',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your data is used exclusively to facilitate your learning journey, track your grammar proficiency progress, enable community interactions, and optimize educational resources.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.6,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '3. Data Protection and Security',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'We implement industry-standard encryption, strict access controls, and secure database practices to ensure that your personal information is safeguarded at all times.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.6,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog(BuildContext context) {
    _showInfoModal(
      context: context,
      title: 'Terms and Condition',
      icon: Icons.gavel_rounded,
      children: [
        Text(
          'Last Updated: 2026',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '1. Acceptance of Terms',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'By using Grammatica, you agree to these Terms and Conditions and applicable laws. If you do not agree with any part, please do not use the service.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.6,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '2. Educational Purpose and Content',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Grammatica and its educators provide educational lessons, quizzes, and learning materials. Content is intended for educational purposes and should not be redistributed without permission.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.6,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '3. User Conduct',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Users agree to engage respectfully within community hubs, conferences, and collaborative sessions. Harassment, unauthorized access, or abusive behavior will result in account termination.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.6,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 8),
            child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF81B655)),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ACCORDION FOR FAQ ────────────────────────────────────────────────────

class _LandingFaqAccordion extends StatefulWidget {
  final String question;
  final String answer;

  const _LandingFaqAccordion({
    required this.question,
    required this.answer,
  });

  @override
  State<_LandingFaqAccordion> createState() => _LandingFaqAccordionState();
}

class _LandingFaqAccordionState extends State<_LandingFaqAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isExpanded ? const Color(0xFF81B655) : const Color(0xFFE2E8F0),
          width: _isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          title: Text(
            widget.question,
            style: GoogleFonts.outfit(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          trailing: Icon(
            _isExpanded ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
            color: _isExpanded ? const Color(0xFF81B655) : const Color(0xFF94A3B8),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Text(
                widget.answer,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  height: 1.65,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SCROLL REVEAL WIDGET ─────────────────────────────────────────────────

class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool slide;

  const ScrollReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slide = true,
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.key ?? Key(widget.child.hashCode.toString()),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.1 && !_isVisible) {
          if (mounted) {
            setState(() {
              _isVisible = true;
            });
          }
        }
      },
      child: widget.child
          .animate(target: _isVisible ? 1 : 0)
          .fade(duration: 600.ms, delay: widget.delay)
          .slideY(
            begin: widget.slide ? 0.18 : 0,
            end: 0,
            duration: 600.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}
