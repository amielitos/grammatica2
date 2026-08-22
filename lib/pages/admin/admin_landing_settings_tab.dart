import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

const int _kMaxImages = 10;

class AdminLandingSettingsTab extends StatefulWidget {
  const AdminLandingSettingsTab({super.key});

  @override
  State<AdminLandingSettingsTab> createState() =>
      _AdminLandingSettingsTabState();
}

class _AdminLandingSettingsTabState extends State<AdminLandingSettingsTab> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  bool _isLoading = true;
  final Set<int> _uploadingIndices = {};

  // Saved image URLs from Firestore
  List<String> _savedUrls = [];

  // Pending selections (before upload)
  final List<_PendingImage> _pendingSlots = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('landing_page')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final raw = data['hero_images'];
        if (raw is List) {
          setState(() {
            _savedUrls = List<String>.from(raw.whereType<String>());
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading landing settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int get _totalCount => _savedUrls.length + _pendingSlots.length;
  bool get _canAddMore => _totalCount < _kMaxImages;
  bool get _hasPending => _pendingSlots.isNotEmpty;
  bool get _isUploading => _uploadingIndices.isNotEmpty;

  Future<void> _pickAndAddImage() async {
    if (!_canAddMore) {
      _showMaxReached();
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _pendingSlots.add(_PendingImage(bytes: file.bytes!, fileName: file.name));
    });
  }

  void _showMaxReached() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Maximum of $_kMaxImages images reached. Remove one to add another.',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<String?> _uploadToStorage(
      Uint8List bytes, String fileName, int globalIndex) async {
    try {
      final ext = fileName.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'landing/hero_${globalIndex}_$timestamp.$ext';
      final ref = _storage.ref().child(path);
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$ext'),
      );
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _saveAllPending() async {
    if (_pendingSlots.isEmpty) return;

    final startIndex = _savedUrls.length;
    final List<String> newUrls = [];

    for (int i = 0; i < _pendingSlots.length; i++) {
      final pending = _pendingSlots[i];
      setState(() => _uploadingIndices.add(i));
      try {
        final url = await _uploadToStorage(
            pending.bytes, pending.fileName, startIndex + i);
        if (url != null) newUrls.add(url);
      } catch (e) {
        debugPrint('Error uploading slot $i: $e');
      } finally {
        setState(() => _uploadingIndices.remove(i));
      }
    }

    _savedUrls.addAll(newUrls);

    await _firestore.collection('settings').doc('landing_page').set(
      {
        'hero_images': _savedUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    setState(() => _pendingSlots.clear());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${newUrls.length} image(s) saved successfully!',
              style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF81B655),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _removeSavedImage(int index) async {
    final confirm = await _showConfirmDialog(
      'Remove Image?',
      'This image will be removed from the landing page slideshow.',
    );
    if (confirm != true) return;

    setState(() => _savedUrls.removeAt(index));

    await _firestore.collection('settings').doc('landing_page').set(
      {
        'hero_images': _savedUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image removed.', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _removePendingImage(int pendingIndex) {
    setState(() => _pendingSlots.removeAt(pendingIndex));
  }

  Future<void> _removeAllImages() async {
    final confirm = await _showConfirmDialog(
      'Remove All Images?',
      'All custom images will be removed. The landing page will use the built-in default images.',
    );
    if (confirm != true) return;

    await _firestore.collection('settings').doc('landing_page').set(
      {'hero_images': [], 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    setState(() {
      _savedUrls.clear();
      _pendingSlots.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All images removed. Defaults restored.',
              style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text(message,
            style: GoogleFonts.inter(
                color: Colors.grey.shade600, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF81B655).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.web_rounded,
                    color: Color(0xFF81B655), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Landing Page Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Manage hero background images for visitors (max $_kMaxImages)',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (_savedUrls.isNotEmpty)
                TextButton.icon(
                  onPressed: _isUploading ? null : _removeAllImages,
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: Text('Clear All',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Info Banner ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      const Color(0xFF3B82F6).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF3B82F6), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add up to $_kMaxImages images for the hero slideshow. Each image cycles every 6 seconds. If no custom images are set, the default built-in images are used.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF1E40AF),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Counter Bar ───────────────────────────────────────────────
          _buildCounterBar(),
          const SizedBox(height: 24),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(64),
                child: CircularProgressIndicator(
                    color: Color(0xFF81B655)),
              ),
            )
          else ...[
            // ── Saved Images ─────────────────────────────────────────
            if (_savedUrls.isNotEmpty) ...[
              _buildSectionLabel(
                'Saved Images',
                Icons.cloud_done_rounded,
                const Color(0xFF81B655),
                '${_savedUrls.length} uploaded',
              ),
              const SizedBox(height: 14),
              _buildSavedGrid(),
              const SizedBox(height: 28),
            ],

            // ── Pending Images ────────────────────────────────────────
            if (_hasPending) ...[
              _buildSectionLabel(
                'Pending Upload',
                Icons.pending_rounded,
                const Color(0xFFF59E0B),
                '${_pendingSlots.length} selected, not yet saved',
              ),
              const SizedBox(height: 14),
              _buildPendingGrid(),
              const SizedBox(height: 24),
            ],

            // ── Empty State ───────────────────────────────────────────
            if (_savedUrls.isEmpty && !_hasPending)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_search_rounded,
                        size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No custom images yet',
                        style: GoogleFonts.outfit(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                        'The landing page is using default built-in images.',
                        style: GoogleFonts.inter(
                            color: Colors.grey.shade400, fontSize: 13)),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ── Action Buttons ────────────────────────────────────────
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : (_canAddMore ? _pickAndAddImage : _showMaxReached),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _canAddMore
                        ? const Color(0xFF334155)
                        : Colors.orange,
                    side: BorderSide(
                      color: _canAddMore
                          ? const Color(0xFFE2E8F0)
                          : Colors.orange.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                  ),
                  icon: Icon(
                    _canAddMore
                        ? Icons.add_photo_alternate_rounded
                        : Icons.block_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _canAddMore
                        ? 'Add Image  ($_totalCount / $_kMaxImages)'
                        : 'Max reached ($_kMaxImages / $_kMaxImages)',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                if (_hasPending) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _saveAllPending,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81B655),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                    ),
                    icon: _isUploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.cloud_upload_rounded,
                            size: 18),
                    label: Text(
                      _isUploading
                          ? 'Uploading...'
                          : 'Save All  (${_pendingSlots.length})',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCounterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Text(
            'Slideshow Images',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.black87),
          ),
          const Spacer(),
          Text(
            '$_totalCount / $_kMaxImages',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: _totalCount >= _kMaxImages
                  ? Colors.orange
                  : const Color(0xFF81B655),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _totalCount / _kMaxImages,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _totalCount >= _kMaxImages
                      ? Colors.orange
                      : const Color(0xFF81B655),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(
      String title, IconData icon, Color color, String sub) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.black87)),
        const SizedBox(width: 8),
        Text('· $sub',
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildSavedGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth >= 900
          ? 5
          : constraints.maxWidth >= 600
              ? 3
              : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 4 / 3,
        ),
        itemCount: _savedUrls.length,
        itemBuilder: (ctx, i) => _buildSavedCard(i),
      );
    });
  }

  Widget _buildPendingGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth >= 900
          ? 5
          : constraints.maxWidth >= 600
              ? 3
              : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 4 / 3,
        ),
        itemCount: _pendingSlots.length,
        itemBuilder: (ctx, i) => _buildPendingCard(i),
      );
    });
  }

  Widget _buildSavedCard(int index) {
    final url = _savedUrls[index];
    return _buildImageCard(
      imageWidget: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.broken_image_rounded,
              color: Colors.grey.shade400, size: 32),
        ),
      ),
      indexLabel: 'Image ${index + 1}',
      statusLabel: 'Saved',
      statusColor: const Color(0xFF81B655),
      onRemove: () => _removeSavedImage(index),
    );
  }

  Widget _buildPendingCard(int index) {
    final pending = _pendingSlots[index];
    final isUploading = _uploadingIndices.contains(index);
    return _buildImageCard(
      imageWidget: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(pending.bytes, fit: BoxFit.cover),
          if (isUploading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      indexLabel: pending.fileName,
      statusLabel: 'Pending',
      statusColor: const Color(0xFFF59E0B),
      onRemove: isUploading ? null : () => _removePendingImage(index),
    );
  }

  Widget _buildImageCard({
    required Widget imageWidget,
    required String indexLabel,
    required String statusLabel,
    required Color statusColor,
    VoidCallback? onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            // Bottom gradient + labels
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.70),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        indexLabel,
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Remove ×
            if (onRemove != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingImage {
  final Uint8List bytes;
  final String fileName;
  _PendingImage({required this.bytes, required this.fileName});
}
