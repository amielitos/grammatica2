import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notebook_models.dart';
import '../../services/notebook_service.dart';
import '../../theme/app_colors.dart';
import '../../pages/notebook/notebook_detail_page.dart';
import '../../pages/notebook/notebook_list_page.dart';

/// Modal dialog allowing educators and admins to browse their local session notebooks
/// and import generated lessons or quizzes directly into the Admin content editors.
class NotebookSelectorDialog extends StatelessWidget {
  final NotebookOutputType targetType;
  final Function(NotebookOutput output) onOutputSelected;

  const NotebookSelectorDialog({
    super.key,
    required this.targetType,
    required this.onOutputSelected,
  });

  String get _typeName => targetType == NotebookOutputType.lesson ? 'Lesson' : 'Quiz';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E261D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 650),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import $_typeName from AI Notebook',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose an AI-generated $_typeName draft from your local session notebooks',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Studio Shortcut Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF283427) : const Color(0xFFF1F8EE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Need to generate new curriculum from documents?',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotebookListPage()),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open Notebook Studio'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notebooks List
            Expanded(
              child: StreamBuilder<List<Notebook>>(
                stream: NotebookService.instance.getNotebooks(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notebooks = snapshot.data ?? [];
                  if (notebooks.isEmpty) {
                    return _buildEmptyState(context, isDark);
                  }

                  return ListView.builder(
                    itemCount: notebooks.length,
                    itemBuilder: (context, index) {
                      final notebook = notebooks[index];
                      return _buildNotebookItem(context, notebook, isDark);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotebookItem(BuildContext context, Notebook notebook, bool isDark) {
    return StreamBuilder<List<NotebookOutput>>(
      stream: NotebookService.instance.getOutputs(notebook.id),
      builder: (context, snapshot) {
        final allOutputs = snapshot.data ?? [];
        final matchingOutputs = allOutputs.where((o) => o.type == targetType).toList();

        if (matchingOutputs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242E23) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.07),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
              title: Text(
                notebook.title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                '${matchingOutputs.length} $_typeName${matchingOutputs.length > 1 ? "s" : ""} available',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.launch_rounded, size: 18),
                tooltip: 'Open Notebook Workspace',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotebookDetailPage(notebookId: notebook.id),
                    ),
                  );
                },
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: matchingOutputs.map((output) {
                      return _buildOutputRow(context, output, isDark);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutputRow(BuildContext context, NotebookOutput output, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E261D) : const Color(0xFFF9FAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            targetType == NotebookOutputType.lesson
                ? Icons.menu_book_rounded
                : Icons.quiz_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  output.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (output.isPublished)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Published',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Session Draft',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                    Text(
                      'Created ${output.generatedAt.toLocal().toString().split(' ')[0]}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onOutputSelected(output);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Import', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notes_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'No Notebooks Found',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a notebook in the AI Notebook studio to ingest sources and generate $_typeName materials.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
