import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../services/database_service.dart';
import '../widgets/design_ornaments.dart';
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

  String get _title => widget.applicationType == 'validator' ? 'Validator Application' : 'Educator Application';

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
    final String type = file.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
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
      // Start upload process
      final cvUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _cvFile!.bytes!,
        fileName: _cvFile!.name,
        contentType: _cvFile!.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg',
      );

      // Progress update
      List<String> certUrls = [];
      for (var file in _certificateFiles) {
        final url = await DatabaseService.instance.uploadApplicationFile(
          uid: widget.user.uid,
          fileBytes: file.bytes!,
          fileName: file.name,
          contentType: file.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg',
        );
        certUrls.add(url);
      }

      // Progress update
      final videoUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _videoFile!.bytes!,
        fileName: _videoFile!.name,
        contentType: 'video/mp4',
      );

      // Progress update
      final syllabusUrl = await DatabaseService.instance.uploadApplicationFile(
        uid: widget.user.uid,
        fileBytes: _syllabusFile!.bytes!,
        fileName: _syllabusFile!.name,
        contentType: _syllabusFile!.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg',
      );

      // Finalizing upload
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
            title: const Text('Application Sent'),
            content: const Text(
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

  bool _canGoNext() {
    if (_currentStep == 0) return _cvFile != null;
    if (_currentStep == 1) return _certificateFiles.isNotEmpty;
    if (_currentStep == 2) return _videoFile != null;
    if (_currentStep == 3) return _syllabusFile != null;
    return true;
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
      drawer: UniversalDrawer(
        user: widget.user,
        userData: _userData ?? {},
      ),
      body: BackgroundWrapper(
        imageAssetPath: 'assets/subscriptionbg.png',
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                _title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 8),
              _buildStepIndicator(),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        children: [
                          if (_currentStep < 4) _buildUploadStep(),
                          if (_currentStep == 4) _buildSummaryStep(),
                          const SizedBox(height: 32),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          _buildNavigationButtons(),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final isActive = index <= _currentStep;
        final isLast = index == 4;
        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF81B655) : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (index + 1).toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 40,
                height: 2,
                color: index < _currentStep ? const Color(0xFF81B655) : Colors.grey.shade300,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildUploadStep() {
    String stepTitle = "";
    String stepDesc = "";
    PlatformFile? currentFile;
    IconData icon = Icons.file_present;

    switch (_currentStep) {
      case 0:
        stepTitle = "Step 1: Curriculum Vitae (CV)";
        stepDesc = "Please upload your latest professional CV (PDF or Image).";
        currentFile = _cvFile;
        icon = Icons.description;
        break;
      case 1:
        stepTitle = "Step 2: Certificates & Credentials";
        stepDesc = "Upload your professional certificates or academic degrees (PDF or Image). You can select multiple files.";
        icon = Icons.verified;
        break;
      case 2:
        stepTitle = "Step 3: Teaching Demo Video";
        stepDesc = "Upload a short video (max 200MB) demonstrating your teaching style.";
        currentFile = _videoFile;
        icon = Icons.videocam;
        break;
      case 3:
        stepTitle = "Step 4: Sample Lessons or Syllabus";
        stepDesc = "Upload a sample lesson plan or course syllabus (PDF or Image).";
        currentFile = _syllabusFile;
        icon = Icons.book;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: const Color(0xFF81B655)),
          const SizedBox(height: 24),
          Text(stepTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(stepDesc, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 40),
          InkWell(
            onTap: () => _pickFile(_currentStep),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 2, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    _currentStep == 1 
                        ? (_certificateFiles.isNotEmpty ? "${_certificateFiles.length} files selected" : "Select Files")
                        : (currentFile != null ? currentFile.name : "Select File"),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (_currentStep == 1 && _certificateFiles.isNotEmpty) || currentFile != null 
                          ? const Color(0xFF81B655) 
                          : Colors.grey,
                    ),
                  ),
                  if (_currentStep != 1 && currentFile != null)
                    Text("${(currentFile.size / 1024 / 1024).toStringAsFixed(2)} MB", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          if (_currentStep == 1 && _certificateFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: _certificateFiles.asMap().entries.map((entry) {
                  int idx = entry.key;
                  PlatformFile file = entry.value;
                  return ListTile(
                    leading: const Icon(Icons.verified, color: Color(0xFF81B655)),
                    title: Text(file.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text("${(file.size / 1024 / 1024).toStringAsFixed(2)} MB"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _certificateFiles.removeAt(idx);
                        });
                      },
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
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text("Remove File", style: TextStyle(color: Colors.red)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    return Column(
      children: [
        const Text("Application Summary", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87)),
        const Text("Review your submitted files below. Click any card to preview the full file.", style: TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 32),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 2 : 1,
          mainAxisSpacing: 32,
          crossAxisSpacing: 32,
          childAspectRatio: 1.5,
          children: [
            _buildContentPreviewCard("Curriculum Vitae", _cvFile, Icons.description),
            _buildContentPreviewCard("Teaching Demo", _videoFile, Icons.videocam),
            _buildContentPreviewCard("Certificates (${_certificateFiles.length})", _certificateFiles.isNotEmpty ? _certificateFiles.first : null, Icons.verified),
            _buildContentPreviewCard("Sample Lessons", _syllabusFile, Icons.book),
          ],
        ),
      ],
    );
  }

  Widget _buildContentPreviewCard(String title, PlatformFile? file, IconData icon) {
    if (file == null) return const SizedBox();
    
    final bool isImage = ['jpg', 'jpeg', 'png'].contains(file.name.toLowerCase().split('.').last);
    final bool isVideo = ['mp4', 'mov', 'avi'].contains(file.name.toLowerCase().split('.').last);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF81B655), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF2C3E50)),
                ),
              ],
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _showLocalFilePreview(file),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isImage && file.bytes != null)
                      Image.memory(file.bytes!, fit: BoxFit.cover)
                    else if (isVideo)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_fill, size: 64, color: Color(0xFF81B655)),
                            SizedBox(height: 12),
                            Text("Click to Preview Video", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf, size: 64, color: Colors.redAccent.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(file.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("${(file.size / 1024 / 1024).toStringAsFixed(2)} MB", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 8),
                            const Text("Click to Open PDF", style: TextStyle(color: Color(0xFF81B655), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Text(
                          file.name,
                          style: const TextStyle(color: Colors.white, fontSize: 12, overflow: TextOverflow.ellipsis),
                        ),
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

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _isUploading ? null : () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: Color(0xFF81B655), width: 2),
              ),
              child: const Text("Back", style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 24),
        Expanded(
          child: ElevatedButton(
            onPressed: (_isUploading || !_canGoNext()) ? null : () {
              if (_currentStep < 4) {
                setState(() => _currentStep++);
              } else {
                _submit();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81B655),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isUploading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _currentStep == 4 ? "Submit Application" : "Next Step",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }
}
