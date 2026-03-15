import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';

class RoleApplicationPage extends StatefulWidget {
  final User user;
  final String applicationType; // 'educator' or 'validator'

  const RoleApplicationPage({
    super.key,
    required this.user,
    required this.applicationType,
  });

  @override
  State<RoleApplicationPage> createState() => _RoleApplicationPageState();
}

class _RoleApplicationPageState extends State<RoleApplicationPage> {
  PlatformFile? _videoFile;
  PlatformFile? _docFile;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;

  String get _title => widget.applicationType == 'validator'
      ? 'Become a Verified Validator'
      : 'Become a Verified Educator';

  String get _demoLabel => widget.applicationType == 'validator'
      ? 'Introductory Demo'
      : 'Teaching Demo Video';

  String get _demoDescription => widget.applicationType == 'validator'
      ? 'Upload a demo that showcases your expertise in the English field.'
      : 'Upload a 3-minute video of you doing a teaching demo.';

  String get _docLabel => widget.applicationType == 'validator'
      ? 'Credentials'
      : 'Teaching Syllabus';

  String get _docDescription => widget.applicationType == 'validator'
      ? 'Upload a PDF of your credentials (certificates, degrees, etc.).'
      : 'Upload a PDF sample of a teaching syllabus you have done.';

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

  Future<void> _pickDoc() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _docFile = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_videoFile == null || _docFile == null) {
      setState(
        () => _error =
            'Please upload both the demo video and the required document.',
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
        uid: widget.user.uid,
        fileBytes: _videoFile!.bytes!,
        fileName: _videoFile!.name,
        contentType: 'video/mp4',
      );

      // Upload Document
      setState(() => _uploadProgress = 0.6);
      final docUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _docFile!.bytes!,
        fileName: _docFile!.name,
        contentType: 'application/pdf',
      );

      // Submit Application
      setState(() => _uploadProgress = 0.9);
      await DatabaseService.instance.submitEducatorApplication(
        uid: widget.user.uid,
        email: widget.user.email!,
        videoUrl: videoUrl,
        syllabusUrl: docUrl,
        applicationType: widget.applicationType,
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
            content: Text(
              'Your application as a ${widget.applicationType} has been submitted successfully and is now subject to approval.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to Role Selection Popup
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
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isLargeScreen ? 40.0 : 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _title,
                            style: Theme.of(context).textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Please provide the following credentials for verification.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _demoLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_demoDescription),
                          const SizedBox(height: 16),
                          _FilePickerButton(
                            label: _videoFile?.name ?? 'Select Video',
                            icon: Icons.videocam,
                            onPressed: _isUploading ? null : _pickVideo,
                            isUploaded: _videoFile != null,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _docLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_docDescription),
                          const SizedBox(height: 16),
                          _FilePickerButton(
                            label: _docFile?.name ?? 'Select PDF',
                            icon: Icons.description,
                            onPressed: _isUploading ? null : _pickDoc,
                            isUploaded: _docFile != null,
                          ),
                          const SizedBox(height: 32),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_isUploading)
                            Column(
                              children: [
                                LinearProgressIndicator(value: _uploadProgress),
                                const SizedBox(height: 8),
                                Text(
                                  'Uploading... ${(_uploadProgress * 100).toInt()}%',
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          FilledButton(
                            onPressed: _isUploading ? null : _submit,
                            child: const Text('Submit Application'),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Note: Your application will be reviewed by our super admins. This process usually takes 2-3 business days.',
                            style: TextStyle(fontSize: 13),
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
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: isUploaded
            ? Theme.of(context).colorScheme.primary
            : null,
        side: isUploaded
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
    );
  }
}
