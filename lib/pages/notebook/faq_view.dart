import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/study_guide_models.dart';
import '../../theme/app_colors.dart';
import 'publish_content_dialogs.dart';

/// Renders a categorized and searchable FAQ accordion from notebook sources.
class FAQView extends StatefulWidget {
  final FAQ faq;
  final String notebookId;
  final String outputId;
  final bool isLearnerView;
  final bool isShared;

  const FAQView({
    super.key,
    required this.faq,
    required this.notebookId,
    required this.outputId,
    bool? isLearnerView,
    this.isShared = false,
  }) : isLearnerView = isLearnerView ?? isShared;

  @override
  State<FAQView> createState() => _FAQViewState();
}

class _FAQViewState extends State<FAQView> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = <String>{'All'};
    for (final item in widget.faq.items) {
      if (item.category != null && item.category!.isNotEmpty) {
        categories.add(item.category!);
      }
    }

    final filteredItems = widget.faq.items.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          item.question.toLowerCase().contains(_searchQuery) ||
          item.answer.toLowerCase().contains(_searchQuery);
      return matchesCategory && matchesQuery;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.faq.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy all Q&As',
                onPressed: () => _copyAllFaqs(context),
              ),
              if (!widget.isLearnerView)
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                  tooltip: 'Publish to Curriculum',
                  onPressed: () => _publishFaq(context),
                ),
            ],
          ),
          if (widget.faq.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.faq.description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
            ),
          ],

          // Search Box
          const SizedBox(height: 20),
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search questions and answers...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFFF59E0B)),
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E261D) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),

          // Categories Row
          if (categories.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: const Color(0xFFF59E0B),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppColors.textPrimary),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Items Accordion
          const SizedBox(height: 20),
          if (filteredItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No questions match your filter.',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...filteredItems.map((item) => _buildFaqTile(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildFaqTile(FAQItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E261D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.help_outline_rounded, color: Color(0xFFF59E0B), size: 18),
          ),
          title: Text(
            item.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          subtitle: item.category != null
              ? Text(
                  item.category!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF182017) : const Color(0xFFF7F9F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.answer,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: 'Q: ${item.question}\nA: ${item.answer}',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Q&A copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy Q&A', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAllFaqs(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('# ${widget.faq.title}\n');
    for (final item in widget.faq.items) {
      buffer.writeln('### ${item.question}');
      buffer.writeln('${item.answer}\n');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All FAQs copied to clipboard')),
    );
  }

  void _publishFaq(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => PublishContentDialog(
        notebookId: widget.notebookId,
        output: widget.faq.toNotebookOutput(
          id: widget.outputId,
          notebookId: widget.notebookId,
        ),
      ),
    );
  }
}
