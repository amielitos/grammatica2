import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/design_ornaments.dart';
import '../services/auth_service.dart';

class OnboardingPage extends StatefulWidget {
  final User user;
  const OnboardingPage({super.key, required this.user});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.justSignedUpWithGoogle) {
        AuthService.justSignedUpWithGoogle = false;
        _showWelcomeModal();
      }
    });
  }

  void _showWelcomeModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF81B655), Color(0xFF5A8E30)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF81B655).withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.stars_rounded, color: Colors.white, size: 52),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Welcome to Grammatica!",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "We've sent your account details to your email. You can use your credentials to login anytime!",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81B655),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      "Let's Explore! 🚀",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      emoji: '🚀',
      pill: 'START ADVENTURE',
      title: 'Level Up Your English!',
      description: 'Step into a modern, gamified world crafted to help you write, speak, and express yourself with crystal clarity.',
      icon: Icons.rocket_launch_rounded,
      accentColor: const Color(0xFF81B655),
      highlightCard: '✨ Gamified & interactive learning paths',
    ),
    OnboardingStep(
      emoji: '📚',
      pill: 'INTERACTIVE LESSONS',
      title: 'Bite-Sized Lessons & AI',
      description: 'Master complex grammar, punctuation, and idioms with interactive visual decks and intelligent AI learning assistants.',
      icon: Icons.auto_stories_rounded,
      accentColor: const Color(0xFF3B82F6),
      highlightCard: '⚡ Flashcards, mind maps & companion guides',
    ),
    OnboardingStep(
      emoji: '🐝',
      pill: 'PRACTICE ARENA',
      title: 'Spelling Bee & Speech Quizzes',
      description: 'Sharpen your ear and voice! Test real-time speech pronunciation and compete in the interactive Spelling Bee challenge.',
      icon: Icons.military_tech_rounded,
      accentColor: const Color(0xFFF59E0B),
      highlightCard: '🎤 Speech recognition & instant scoring',
    ),
    OnboardingStep(
      emoji: '🎓',
      pill: 'VERIFIED EDUCATORS',
      title: 'Learn from Top Teachers',
      description: 'Subscribe to certified educators, book 1-on-1 mentorship sessions, and access premium curated study materials.',
      icon: Icons.school_rounded,
      accentColor: const Color(0xFF8B5CF6),
      highlightCard: '👥 Community hubs & personalized mentoring',
    ),
    OnboardingStep(
      emoji: '🎉',
      pill: 'YOU\'RE READY',
      title: 'Ready to Dominate?',
      description: 'Your learning sanctuary is all set up. Let\'s embark on this exciting linguistic adventure together!',
      icon: Icons.celebration_rounded,
      accentColor: const Color(0xFF10B981),
      highlightCard: '🌟 Jump right into your first module!',
      isLast: true,
    ),
  ];

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'has_completed_onboarding': true});
    } catch (e) {
      debugPrint('Error updating onboarding status: $e');
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLarge = size.width >= 768;
    final currentStep = _steps[_currentPage];

    return Scaffold(
      body: BackgroundWrapper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLarge ? 32 : 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentStep.accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
                        blurRadius: 36,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 28,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.auto_stories_rounded,
                                    color: Color(0xFF81B655),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Grammatica',
                                  style: GoogleFonts.outfit(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: _completeOnboarding,
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              child: Text(
                                'Skip',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Carousel Body
                      SizedBox(
                        height: 430,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemCount: _steps.length,
                          itemBuilder: (context, index) {
                            final step = _steps[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Fun Step Category Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: step.accentColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: step.accentColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(step.emoji, style: const TextStyle(fontSize: 14)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'STEP ${index + 1} OF ${_steps.length} • ${step.pill}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: step.accentColor,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Glowing Themed Icon with pulsating ring effect
                                  Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          step.accentColor,
                                          step.accentColor.withValues(alpha: 0.7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: step.accentColor.withValues(alpha: 0.4),
                                          blurRadius: 28,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        step.icon,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Title
                                  Text(
                                    step.title,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Description
                                  Text(
                                    step.description,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Highlight Feature Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: step.accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      step.highlightCard,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: step.accentColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const Divider(height: 1),

                      // Bottom Navigation Area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Progress dots
                            Row(
                              children: List.generate(
                                _steps.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(right: 8),
                                  height: 8,
                                  width: _currentPage == index ? 28 : 8,
                                  decoration: BoxDecoration(
                                    color: _currentPage == index
                                        ? _steps[_currentPage].accentColor
                                        : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),

                            // Next / Finish Button
                            if (_steps[_currentPage].isLast)
                              FilledButton(
                                onPressed: _isCompleting ? null : _completeOnboarding,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isCompleting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "LET'S GO! 🚀",
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              )
                            else
                              FilledButton(
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.fastOutSlowIn,
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _steps[_currentPage].accentColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Next',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded, size: 16),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String emoji;
  final String pill;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String highlightCard;
  final bool isLast;

  OnboardingStep({
    required this.emoji,
    required this.pill,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.highlightCard,
    this.isLast = false,
  });
}
