import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'unverified_validator_gate_page.dart';

class ValidatorPrcUploadPage extends StatefulWidget {
  final User user;
  const ValidatorPrcUploadPage({super.key, required this.user});

  @override
  State<ValidatorPrcUploadPage> createState() => _ValidatorPrcUploadPageState();
}

class _ValidatorPrcUploadPageState extends State<ValidatorPrcUploadPage> {
  PlatformFile? _prcFile;
  bool _isUploading = false;
  String? _errorMessage;

  static const List<String> _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
        if (!_allowedExtensions.contains(ext)) {
          setState(() {
            _errorMessage = 'Please select a valid document (${_allowedExtensions.join(', ').toUpperCase()})';
          });
          return;
        }

        if (file.size > 20 * 1024 * 1024) {
          setState(() {
            _errorMessage = 'File size must be under 20MB.';
          });
          return;
        }

        setState(() {
          _prcFile = file;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _submitPrc() async {
    if (_prcFile == null || _prcFile!.bytes == null) {
      setState(() {
        _errorMessage = 'Please select your PRC teacher certificate file first.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final ext = (_prcFile!.extension ?? _prcFile!.name.split('.').last).toLowerCase();
      String contentType = 'application/pdf';
      if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == 'png') {
        contentType = 'image/png';
      }

      final downloadUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _prcFile!.bytes!,
        fileName: _prcFile!.name,
        contentType: contentType,
      );

      await DatabaseService.instance.submitValidatorApplication(
        uid: widget.user.uid,
        email: widget.user.email ?? '',
        prcUrl: downloadUrl,
        prcFileName: _prcFile!.name,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const UnverifiedValidatorGatePage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to upload document: $e';
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Validator Accreditation',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          actions: [
            TextButton.icon(
              onPressed: () => AuthService.instance.signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Upload PRC Teacher Certificate',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'To register as an accredited Validator for Grammatica, please provide a clear copy of your Professional Regulation Commission (PRC) Teacher Certificate or ID.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Upload Area
                      InkWell(
                        onTap: _isUploading ? null : _pickFile,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(
                            color: _prcFile != null
                                ? AppColors.primary.withValues(alpha: 0.05)
                                : (isDark ? Colors.grey.shade900 : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _prcFile != null
                                  ? AppColors.primary
                                  : (isDark ? Colors.white24 : Colors.grey.shade300),
                              width: _prcFile != null ? 2 : 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _prcFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                                size: 48,
                                color: _prcFile != null ? AppColors.primary : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              if (_prcFile != null) ...[
                                Text(
                                  _prcFile!.name,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_prcFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Tap to change',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Click to select PRC Document',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Supported formats: PDF, PNG, JPG (Max 20MB)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_prcFile == null || _isUploading) ? null : _submitPrc,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  'Submit Certificate for Review',
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
          ),
        ),
      ),
    );
  }
}
