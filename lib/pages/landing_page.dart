import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _bgImages = ['assets/hero_bg2.png', 'assets/people4.png'];
  int _currentBgIndex = 0;
  Timer? _bgTimer;

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

    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 10 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });

    _bgTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _currentBgIndex = (_currentBgIndex + 1) % _bgImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
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
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(isDesktop),
            _buildBannerStrip(isDesktop),
            _buildFeaturesSection(isDesktop),
            _buildHowItWorksSection(isDesktop),
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
                _buildNavLink('Features', () {}, isDesktop),
                const SizedBox(width: 4),
                _buildNavLink('How It Works', () {}, isDesktop),
                const SizedBox(width: 28),
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

  Widget _buildNavLink(String label, VoidCallback onTap, bool isDesktop) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF64748B),
        textStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label),
    );
  }

  // ─── HERO ─────────────────────────────────────────────────────────────────

  Widget _buildHeroSection(bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 680 : 560,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image slideshow
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1500),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Image.asset(
              _bgImages[_currentBgIndex],
              key: ValueKey<int>(_currentBgIndex),
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.35),
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Dark gradient overlay (stronger on left for text legibility)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0B1120).withValues(alpha: 0.88),
                  const Color(0xFF0B1120).withValues(alpha: 0.75),
                  const Color(0xFF0B1120).withValues(alpha: 0.40),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.35, 0.60, 1.0],
              ),
            ),
          ),
          // Bottom fade
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF0B1120).withValues(alpha: 0.65),
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
                horizontal: isDesktop ? 60 : 24,
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
                                fontSize: isDesktop ? 68 : 42,
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                                letterSpacing: -2.0,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Subtitle
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 500),
                              child: Text(
                                'Join learners improving their language skills daily with verified educators, interactive quizzes, and community-driven lessons.',
                                style: GoogleFonts.inter(
                                  fontSize: isDesktop ? 17 : 15,
                                  height: 1.65,
                                  color: Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                            ),

                            const SizedBox(height: 36),

                            // CTA Buttons
                            Wrap(
                              spacing: 14,
                              runSpacing: 12,
                              children: [
                                ElevatedButton(
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
                                OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/login'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
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
                              ],
                            ),

                            const SizedBox(height: 40),

                            // Stats row
                            _buildHeroStats(isDesktop),
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

  Widget _buildHeroStats(bool isDesktop) {
    return Wrap(spacing: 24, runSpacing: 12);
  }

  Widget _buildStatChip(String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 20),
        Container(
          width: 1,
          height: 18,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Grammatica',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildSocialIcon(Icons.facebook_rounded),
                      const SizedBox(width: 12),
                      _buildSocialIcon(Icons.email_rounded),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© 2026 Grammatica. All rights reserved.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Privacy',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Terms',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.4),
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

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
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
