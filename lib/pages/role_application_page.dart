import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';
import '../main.dart';

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

  String get _title => widget.applicationType == 'validator' ? 'Become a Validator' : 'Become an Educator';

  String get _demoLabel => widget.applicationType == 'validator' ? 'Expertise Demo' : 'Teaching Demo';

  String get _demoDescription => widget.applicationType == 'validator'
      ? 'Showcase your English expertise in a short introductory video.'
      : 'Upload a 3-minute video demonstrating your teaching style.';

  String get _docLabel => widget.applicationType == 'validator' ? 'Professional Credentials' : 'Teaching Syllabus';

  String get _docDescription => widget.applicationType == 'validator'
      ? 'Upload your certifications, degrees, or relevant professional documents.'
      : 'Upload a sample syllabus or lesson plan you have created.';

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
      setState(() => _error = 'Please upload both required modules to proceed.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _error = null;
    });

    try {
      setState(() => _uploadProgress = 0.2);
      final videoUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _videoFile!.bytes!,
        fileName: _videoFile!.name,
        contentType: 'video/mp4',
      );

      setState(() => _uploadProgress = 0.6);
      final docUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _docFile!.bytes!,
        fileName: _docFile!.name,
        contentType: 'application/pdf',
      );

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
            title: const Text('Application Sent'),
            content: Text(
              'Your application has been received! Our team will review your credentials within 2-3 business days.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Great!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Hmm, something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        user: widget.user,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
      ),
      body: BackgroundWrapper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // Header Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user_rounded, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Join our elite community of language enthusiasts and experts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 40),

                    // Form Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildUploadSection(
                              title: _demoLabel,
                              description: _demoDescription,
                              fileName: _videoFile?.name,
                              icon: Icons.videocam_rounded,
                              onPick: _pickVideo,
                            ),
                            const SizedBox(height: 40),
                            _buildUploadSection(
                              title: _docLabel,
                              description: _docDescription,
                              fileName: _docFile?.name,
                              icon: Icons.description_rounded,
                              onPick: _pickDoc,
                            ),
                            const SizedBox(height: 48),

                            if (_error != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            if (_isUploading)
                              Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: _uploadProgress,
                                      minHeight: 8,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Uploading Progress: ${(_uploadProgress * 100).toInt()}%',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),

                            ElevatedButton(
                              onPressed: _isUploading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 64),
                              ),
                              child: const Text('SUBMIT APPLICATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Applications are typically processed within 2-3 business days. You will receive a notification once yours is approved.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection({
    required String title,
    required String description,
    required String? fileName,
    required IconData icon,
    required VoidCallback onPick,
  }) {
    final bool isUploaded = fileName != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _isUploading ? null : onPick,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: isUploaded ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUploaded ? AppColors.primary : AppColors.divider,
                width: isUploaded ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isUploaded ? AppColors.primary : AppColors.divider).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isUploaded ? Icons.check_circle_rounded : icon,
                    color: isUploaded ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    fileName ?? 'Select File',
                    style: TextStyle(
                      fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal,
                      color: isUploaded ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.upload_file_rounded,
                  color: isUploaded ? AppColors.primary : AppColors.textSecondary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ],
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
        foregroundColor: isUploaded ? Theme.of(context).colorScheme.primary : null,
        side: isUploaded ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2) : null,
      ),
    );
  }
}
