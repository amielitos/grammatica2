import 'dart:io';

void main() {
  final file = File('lib/pages/lesson_folder_page.dart');
  String content = file.readAsStringSync();

  // 1. Inject isDark in _buildLessonListBody
  content = content.replaceFirst(
    'Widget _buildLessonListBody(BuildContext context) {',
    'Widget _buildLessonListBody(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;'
  );

  // 2. Adjust TextField decoration for search box
  content = content.replaceFirst(
    "suffixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary)",
    "suffixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white70 : AppColors.textSecondary)"
  );
  content = content.replaceFirst(
    "fillColor: Colors.white",
    "fillColor: isDark ? const Color(0xFF333333) : Colors.white"
  );
  content = content.replaceFirst(
    "hintText: 'Search lesson..',",
    "hintText: 'Search lesson..',\n                      hintStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary),\n                      style: TextStyle(color: isDark ? Colors.white : Colors.black),"
  );
  
  // 3. Inject isDark into _buildSmallLessonCard
  content = content.replaceFirst(
    'Widget _buildSmallLessonCard(\n    BuildContext context, {\n    required Lesson lesson,\n    required bool completed,\n    String? authorLabel,\n  }) {',
    'Widget _buildSmallLessonCard(\n    BuildContext context, {\n    required Lesson lesson,\n    required bool completed,\n    String? authorLabel,\n  }) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;'
  );

  // 4. Modify SmallLessonCard colors
  content = content.replaceFirst(
    "color: Colors.white,",
    "color: isDark ? const Color(0xFF333333) : Colors.white,"
  );
  // Title color
  content = content.replaceFirst(
    "style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),",
    "style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),"
  );
  // Author color
  content = content.replaceFirst(
    "style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),",
    "style: TextStyle(fontSize: 9, color: isDark ? Colors.white70 : AppColors.textSecondary),"
  );

  // 5. Inject isDark into _buildMetricsSection
  content = content.replaceFirst(
    'Widget _buildMetricsSection(\n    BuildContext context,\n    List<Lesson> lessons,\n    Map<String, dynamic> progress,\n  ) {',
    'Widget _buildMetricsSection(\n    BuildContext context,\n    List<Lesson> lessons,\n    Map<String, dynamic> progress,\n  ) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;'
  );

  // 6. Modify MetricsSection colors
  content = content.replaceFirst(
    "style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),",
    "style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),"
  );
  content = content.replaceFirst(
    "style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),",
    "style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textSecondary),"
  );
  content = content.replaceFirst(
    "style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),", // Second one (Recent Activity)
    "style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),"
  );
  content = content.replaceFirst(
    "const Text('No activity yet.', style: TextStyle(color: AppColors.textSecondary))",
    "Text('No activity yet.', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary))"
  );
  content = content.replaceFirst(
    "style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),",
    "style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary),"
  );
  // Also fix divider color to match dark mode implicitly or explicitly
  content = content.replaceFirst(
    "separatorBuilder: (c, i) => Divider(color: AppColors.divider),",
    "separatorBuilder: (c, i) => Divider(color: isDark ? Colors.grey[700] : AppColors.divider),"
  );

  file.writeAsStringSync(content);
}
