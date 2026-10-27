import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/email_validator_service.dart';

import 'package:flutter/services.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/design_ornaments.dart';

import '../widgets/top_nav_bar.dart';
import 'otp_verification_page.dart';
import '../services/notification_service.dart';
import '../widgets/tagline_hero_text.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _pageController = PageController();
  int _currentStep = 0;

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // Role Selection
  String _selectedRole = 'learner'; // 'learner' or 'validator'

  // Step 1 Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  String? _selectedSuffix;
  final List<String> _suffixes = ['None', 'Jr.', 'Sr.', 'III', 'IV', 'V'];

  // Step 2 Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEmailTaken = false;
  bool _isInvalidDomain = false;
  bool _isValidatingEmail = false;

  // Step 3 Controllers
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;
  DateTime? _selectedDate;
  bool _agreedToTerms = false;
  bool _hasScrolledToBottom = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmailRealTime);
    _authSubscription = AuthService.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        final isGoogleUser = user.providerData.any(
          (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
        );
        if (isGoogleUser) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  void _validateEmailRealTime() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _isEmailTaken = false;
        _isInvalidDomain = false;
      });
      return;
    }

    if (!EmailValidatorService.isAllowedEmail(email)) {
      setState(() {
        _isInvalidDomain = true;
        _isEmailTaken = false;
        _isValidatingEmail = false;
      });
      return;
    } else {
      if (_isInvalidDomain) {
        setState(() => _isInvalidDomain = false);
      }
    }

    setState(() => _isValidatingEmail = true);
    final taken = await AuthService.instance.isEmailTaken(email);
    if (mounted) {
      setState(() {
        _isEmailTaken = taken;
        _isValidatingEmail = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime maxAllowedDate = DateTime(2014, 12, 31);
    DateTime defaultInitDate = DateTime(2005, 1, 1);
    if (_selectedDate != null) {
      defaultInitDate = _selectedDate!.isAfter(maxAllowedDate) ? maxAllowedDate : _selectedDate!;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: defaultInitDate,
      firstDate: DateTime(1900),
      lastDate: maxAllowedDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF81B655),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.month}/${picked.day}/${picked.year}";
      });
    }
  }

  bool _hasMinLength(String p) => p.length >= 8;
  bool _hasUppercase(String p) => p.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String p) => p.contains(RegExp(r'[a-z]'));
  bool _hasDigit(String p) => p.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String p) => p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>~_\-+=]'));

  String _getPasswordStrength() {
    String pass = _passwordController.text;
    if (pass.isEmpty) return "";
    int score = 0;
    if (_hasMinLength(pass)) score++;
    if (_hasUppercase(pass)) score++;
    if (_hasLowercase(pass)) score++;
    if (_hasDigit(pass)) score++;
    if (_hasSpecial(pass)) score++;

    if (score == 5) return "Strong";
    if (score >= 3) return "Medium";
    return "Weak";
  }

  Color _getStrengthColor() {
    String strength = _getPasswordStrength();
    if (strength == "Strong") return const Color(0xFF16A34A);
    if (strength == "Medium") return Colors.orange;
    if (strength.contains("Weak")) return Colors.red;
    return Colors.grey;
  }

  void _showTermsModal() {
    final scrollController = ScrollController();
    _hasScrolledToBottom = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            scrollController.addListener(() {
              if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 10) {
                if (!_hasScrolledToBottom) {
                  setModalState(() => _hasScrolledToBottom = true);
                  setState(() => _agreedToTerms = true);
                }
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Terms & Privacy Policy", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Terms of Service", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              SizedBox(height: 8),
                              Text("Welcome to Grammatica. By using our services, you agree to these terms. Please read them carefully. We provide an educational platform for grammar learning. You are responsible for maintaining the confidentiality of your account..."),
                              SizedBox(height: 16),
                              Text("Privacy Policy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              SizedBox(height: 8),
                              Text("We value your privacy. We collect information to provide better services to our users. This includes your name, email, and progress data. We do not sell your data to third parties..."),
                              SizedBox(height: 400, child: Center(child: Text("Scroll down to accept terms...", style: TextStyle(color: Colors.grey)))),
                              Text("End of Document", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("Thank you for choosing Grammatica! Now you can proceed."),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: _hasScrolledToBottom ? (val) => setModalState(() => _agreedToTerms = val!) : null,
                          activeColor: const Color(0xFF81B655),
                        ),
                        const Expanded(child: Text("I have read and agree to the terms.")),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_hasScrolledToBottom ? "Accept & Close" : "Close", style: TextStyle(color: _hasScrolledToBottom ? const Color(0xFF81B655) : Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    if (!EmailValidatorService.isAllowedEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only @gmail.com, @yahoo.com, and @hotmail.com emails are accepted.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isInvalidDomain = true);
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please read and agree to the Terms')));
      return;
    }
    if (!_formKey3.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final first = _firstNameController.text.trim();
      final middle = _middleNameController.text.trim();
      final last = _lastNameController.text.trim();
      String fullName = first;
      if (middle.isNotEmpty) fullName += " $middle";
      if (last.isNotEmpty) fullName += " $last";
      if (_selectedSuffix != null && _selectedSuffix != 'None') fullName += " $_selectedSuffix";

      // Register directly via Firebase Authentication
      final cred = await AuthService.instance.registerWithEmailPassword(
        email: email,
        password: _passwordController.text,
        fullName: fullName,
        phoneNumber: '',
        dateOfBirth: _selectedDate ?? DateTime.now(),
        role: _selectedRole,
      );

      final user = cred.user;
      if (user != null) {
        await NotificationService.instance.sendWelcomeNotification(user.uid);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(
              email: email,
              fullName: fullName,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Registration failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKey1.currentState!.validate()) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } else if (_currentStep == 1) {
      final email = _emailController.text.trim();
      if (!EmailValidatorService.isAllowedEmail(email)) {
        setState(() => _isInvalidDomain = true);
        _formKey2.currentState?.validate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only @gmail.com, @yahoo.com, and @hotmail.com emails are accepted.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_formKey2.currentState!.validate() && !_isEmailTaken && !_isValidatingEmail && !_isInvalidDomain) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.instance.googleSignIn();
      // Now that sign-up/sign-in is successful, pop this page so the AuthWrapper in main.dart
      // can show the dashboard.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign-Up failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const PreferredSize(preferredSize: Size.fromHeight(80), child: TopNavBar()),
      body: BackgroundWrapper(
        imageAssetPath: 'assets/signinbgs.png',
        child: LayoutBuilder(builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 800;
          
          final authCard = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08), blurRadius: 24, offset: const Offset(0, 12)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(isDark),
                  _buildProgress(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _getStepHeight(),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (idx) => setState(() => _currentStep = idx),
                      children: [
                        _buildStep1(),
                        _buildStep2(),
                        _buildStep3(),
                      ],
                    ),
                  ),
                  _buildFooter(isDark),
                ],
              ),
            ),
          );

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: isLargeScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: TaglineHeroText(title: 'Join Today!'),
                        ),
                        const SizedBox(width: 40),
                        authCard,
                      ],
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: authCard,
                    ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      padding: const EdgeInsets.only(top: 32, bottom: 16, left: 32, right: 32),
      child: Column(
        children: [
          Image.asset(
            'assets/logotext.png',
            height: 38,
            errorBuilder: (ctx, err, st) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  color: Color(0xFF81B655),
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  'Grammatica',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Create Account",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = ["Personal Info", "Contact", "Security"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          if (index % 2 != 0) {
            int stepIndex = index ~/ 2;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
                color: stepIndex < _currentStep ? const Color(0xFF81B655) : (isDark ? Colors.white12 : Colors.grey[200]),
              ),
            );
          }
          int stepIndex = index ~/ 2;
          bool isActive = stepIndex <= _currentStep;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF81B655) : (isDark ? const Color(0xFF334155) : Colors.grey[200]),
                  shape: BoxShape.circle,
                  boxShadow: isActive ? [BoxShadow(color: const Color(0xFF81B655).withValues(alpha: 0.3), blurRadius: 8)] : [],
                ),
                child: Center(
                  child: Text("${stepIndex + 1}", style: TextStyle(color: isActive ? Colors.white : (isDark ? Colors.white38 : Colors.grey), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[stepIndex], style: TextStyle(fontSize: 11, color: isActive ? const Color(0xFF81B655) : (isDark ? Colors.white54 : Colors.grey), fontWeight: FontWeight.bold)),
            ],
          );
        }),
      ),
    );
  }

  double _getStepHeight() {
    switch (_currentStep) {
      case 0:
        return _selectedRole == 'validator' ? 490 : 470;
      case 1:
        return 190;
      case 2:
        return 530;
      default:
        return 470;
    }
  }

  Widget _buildStep1() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Register As", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'learner'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'learner'
                            ? const Color(0xFF81B655).withValues(alpha: 0.12)
                            : (isDark ? Colors.white10 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRole == 'learner' ? const Color(0xFF81B655) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school_rounded, size: 20, color: _selectedRole == 'learner' ? const Color(0xFF81B655) : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Learner',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedRole == 'learner' ? const Color(0xFF81B655) : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'validator'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'validator'
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                            : (isDark ? Colors.white10 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRole == 'validator' ? const Color(0xFF3B82F6) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_rounded, size: 20, color: _selectedRole == 'validator' ? const Color(0xFF3B82F6) : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Validator',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedRole == 'validator' ? const Color(0xFF3B82F6) : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedRole == 'validator') ...[
              const SizedBox(height: 6),
              Text(
                'Note: Validators must upload a PRC Teacher Certificate after account setup.',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade400, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 16),
            Text("Personal Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _firstNameController,
              hintText: 'First Name *',
              prefixIcon: const Icon(Icons.person_outline),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
                _CapitalizerFormatter(),
              ],
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter first name';
                if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(val)) return 'Only letters allowed';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _middleNameController,
              hintText: 'Middle Name (Optional)',
              prefixIcon: const Icon(Icons.person_outline),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
                _CapitalizerFormatter(),
              ],
              validator: (val) {
                if (val != null && val.isNotEmpty && !RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(val)) {
                  return 'Only letters allowed';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _lastNameController,
              hintText: 'Last Name *',
              prefixIcon: const Icon(Icons.person_outline),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
                _CapitalizerFormatter(),
              ],
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter last name';
                if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(val)) return 'Only letters allowed';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildDropdownField(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _dobController,
              hintText: 'Date of Birth (2014 or earlier) *',
              prefixIcon: const Icon(Icons.calendar_month_outlined),
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Select date of birth';
                if (_selectedDate != null && _selectedDate!.isAfter(DateTime(2014, 12, 31))) {
                  return 'Must be born in 2014 or earlier (minimum 12 years old)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailTooltip = _isEmailTaken
        ? 'This email has already been taken'
        : (_isInvalidDomain ? 'Only @gmail.com, @yahoo.com, and @hotmail.com are allowed' : '');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                text: "Account Email",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
                children: const [
                  TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Tooltip(
              message: emailTooltip,
              child: _buildTextField(
                controller: _emailController,
                hintText: 'Email Address *',
                prefixIcon: const Icon(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter email';
                  final clean = val.trim();
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(clean)) return 'Enter valid email';
                  if (!EmailValidatorService.isAllowedEmail(clean) || _isInvalidDomain) {
                    return 'Only @gmail.com, @yahoo.com, and @hotmail.com are allowed';
                  }
                  if (_isEmailTaken) return 'This email has already been taken';
                  return null;
                },
                onChanged: (val) => _validateEmailRealTime(),
                suffixIcon: _isValidatingEmail 
                  ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                  : _isInvalidDomain
                    ? const Tooltip(message: 'Only @gmail.com, @yahoo.com, and @hotmail.com allowed', child: Icon(Icons.block_rounded, color: Colors.red))
                    : _isEmailTaken
                        ? const Tooltip(message: 'This email has already been taken', child: Icon(Icons.error_outline, color: Colors.red))
                        : null,
              ),
            ),
            if (_isEmailTaken) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'This email has already been taken',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isInvalidDomain) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Only @gmail.com, @yahoo.com, and @hotmail.com are allowed',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordRequirementItem(String text, bool met, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? const Color(0xFF16A34A) : (isDark ? Colors.white38 : Colors.grey[400]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: met ? FontWeight.w600 : FontWeight.normal,
                color: met
                    ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                    : (isDark ? Colors.white60 : Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pass = _passwordController.text;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Security", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              hintText: 'Password *',
              obscureText: _obscurePassword,
              onChanged: (v) => setState(() {}),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF81B655),
                  size: 22,
                ),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Password is required';
                if (!_hasMinLength(val)) return 'At least 8 characters required';
                if (!_hasUppercase(val)) return 'At least 1 uppercase letter required';
                if (!_hasLowercase(val)) return 'At least 1 lowercase letter required';
                if (!_hasDigit(val)) return 'At least 1 number required';
                if (!_hasSpecial(val)) return 'At least 1 special character required';
                return null;
              },
            ),
            if (pass.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text("Strength: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                  Text(_getPasswordStrength(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStrengthColor())),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Password Requirements Guidance Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF81B655)),
                      const SizedBox(width: 6),
                      Text(
                        "Password Requirements",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordRequirementItem("At least 8 characters", _hasMinLength(pass), isDark),
                  _buildPasswordRequirementItem("At least 1 uppercase letter (A-Z)", _hasUppercase(pass), isDark),
                  _buildPasswordRequirementItem("At least 1 lowercase letter (a-z)", _hasLowercase(pass), isDark),
                  _buildPasswordRequirementItem("At least 1 number (0-9)", _hasDigit(pass), isDark),
                  _buildPasswordRequirementItem("At least 1 special character", _hasSpecial(pass), isDark),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Allowed special characters: ! @ # \$ % ^ & * ( ) , . ? \" : { } | < > ~ _ - + =",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _confirmPasswordController,
              hintText: 'Confirm Password *',
              obscureText: _obscureConfirmPassword,
              onChanged: (v) => setState(() {}),
              prefixIcon: const Icon(Icons.lock_reset),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF81B655),
                  size: 22,
                ),
                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (val) => (val != _passwordController.text) ? 'Passwords do not match' : null,
            ),
            if (_confirmPasswordController.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _passwordController.text == _confirmPasswordController.text ? "✓ Passwords match" : "✗ Passwords do not match",
                style: TextStyle(fontSize: 12, color: _passwordController.text == _confirmPasswordController.text ? Colors.green : Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _agreedToTerms,
                  onChanged: (v) => _showTermsModal(),
                  activeColor: const Color(0xFF81B655),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _showTermsModal,
                    child: const Text(
                      "Terms & Conditions and Privacy Policy",
                      style: TextStyle(fontSize: 12, decoration: TextDecoration.underline, color: Color(0xFF75A94B), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.only(right: 12),
                    child: OutlinedButton(
                      onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF81B655), width: 1.5),
                      ),
                      child: const Text("Back", style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(colors: [Color(0xFF81B655), Color(0xFF75A94B)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF81B655).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_currentStep == 2 ? _register : _nextStep),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_currentStep == 2 ? "Finish" : "Next", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),
          GoogleSignInButton(
            onPressed: _isLoading ? () {} : _signUpWithGoogle,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Already have an account? ", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Text("Sign In", style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Or continue with",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRequired = hintText.trim().endsWith('*');
    final String cleanHint = isRequired
        ? hintText.replaceAll(RegExp(r'\s*\*'), '').trim()
        : hintText;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 4))],
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: TextFormField(
        inputFormatters: inputFormatters,
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          label: isRequired
              ? Text.rich(
                  TextSpan(
                    text: cleanHint,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    children: const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          hintText: isRequired ? null : cleanHint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black45,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          prefixIcon: IconTheme(data: IconThemeData(color: isDark ? Colors.white60 : Colors.black45), child: prefixIcon),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedSuffix,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
          hint: Text(
            "Suffix (Optional)",
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black45,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          items: _suffixes.map((s) {
            return DropdownMenuItem<String>(
              value: s,
              child: Text(
                s,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedSuffix = val),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.removeListener(_validateEmailRealTime);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

class _CapitalizerFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text;
    final words = text.split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
    
    return TextEditingValue(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}
