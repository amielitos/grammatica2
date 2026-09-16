import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:flutter/services.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/design_ornaments.dart';

import '../widgets/top_nav_bar.dart';
import 'otp_verification_page.dart';
import '../services/email_sender_service.dart';
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

  // Step 1 Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  String? _selectedSuffix;
  final List<String> _suffixes = ['Jr.', 'Sr.', 'III', 'IV', 'V'];

  // Step 2 Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _completePhoneNumber;
  bool _isEmailTaken = false;
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
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _validateEmailRealTime() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _isEmailTaken = false);
      return;
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
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

  String _getPasswordStrength() {
    String pass = _passwordController.text;
    if (pass.isEmpty) return "";
    if (pass.length < 6) return "Weak (Short)";
    bool hasLetters = pass.contains(RegExp(r'[a-zA-Z]'));
    bool hasNumbers = pass.contains(RegExp(r'[0-9]'));
    bool hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (hasLetters && hasNumbers && hasSpecial && pass.length >= 8) return "Strong";
    if (hasLetters && hasNumbers) return "Medium";
    return "Weak";
  }

  Color _getStrengthColor() {
    String strength = _getPasswordStrength();
    if (strength == "Strong") return Colors.green;
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
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please read and agree to the Terms')));
      return;
    }
    if (!_formKey3.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String fullName = "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
      if (_selectedSuffix != null) fullName += " $_selectedSuffix";

      // Generate 6-Digit OTP
      final generatedOtp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
      
      // SEND REAL OTP WITH TEMPLATE
      await EmailSenderService.sendOtpEmail(
        recipientEmail: _emailController.text.trim(),
        recipientName: _firstNameController.text.trim(),
        otpCode: generatedOtp,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerificationPage(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: fullName,
          phoneNumber: _completePhoneNumber ?? _phoneController.text.trim(),
          dateOfBirth: _selectedDate ?? DateTime.now(),
          expectedOtp: generatedOtp,
        )));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKey1.currentState!.validate()) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } else if (_currentStep == 1) {
      if (_formKey2.currentState!.validate() && !_isEmailTaken && !_isValidatingEmail) {
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 12)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  _buildProgress(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _currentStep == 2 ? 380 : 220,
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
                  _buildFooter(),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2F3D9), Colors.white],
        ),
      ),
      padding: const EdgeInsets.only(top: 32, bottom: 16, left: 32, right: 32),
      child: Column(
        children: [
          Image.asset('assets/logotext.png', height: 35),
          const SizedBox(height: 12),
          Text(
            "Create Account",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
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
                color: stepIndex < _currentStep ? const Color(0xFF81B655) : Colors.grey[200],
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
                  color: isActive ? const Color(0xFF81B655) : Colors.grey[200],
                  shape: BoxShape.circle,
                  boxShadow: isActive ? [BoxShadow(color: const Color(0xFF81B655).withValues(alpha: 0.3), blurRadius: 8)] : [],
                ),
                child: Center(
                  child: Text("${stepIndex + 1}", style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[stepIndex], style: TextStyle(fontSize: 11, color: isActive ? const Color(0xFF81B655) : Colors.grey, fontWeight: FontWeight.bold)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Personal Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _firstNameController,
                    hintText: 'First Name',
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _lastNameController,
                    hintText: 'Last Name',
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
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _dobController,
                    hintText: 'Date of Birth',
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Select date';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Contact Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              hintText: 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter email';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) return 'Enter valid email';
                if (_isEmailTaken) return 'Email already registered';
                return null;
              },
              onChanged: (val) => _validateEmailRealTime(),
              suffixIcon: _isValidatingEmail 
                ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                : _isEmailTaken ? const Icon(Icons.error_outline, color: Colors.red) : null,
            ),
            const SizedBox(height: 12),
            _buildPhoneField(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Security", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              hintText: 'Password',
              obscureText: _obscurePassword,
              onChanged: (v) => setState(() {}),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (val) => (val == null || val.length < 6) ? 'Min 6 characters' : null,
            ),
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text("Strength: ", style: TextStyle(fontSize: 12)),
                  Text(_getPasswordStrength(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStrengthColor())),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _buildTextField(
              controller: _confirmPasswordController,
              hintText: 'Confirm Password',
              obscureText: _obscureConfirmPassword,
              onChanged: (v) => setState(() {}),
              prefixIcon: const Icon(Icons.lock_reset),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
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
            const SizedBox(height: 20),
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

  Widget _buildFooter() {
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
              const Text("Already have an account? ", style: TextStyle(color: Colors.black87, fontSize: 13)),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Text("Sign In", style: TextStyle(color: Color(0xFF75A94B), fontWeight: FontWeight.bold, fontSize: 13)),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: TextFormField(
        inputFormatters: inputFormatters,
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 14, fontWeight: FontWeight.w600),
          prefixIcon: IconTheme(data: const IconThemeData(color: Colors.black45), child: prefixIcon),
          suffixIcon: suffixIcon != null ? IconTheme(data: const IconThemeData(color: Colors.black45), child: suffixIcon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedSuffix,
          decoration: const InputDecoration(
            hintText: "Suffix (Optional)",
            hintStyle: TextStyle(color: Colors.black45, fontSize: 14, fontWeight: FontWeight.w600),
            prefixIcon: Icon(Icons.title, color: Colors.black45),
            border: InputBorder.none,
          ),
          items: _suffixes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) => setState(() => _selectedSuffix = val),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: IntlPhoneField(
        controller: _phoneController,
        initialCountryCode: 'PH',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        showDropdownIcon: false,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Phone Number',
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 14, fontWeight: FontWeight.w600),
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        onChanged: (phone) {
          _completePhoneNumber = phone.completeNumber;
        },
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
