import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 50 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
            color: _isScrolled
                ? Colors.white.withOpacity(0.95)
                : Colors.transparent,
            boxShadow: _isScrolled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60 : 24,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  InkWell(
                    onTap: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (route) => false,
                      );
                    },
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/logotext.png',
                          height: 35,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.language,
                                color: AppColors.primary,
                                size: 35,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Nav Actions
                  if (isDesktop)
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/login'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black87,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          child: const Text('Log In'),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF81B655),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Get Started'),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black87),
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
      decoration: const BoxDecoration(
        color: Color(0xFFF7FBF4),
        image: DecorationImage(
          image: AssetImage('assets/signinbg.png'),
          fit: BoxFit.cover,
          opacity: 0.15,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 60 : 24,
        isDesktop ? 180 : 140,
        isDesktop ? 60 : 24,
        isDesktop ? 120 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(flex: 5, child: _buildHeroContent(isDesktop)),
                    const SizedBox(width: 60),
                    Expanded(flex: 5, child: _buildHeroImage()),
                  ],
                )
              : Column(
                  children: [
                    _buildHeroContent(isDesktop),
                    const SizedBox(height: 50),
                    _buildHeroImage(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroContent(bool isDesktop) {
    return Column(
      crossAxisAlignment: isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE2F3D9),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            "🌟 The #1 Grammar Learning Platform",
            style: TextStyle(
              color: Color(0xFF5A8E2E),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Master Grammar\nWith Confidence.",
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 64 : 42,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -1.5,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Join thousands of learners improving their language skills daily with verified educators, interactive quizzes, and community-driven lessons.",
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            height: 1.6,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: isDesktop
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81B655),
                foregroundColor: Colors.white,
                elevation: 10,
                shadowColor: const Color(0xFF81B655).withOpacity(0.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Start Learning Free',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: isDesktop
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: const Color(0xFF81B655), size: 20),
            const SizedBox(width: 8),
            const Text(
              "No credit card required",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 20),
            Icon(Icons.check_circle, color: const Color(0xFF81B655), size: 20),
            const SizedBox(width: 8),
            const Text(
              "Verified Content",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    return SizedBox(
      height: 500,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Showcase Image
          Positioned(
            right: 0,
            top: 0,
            bottom: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF81B655).withOpacity(0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=1000&q=80',
                  ), // Professional studying/networking aesthetic
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Floating Badge 1 - Top Left
          Positioned(
            top: 50,
            left: -20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2F3D9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt,
                      color: Color(0xFF81B655),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "10k+",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        "Active Learners",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Floating Badge 2 - Bottom Right
          Positioned(
            bottom: 10,
            right: -20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF81B655), Color(0xFF6A9943)],
                ), // Primary Brand Gradient
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF81B655).withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "4.9/5",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "User Rating",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(bool isDesktop) {
    final features = [
      {
        'icon': Icons.library_books,
        'title': 'Curated Lessons',
        'desc':
            'Access hundreds of grammar rules and vocabulary lessons created by experts.',
      },
      {
        'icon': Icons.quiz,
        'title': 'Interactive Quizzes',
        'desc':
            'Test your knowledge with dynamic multiple-choice and spelling exercises.',
      },
      {
        'icon': Icons.verified,
        'title': 'Verified Educators',
        'desc':
            'Learn only from approved and certified language professionals.',
      },
      {
        'icon': Icons.insights,
        'title': 'Track Progress',
        'desc':
            'Visualize your learning streaks and track your mastery over time.',
      },
    ];

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
              const Text(
                "WHY CHOOSE US",
                style: TextStyle(
                  color: Color(0xFF81B655),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Everything you need to excel",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 60),
              Wrap(
                spacing: 30,
                runSpacing: 30,
                alignment: WrapAlignment.center,
                children: features.map((f) {
                  return Container(
                    width: isDesktop ? 260 : double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2F3D9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            f['icon'] as IconData,
                            color: const Color(0xFF81B655),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          f['title'] as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          f['desc'] as String,
                          style: const TextStyle(
                            height: 1.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorksSection(bool isDesktop) {
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
              const Text(
                "SIMPLE WORKFLOW",
                style: TextStyle(
                  color: Color(0xFF81B655),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "How Grammatica Works",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 80),
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildStepCard(
                            "1",
                            "Create Account",
                            "Sign up in seconds for free as a Learner or an Educator.",
                          ),
                        ),
                        _buildConnector(),
                        Expanded(
                          child: _buildStepCard(
                            "2",
                            "Browse Content",
                            "Read through comprehensive lessons and rules.",
                          ),
                        ),
                        _buildConnector(),
                        Expanded(
                          child: _buildStepCard(
                            "3",
                            "Take Quizzes",
                            "Challenge yourself and earn certificates upon completion.",
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildStepCard(
                          "1",
                          "Create Account",
                          "Sign up in seconds for free as a Learner or an Educator.",
                        ),
                        const SizedBox(height: 30),
                        _buildStepCard(
                          "2",
                          "Browse Content",
                          "Read through comprehensive lessons and rules.",
                        ),
                        const SizedBox(height: 30),
                        _buildStepCard(
                          "3",
                          "Take Quizzes",
                          "Challenge yourself and earn certificates upon completion.",
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
                color: const Color(0xFF81B655).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: const Color(0xFF81B655), width: 3),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF81B655),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.6, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 50,
      height: 3,
      margin: const EdgeInsets.only(top: 40, left: 10, right: 10),
      color: const Color(0xFFE2F3D9),
    );
  }

  Widget _buildCTASection(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF81B655),
        image: DecorationImage(
          image: AssetImage('assets/dashboardbg.png'),
          fit: BoxFit.cover,
          opacity: 0.1,
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
              const Text(
                "Ready to master your grammar?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Join our community today and get unlimited access to all verified lessons and interactive quizzes.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF81B655),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 10,
                  shadowColor: Colors.black.withOpacity(0.2),
                ),
                child: const Text(
                  'Get Started for Free',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 24,
        vertical: 60,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      const Text(
                        "Grammatica",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.facebook, color: Colors.white70),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.email, color: Colors.white70),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "© 2026 Grammatica. All rights reserved.",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "Privacy",
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "Terms",
                          style: TextStyle(color: Colors.white54, fontSize: 13),
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
}
