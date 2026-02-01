import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';

class EducatorApplicationPage extends StatefulWidget {
  final User user;
  const EducatorApplicationPage({super.key, required this.user});

  @override
  State<EducatorApplicationPage> createState() =>
      _EducatorApplicationPageState();
}

class _EducatorApplicationPageState extends State<EducatorApplicationPage> {
  PlatformFile? _videoFile;
  PlatformFile? _syllabusFile;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result != null) {
      setState(() {
        _videoFile = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _pickSyllabus() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _syllabusFile = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_videoFile == null || _syllabusFile == null) {
      setState(
        () => _error = 'Please upload both a video demo and a syllabus.',
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _error = null;
    });

    try {
      // Upload Video
      setState(() => _uploadProgress = 0.2);
      final videoUrl = await DatabaseService.instance.uploadApplicationFile(
        fileBytes: _videoFile!.bytes!,
        fileName: _videoFile!.name,
        contentType:
            'video/mp4', // Assuming mp4 for simplicity, or detect from extension
      );

      // Upload Syllabus
      setState(() => _uploadProgress = 0.6);
      final syllabusUrl = await DatabaseService.instance.uploadApplicationFile(
        fileBytes: _syllabusFile!.bytes!,
        fileName: _syllabusFile!.name,
        contentType: 'application/pdf',
      );

      // Submit Application
      setState(() => _uploadProgress = 0.9);
      await DatabaseService.instance.submitEducatorApplication(
        uid: widget.user.uid,
        email: widget.user.email!,
        videoUrl: videoUrl,
        syllabusUrl: syllabusUrl,
      );

      setState(() {
        _uploadProgress = 1.0;
        _isUploading = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Application Submitted'),
            content: const Text(
              'Your application has been submitted successfully and is now subject to approval by the super admins.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to Profile
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Failed to submit application: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Educator Application'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              AppColors.backgroundDark.withBlue(50),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 800;
              final contentWidth = isLargeScreen
                  ? constraints.maxWidth * 0.7
                  : constraints.maxWidth;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Card(
                      elevation: 0,
                      color: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isLargeScreen ? 40.0 : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Become a Verified Educator',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Please provide the following credentials for verification.',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Teaching Demo Video',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a 3-minute video of you doing a teaching demo.',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 16),
                            _FilePickerButton(
                              label: _videoFile?.name ?? 'Select Video',
                              icon: CupertinoIcons.videocam_fill,
                              onPressed: _isUploading ? null : _pickVideo,
                              isUploaded: _videoFile != null,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Teaching Syllabus',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a PDF sample of a teaching syllabus you have done.',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 16),
                            _FilePickerButton(
                              label: _syllabusFile?.name ?? 'Select PDF',
                              icon: CupertinoIcons.doc_fill,
                              onPressed: _isUploading ? null : _pickSyllabus,
                              isUploaded: _syllabusFile != null,
                            ),
                            const SizedBox(height: 32),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            if (_isUploading)
                              Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: _uploadProgress,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Uploading... ${(_uploadProgress * 100).toInt()}%',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            FilledButton(
                              onPressed: _isUploading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Submit Application',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Note: Your application will be reviewed by our super admins. This process usually takes 2-3 business days.',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilePickerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isUploaded;

  const _FilePickerButton({
    required this.label,
    required this.icon,
    this.onPressed,
    required this.isUploaded,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: isUploaded ? Colors.green : null),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isUploaded ? Colors.green : null),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        side: BorderSide(
          color: isUploaded ? Colors.green : Colors.grey.withOpacity(0.3),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
