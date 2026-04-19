import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';
import '../widgets/universal_drawer.dart';
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
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final data = await DatabaseService.instance.getUserData(widget.user.uid);
    if (mounted) {
      setState(() {
        _userData = data;
      });
    }
  }

  String get _title => widget.applicationType == 'validator'
      ? 'Become a Validator'
      : 'Become an Educator';

  String get _demoLabel => widget.applicationType == 'validator'
      ? 'Expertise Demo'
      : 'Teaching Demo';

  String get _demoDescription => widget.applicationType == 'validator'
      ? 'Showcase your English expertise in a short introductory video.'
      : 'Upload a 3-minute video demonstrating your teaching style.';

  String get _docLabel => widget.applicationType == 'validator'
      ? 'Professional Credentials'
      : 'Teaching Syllabus';

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
      setState(
        () => _error = 'Please upload both required modules to proceed.',
      );
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
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        user: widget.user,
        userData: _userData,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
        onLogoTap: () => Navigator.pop(context),
        onProfileTap: () => Navigator.pop(context),
      ),
      drawer: UniversalDrawer(user: widget.user, userData: _userData ?? {}),
      body: BackgroundWrapper(
        imageAssetPath: 'assets/subscriptionbg.png',
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join our elite community of language enthusiasts and expert',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF2C3E50).withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;
                        return isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildApplicationCard(true)),
                                  const SizedBox(width: 24),
                                  Expanded(child: _buildApplicationCard(false)),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildApplicationCard(true),
                                  const SizedBox(height: 24),
                                  _buildApplicationCard(false),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 32),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    _buildSubmitBtn(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationCard(bool isVideo) {
    final file = isVideo ? _videoFile : _docFile;
    final title = isVideo ? _demoLabel : _docLabel;
    final desc = isVideo ? _demoDescription : _docDescription;
    final selectText = isVideo ? 'Select Video File' : 'Select PDF File';

    final pillBg = isVideo
        ? const Color(0xFFFEE69F)
        : const Color(0xFFCEDA72).withOpacity(0.5);
    final pillTextColor = isVideo
        ? const Color(0xFFF9A825)
        : const Color(0xFF88B342);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Upload Area
          InkWell(
            onTap: isVideo ? _pickVideo : _pickDoc,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.file_upload_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // File Pill
          if (file != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      file.name,
                      style: TextStyle(
                        color: pillTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    iconSize: 20,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isVideo) {
                          _videoFile = null;
                        } else {
                          _docFile = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 24),

          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.4),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBtn() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF81B655).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF81B655),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: _isUploading ? null : _submit,
        child: _isUploading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Submit Application',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
