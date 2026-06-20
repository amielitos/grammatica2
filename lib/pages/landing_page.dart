import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _bgImages = [
    'assets/student_teacher_bg.png',
    'assets/student_teacher_bg2.png',
    'assets/student_teacher_bg3.png',
  ];
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
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.8, curve: Curves.easeOut)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.8, curve: Curves.easeOut)),
    );

    _animController.forward();

    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 50 && _isScrolled) {
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
    final isDesktop = size.width > 900;
    
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: _isScrolled ? Colors.white.withValues(alpha: 0.95) : Colors.transparent,
            boxShadow: _isScrolled 
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))]
              : [],
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _isScrolled ? 10 : 0, sigmaY: _isScrolled ? 10 : 0),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      InkWell(
                        onTap: () {
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        },
                        child: Row(
                          children: [
                            Image.asset('assets/logotext.png', height: 35, errorBuilder: (context, error, stackTrace) => const Icon(Icons.language, color: AppColors.primary, size: 35)),
                          ],
                        ),
                      ),
                      
                      // Nav Actions
                      if (isDesktop)
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/login'),
                              style: TextButton.styleFrom(
                                foregroundColor: _isScrolled ? Colors.black87 : Colors.white,
                                textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              child: const Text('Log In'),
                            ),
                            const SizedBox(width: 20),
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamed(context, '/register'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF81B655),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              child: const Text('Get Started'),
                            ),
                          ],
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.menu, color: _isScrolled ? Colors.black87 : Colors.white),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
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
                                          side: const BorderSide(color: Color(0xFF81B655)),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(isDesktop),
            _buildFeaturesSection(isDesktop),
            _buildHowItWorksSection(isDesktop),
            _buildCTASection(isDesktop),
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      height: isDesktop ? 900 : 800,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Fallback
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image Slideshow
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Image.asset(
              _bgImages[_currentBgIndex],
              key: ValueKey<int>(_currentBgIndex),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.9),
                  const Color(0xFF0F172A).withValues(alpha: 0.6),
                  Colors.transparent,
                  const Color(0xFF0F172A).withValues(alpha: 0.9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
          
          // Additional dark overlay to ensure text readability
          Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),

          // Content
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 80),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Text(
                                  "🌟 Discover the Future of Learning",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            "Master Grammar\nWith Confidence.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 84 : 52,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -2.0,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ]
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700),
                            child: Text(
                              "Join thousands of learners improving their language skills daily with verified educators, interactive quizzes, and community-driven lessons.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: isDesktop ? 22 : 18,
                                height: 1.6,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.pushNamed(context, '/register'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81B655),
                                  foregroundColor: Colors.white,
                                  elevation: 20,
                                  shadowColor: const Color(0xFF81B655).withValues(alpha: 0.6),
                                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 32, vertical: isDesktop ? 24 : 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Start Learning Free', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              OutlinedButton(
                                onPressed: () => Navigator.pushNamed(context, '/login'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 32, vertical: isDesktop ? 24 : 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Log In to Account', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildHeroStats(isDesktop),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem("10k+", "Active Learners", Icons.people_alt_rounded),
              if (isDesktop) _buildDivider(),
              if (isDesktop) _buildStatItem("4.9/5", "User Rating", Icons.star_rounded),
              if (isDesktop) _buildDivider(),
              if (isDesktop) _buildStatItem("500+", "Lessons", Icons.library_books_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF81B655).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF81B655), size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 50,
      width: 1,
      color: Colors.white.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  Widget _buildFeaturesSection(bool isDesktop) {
    final features = [
      {'icon': Icons.library_books, 'title': 'Curated Lessons', 'desc': 'Access hundreds of grammar rules and vocabulary lessons created by experts.'},
      {'icon': Icons.quiz, 'title': 'Interactive Quizzes', 'desc': 'Test your knowledge with dynamic multiple-choice and spelling exercises.'},
      {'icon': Icons.verified, 'title': 'Verified Educators', 'desc': 'Learn only from approved and certified language professionals.'},
      {'icon': Icons.insights, 'title': 'Track Progress', 'desc': 'Visualize your learning streaks and track your mastery over time.'},
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 24, vertical: 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              ScrollReveal(
                child: Text(
                  "WHY CHOOSE US",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF81B655),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    fontSize: 14,
                  )
                ),
              ),
              const SizedBox(height: 16),
              ScrollReveal(
                delay: 100.ms,
                child: Text(
                  "Everything you need to excel",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 48 : 36,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -1.0,
                  )
                ),
              ),
              const SizedBox(height: 80),
              Wrap(
                spacing: 30,
                runSpacing: 30,
                alignment: WrapAlignment.center,
                children: List.generate(features.length, (index) {
                  return ScrollReveal(
                    delay: Duration(milliseconds: 200 + (index * 100)),
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
    return Container(
      width: isDesktop ? 270 : double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 10)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF81B655), Color(0xFF6A9943)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF81B655).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ]
            ),
            child: Icon(f['icon'] as IconData, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 32),
          Text(
            f['title'] as String,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            )
          ),
          const SizedBox(height: 16),
          Text(
            f['desc'] as String,
            style: GoogleFonts.inter(
              height: 1.6,
              color: const Color(0xFF64748B),
              fontSize: 16,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection(bool isDesktop) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 24, vertical: 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              ScrollReveal(
                child: Text(
                  "SIMPLE WORKFLOW",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF81B655),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    fontSize: 14,
                  )
                ),
              ),
              const SizedBox(height: 16),
              ScrollReveal(
                delay: 100.ms,
                child: Text(
                  "How Grammatica Works",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 48 : 36,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -1.0,
                  )
                ),
              ),
              const SizedBox(height: 80),
              isDesktop 
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ScrollReveal(delay: 200.ms, child: _buildStepCard("1", "Create Account", "Sign up in seconds for free as a Learner or an Educator."))),
                      ScrollReveal(delay: 300.ms, slide: false, child: _buildConnector()),
                      Expanded(child: ScrollReveal(delay: 400.ms, child: _buildStepCard("2", "Browse Content", "Read through comprehensive lessons and rules."))),
                      ScrollReveal(delay: 500.ms, slide: false, child: _buildConnector()),
                      Expanded(child: ScrollReveal(delay: 600.ms, child: _buildStepCard("3", "Take Quizzes", "Challenge yourself and earn certificates upon completion."))),
                    ],
                  )
                : Column(
                    children: [
                      ScrollReveal(delay: 200.ms, child: _buildStepCard("1", "Create Account", "Sign up in seconds for free as a Learner or an Educator.")),
                      const SizedBox(height: 50),
                      ScrollReveal(delay: 300.ms, child: _buildStepCard("2", "Browse Content", "Read through comprehensive lessons and rules.")),
                      const SizedBox(height: 50),
                      ScrollReveal(delay: 400.ms, child: _buildStepCard("3", "Take Quizzes", "Challenge yourself and earn certificates upon completion.")),
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
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF81B655).withValues(alpha: 0.2),
                blurRadius: 25,
                offset: const Offset(0, 12),
              )
            ],
            border: Border.all(color: const Color(0xFF81B655), width: 4),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.outfit(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF81B655),
              )
            )
          ),
        ),
        const SizedBox(height: 32),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          )
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              height: 1.6,
              color: const Color(0xFF64748B),
              fontSize: 16,
            )
          ),
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 60,
      height: 4,
      margin: const EdgeInsets.only(top: 45, left: 10, right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE2F3D9),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCTASection(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF81B655), Color(0xFF6A9943)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 24, vertical: 120),
      child: Stack(
        children: [
          // Subtle background pattern or shine could go here
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  ScrollReveal(
                    child: Text(
                      "Ready to master your grammar?",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: isDesktop ? 54 : 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -1.0,
                      )
                    ),
                  ),
                  const SizedBox(height: 24),
                  ScrollReveal(
                    delay: 100.ms,
                    child: Text(
                      "Join our community today and get unlimited access to all verified lessons and interactive quizzes.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.6,
                      )
                    ),
                  ),
                  const SizedBox(height: 48),
                  ScrollReveal(
                    delay: 200.ms,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF81B655),
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 15,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: Text(
                        'Get Started for Free',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        )
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

  Widget _buildFooter(bool isDesktop) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 24, vertical: 80),
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
                      const Icon(Icons.language, color: Colors.white, size: 36),
                      const SizedBox(width: 12),
                      Text(
                        "Grammatica",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        )
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildSocialIcon(Icons.facebook),
                      const SizedBox(width: 16),
                      _buildSocialIcon(Icons.email),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 48),
              Divider(color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "© 2026 Grammatica. All rights reserved.",
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    )
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text("Privacy", style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 14))
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {},
                        child: Text("Terms", style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 14))
                      ),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
    );
  }
}

class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool slide;

  const ScrollReveal({super.key, required this.child, this.delay = Duration.zero, this.slide = true});

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
      child: widget.child.animate(
        target: _isVisible ? 1 : 0,
      )
      .fade(duration: 600.ms, delay: widget.delay)
      .slideY(begin: widget.slide ? 0.2 : 0, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
    );
  }
}
