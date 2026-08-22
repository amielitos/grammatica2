import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../services/database_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';
import '../widgets/universal_drawer.dart';
import '../widgets/application_preview_widgets.dart';

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
  int _currentStep = 0;
  PlatformFile? _cvFile;
  final List<PlatformFile> _certificateFiles = [];
  PlatformFile? _videoFile;
  PlatformFile? _syllabusFile;

  bool _isUploading = false;
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
      ? 'Validator Application'
      : 'Educator Application';

  Future<void> _pickFile(int step) async {
    if (step == 1) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
        withData: true,
        allowMultiple: true,
      );
      if (result != null) {
        setState(() {
          _certificateFiles.addAll(result.files);
          _error = null;
        });
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: step == 2 ? FileType.video : FileType.custom,
      allowedExtensions: step == 2 ? null : ['pdf', 'jpg', 'png', 'jpeg'],
      withData: true,
    );
    if (result != null) {
      final file = result.files.first;
      if (step == 2 && file.size > 200 * 1024 * 1024) {
        setState(() => _error = 'Video file size must be less than 200MB');
        return;
      }
      setState(() {
        if (step == 0) _cvFile = file;
        if (step == 2) _videoFile = file;
        if (step == 3) _syllabusFile = file;
        _error = null;
      });
    }
  }

  void _showLocalFilePreview(PlatformFile file) {
    final String type = file.name.toLowerCase().endsWith('.pdf')
        ? 'application/pdf'
        : 'image/jpeg';
    final blob = web.Blob([file.bytes!.toJS].toJS, web.BlobPropertyBag(type: type));
    final blobUrl = web.URL.createObjectURL(blob);
    showFilePreviewModal(context, blobUrl, file.name);
  }

  Future<void> _submit() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      String getContentType(String name) {
        final ext = name.toLowerCase().split('.').last;
        if (ext == 'pdf') return 'application/pdf';
        if (['jpg', 'jpeg'].contains(ext)) return 'image/jpeg';
        if (ext == 'png') return 'image/png';
        if (ext == 'mp4') return 'video/mp4';
        if (ext == 'mov') return 'video/quicktime';
        if (ext == 'avi') return 'video/x-msvideo';
        if (ext == 'webm') return 'video/webm';
        return 'application/octet-stream';
      }

      if (_cvFile?.bytes == null) throw Exception('CV file data not loaded');
      final cvUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _cvFile!.bytes!,
        fileName: _cvFile!.name,
        contentType: getContentType(_cvFile!.name),
      );

      List<String> certUrls = [];
      for (var file in _certificateFiles) {
        if (file.bytes == null) continue;
        final url = await DatabaseService.instance.uploadApplicationFile(
          uid: widget.user.uid,
          fileBytes: file.bytes!,
          fileName: file.name,
          contentType: getContentType(file.name),
        );
        certUrls.add(url);
      }

      if (_videoFile?.bytes == null) throw Exception('Video file data not loaded');
      final videoUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _videoFile!.bytes!,
        fileName: _videoFile!.name,
        contentType: getContentType(_videoFile!.name),
      );

      if (_syllabusFile?.bytes == null) throw Exception('Syllabus file data not loaded');
      final syllabusUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _syllabusFile!.bytes!,
        fileName: _syllabusFile!.name,
        contentType: getContentType(_syllabusFile!.name),
      );

      await DatabaseService.instance.submitEducatorApplication(
        uid: widget.user.uid,
        email: widget.user.email!,
        cvUrl: cvUrl,
        certificateUrls: certUrls,
        videoUrl: videoUrl,
        syllabusUrl: syllabusUrl,
        applicationType: widget.applicationType,
      );

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Application Sent',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Your application has been received! Our team will review your credentials within 2-3 business days.',
              style: GoogleFonts.inter(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(
                  'Great!',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF81B655),
                    fontWeight: FontWeight.w700,
                  ),
                ),
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

  bool _canGoNext() {
    if (_currentStep == 0) return _cvFile != null;
    if (_currentStep == 1) return _certificateFiles.isNotEmpty;
    if (_currentStep == 2) return _videoFile != null;
    if (_currentStep == 3) return _syllabusFile != null;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
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
      drawer: UniversalDrawer(
        user: widget.user,
        userData: _userData ?? {},
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF81B655).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF81B655).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                                color: Color(0xFF81B655),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Back',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF81B655),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Title
                  Text(
                    _title,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Complete the 5 steps to submit your application for review.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Modern Step Progress Bar
                  _buildStepIndicator(isDark, textColor, borderColor),
                  const SizedBox(height: 32),

                  // Main Form Card
                  if (_currentStep < 4)
                    _buildUploadStep(
                      isDark,
                      cardBg,
                      borderColor,
                      textColor,
                      subtitleColor,
                    )
                  else
                    _buildSummaryStep(
                      isDark,
                      cardBg,
                      borderColor,
                      textColor,
                      subtitleColor,
                    ),

                  const SizedBox(height: 28),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                  // Bottom Nav Buttons
                  _buildNavigationButtons(isDark, borderColor),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          final isLast = index == 4;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isCurrent ? 36 : 32,
                        height: isCurrent ? 36 : 32,
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent
                              ? const Color(0xFF81B655)
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                          shape: BoxShape.circle,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF81B655)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: GoogleFonts.outfit(
                                    color: isCompleted || isCurrent
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white38
                                            : const Color(0xFF94A3B8)),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index < _currentStep
                            ? const Color(0xFF81B655)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUploadStep(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    String stepTitle = "";
    String stepDesc = "";
    PlatformFile? currentFile;
    IconData icon = Icons.file_present_rounded;

    switch (_currentStep) {
      case 0:
        stepTitle = "Step 1: Curriculum Vitae (CV)";
        stepDesc = "Please upload your latest professional CV (PDF or Image format).";
        currentFile = _cvFile;
        icon = Icons.description_rounded;
        break;
      case 1:
        stepTitle = "Step 2: Certificates & Credentials";
        stepDesc = "Upload your professional certificates or academic degrees. You can select multiple files.";
        icon = Icons.workspace_premium_rounded;
        break;
      case 2:
        stepTitle = "Step 3: Teaching Demo Video";
        stepDesc = "Upload a short video (max 200MB) demonstrating your teaching style.";
        currentFile = _videoFile;
        icon = Icons.videocam_rounded;
        break;
      case 3:
        stepTitle = "Step 4: Sample Lessons or Syllabus";
        stepDesc = "Upload a sample lesson plan or course syllabus (PDF or Image format).";
        currentFile = _syllabusFile;
        icon = Icons.menu_book_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF81B655).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: const Color(0xFF81B655)),
          ),
          const SizedBox(height: 20),
          Text(
            stepTitle,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stepDesc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: subtitleColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Upload Area Dropzone
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _pickFile(_currentStep),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF81B655).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        size: 32,
                        color: Color(0xFF81B655),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _currentStep == 1
                          ? (_certificateFiles.isNotEmpty
                              ? "${_certificateFiles.length} file(s) selected"
                              : "Click to Select Files")
                          : (currentFile != null
                              ? currentFile.name
                              : "Click to Upload File"),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: (_currentStep == 1 && _certificateFiles.isNotEmpty) ||
                                currentFile != null
                            ? const Color(0xFF81B655)
                            : textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentStep == 2
                          ? "Supports MP4, MOV, AVI up to 200MB"
                          : "Supports PDF, PNG, JPG format",
                      style: GoogleFonts.inter(
                        color: subtitleColor,
                        fontSize: 12,
                      ),
                    ),
                    if (_currentStep != 1 && currentFile != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF81B655).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${(currentFile.size / 1024 / 1024).toStringAsFixed(2)} MB",
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF81B655),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // File List for Step 1 (Certificates)
          if (_currentStep == 1 && _certificateFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                children: _certificateFiles.asMap().entries.map((entry) {
                  int idx = entry.key;
                  PlatformFile file = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFF81B655), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "${(file.size / 1024 / 1024).toStringAsFixed(2)} MB",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              _certificateFiles.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          if (_currentStep != 1 && currentFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (_currentStep == 0) _cvFile = null;
                    if (_currentStep == 2) _videoFile = null;
                    if (_currentStep == 3) _syllabusFile = null;
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 18),
                label: Text(
                  "Remove File",
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Application Summary",
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Review your attached files before submitting. Click any card to preview.",
            style: GoogleFonts.inter(
              color: subtitleColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 2 : 1,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              _buildContentPreviewCard(
                "Curriculum Vitae",
                _cvFile,
                Icons.description_rounded,
                isDark,
                borderColor,
                textColor,
                subtitleColor,
              ),
              _buildContentPreviewCard(
                "Teaching Demo",
                _videoFile,
                Icons.videocam_rounded,
                isDark,
                borderColor,
                textColor,
                subtitleColor,
              ),
              _buildContentPreviewCard(
                "Certificates (${_certificateFiles.length})",
                _certificateFiles.isNotEmpty ? _certificateFiles.first : null,
                Icons.workspace_premium_rounded,
                isDark,
                borderColor,
                textColor,
                subtitleColor,
              ),
              _buildContentPreviewCard(
                "Sample Lessons",
                _syllabusFile,
                Icons.menu_book_rounded,
                isDark,
                borderColor,
                textColor,
                subtitleColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreviewCard(
    String title,
    PlatformFile? file,
    IconData icon,
    bool isDark,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    if (file == null) return const SizedBox();

    final bool isImage = ['jpg', 'jpeg', 'png']
        .contains(file.name.toLowerCase().split('.').last);
    final bool isVideo = ['mp4', 'mov', 'avi']
        .contains(file.name.toLowerCase().split('.').last);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF81B655), size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _showLocalFilePreview(file),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isImage && file.bytes != null)
                      Image.memory(file.bytes!, fit: BoxFit.cover)
                    else if (isVideo)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_fill_rounded,
                                size: 44, color: Color(0xFF81B655)),
                            const SizedBox(height: 6),
                            Text(
                              "Click to Preview Video",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                color: subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf_rounded,
                                size: 44,
                                color: Colors.redAccent.withValues(alpha: 0.6)),
                            const SizedBox(height: 6),
                            Text(
                              file.name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "${(file.size / 1024 / 1024).toStringAsFixed(2)} MB",
                              style: GoogleFonts.inter(
                                color: subtitleColor,
                                fontSize: 11,
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
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark, Color borderColor) {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed:
                    _isUploading ? null : () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                  foregroundColor:
                      isDark ? Colors.white70 : const Color(0xFF475569),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Back",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_isUploading || !_canGoNext())
                  ? null
                  : () {
                      if (_currentStep < 4) {
                        setState(() => _currentStep++);
                      } else {
                        _submit();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81B655),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == 4 ? "Submit Application" : "Next Step",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
