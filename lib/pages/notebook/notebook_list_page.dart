import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models/notebook_models.dart';
import '../../services/auth_service.dart';
import '../../services/notebook_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notebook/notebook_card.dart';
import 'notebook_detail_page.dart';

/// Landing page for the AI Notebook system, presenting all notebooks created
/// by the current educator/admin with search and creation workflows.
class NotebookListPage extends StatefulWidget {
  const NotebookListPage({super.key});

  @override
  State<NotebookListPage> createState() => _NotebookListPageState();
}

class _NotebookListPageState extends State<NotebookListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = AuthService.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF131812) : AppColors.backgroundBase,
      body: CustomScrollView(
        slivers: [
          // Elegant Header App Bar with Gradient
          SliverAppBar(
            expandedHeight: 180.0,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'AI Notebooks',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF4C7530),
                      Color(0xFF76A34F),
                      Color(0xFF2E4D1D),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 200,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 50,
                      child: Text(
                        'Upload sources, synthesize notes, and generate study tools',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search and Filter Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E261D) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search notebooks...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateNotebookDialog(context, currentUid),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('New Notebook'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Notebooks Stream Grid
          StreamBuilder<List<Notebook>>(
            stream: NotebookService.instance.listUserNotebooks(currentUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Error loading notebooks: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              var notebooks = snapshot.data ?? [];

              if (_searchQuery.isNotEmpty) {
                notebooks = notebooks
                    .where((nb) =>
                        nb.title.toLowerCase().contains(_searchQuery) ||
                        nb.description.toLowerCase().contains(_searchQuery))
                    .toList();
              }

              if (notebooks.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(isDark, currentUid),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: _calculateColumnCount(context),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  itemBuilder: (context, index) {
                    final notebook = notebooks[index];
                    return NotebookCard(
                      notebook: notebook,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotebookDetailPage(notebookId: notebook.id),
                          ),
                        );
                      },
                      onEdit: () => _showEditNotebookDialog(context, notebook),
                      onDelete: () => _confirmDeleteNotebook(context, notebook),
                    );
                  },
                  childCount: notebooks.length,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateNotebookDialog(context, currentUid),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Notebook'),
      ),
    );
  }

  int _calculateColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 900) return 3;
    if (width > 600) return 2;
    return 1;
  }

  Widget _buildEmptyState(bool isDark, String currentUid) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No notebooks match "$_searchQuery"'
                  : 'Start by creating your first Notebook',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A Notebook organizes your PDF documents, notes, recordings, and generates interactive flashcards, quizzes, mind maps, and study guides.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateNotebookDialog(context, currentUid),
              icon: const Icon(Icons.add),
              label: const Text('Create Notebook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateNotebookDialog(BuildContext context, String currentUid) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create New Notebook'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Notebook Title',
                  hintText: 'e.g., Biology 101 - Cell Respiration',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Brief summary of what this notebook covers...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              final notebook = await NotebookService.instance.createNotebook(
                title: titleController.text.trim(),
                description: descController.text.trim(),
                createdBy: currentUid,
              );

              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotebookDetailPage(notebookId: notebook.id),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditNotebookDialog(BuildContext context, Notebook notebook) {
    final titleController = TextEditingController(text: notebook.title);
    final descController = TextEditingController(text: notebook.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Notebook Details'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              final updated = notebook.copyWith(
                title: titleController.text.trim(),
                description: descController.text.trim(),
              );
              await NotebookService.instance.updateNotebook(updated);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNotebook(BuildContext context, Notebook notebook) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notebook?'),
        content: Text(
          'Are you sure you want to delete "${notebook.title}"? All associated sources, flashcards, quizzes, and outputs will be permanently deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await NotebookService.instance.deleteNotebook(notebook.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
