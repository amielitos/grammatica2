import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../widgets/author_name_widget.dart';

class ValidatorDashboardTab extends StatelessWidget {
  final Function(int)? onReviewRequests;
  const ValidatorDashboardTab({super.key, this.onReviewRequests});

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF8CB31D);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Centered Header
              const Text(
                'Validator Dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'Instantly review and approve pending requests from educators and applicants.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              // Centered Stats Row
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'EDUCATOR').snapshots(),
                builder: (context, educSnap) {
                  final educCount = educSnap.data?.docs.length ?? 0;
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('lessons').where('validationStatus', isEqualTo: 'awaiting_approval').snapshots(),
                    builder: (context, lessonSnap) {
                      final lessonCount = lessonSnap.data?.docs.length ?? 0;
                      return StreamBuilder<List<EducatorApplication>>(
                        stream: DatabaseService.instance.streamEducatorApplications(),
                        builder: (context, appSnap) {
                          final appCount = appSnap.data?.length ?? 0;
                          
                          return Wrap(
                            spacing: 24,
                            runSpacing: 24,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildStatCard('Pending Lessons', lessonCount.toString(), Icons.pending_actions, Colors.orange),
                              _buildStatCard('Pending Applicants', appCount.toString(), Icons.person_add, Colors.blue),
                              _buildStatCard('Active Educators', educCount.toString(), Icons.school, brandGreen),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
              
              const SizedBox(height: 64),
              
              // Content Sections
              // Responsive Sections Wrapper
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;
                  return Flex(
                    direction: isNarrow ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Lessons
                      Expanded(
                        flex: isNarrow ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('New Lesson Requests', Icons.menu_book, brandGreen),
                            const SizedBox(height: 20),
                            _buildLessonsList(context),
                          ],
                        ),
                      ),
                      if (!isNarrow) const SizedBox(width: 40),
                      if (isNarrow) const SizedBox(height: 48),
                      // Section 2: Applicants
                      Expanded(
                        flex: isNarrow ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Applicant Requests', Icons.person_add_alt_1, Colors.blue),
                            const SizedBox(height: 20),
                            _buildApplicationsList(context),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.withOpacity(0.2), width: 2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLessonsList(BuildContext context) {
    return StreamBuilder<List<Lesson>>(
      stream: DatabaseService.instance.streamAwaitingApprovalLessons(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final lessons = snapshot.data ?? [];
        if (lessons.isEmpty) return _buildEmptyState('No new lesson requests.', Icons.check_circle_outline);

        return Column(
          children: lessons.map((l) => _buildLessonItem(context, l)).toList(),
        );
      }
    );
  }

  Widget _buildApplicationsList(BuildContext context) {
    return StreamBuilder<List<EducatorApplication>>(
      stream: DatabaseService.instance.streamEducatorApplications(type: 'educator'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final apps = snapshot.data ?? [];
        if (apps.isEmpty) return _buildEmptyState('No pending applications.', Icons.people_outline);

        return Column(
          children: apps.map((a) => _buildApplicationItem(context, a)).toList(),
        );
      }
    );
  }

  Widget _buildLessonItem(BuildContext context, Lesson l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: Colors.orange, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                AuthorName(uid: l.createdByUid, fallbackEmail: l.createdByEmail, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => onReviewRequests?.call(0), // Lessons tab
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withOpacity(0.1),
              foregroundColor: Colors.orange,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationItem(BuildContext context, EducatorApplication a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_outlined, color: Colors.blue, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.applicantEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Text('Educator verification', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => onReviewRequests?.call(2), // Educators tab
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              foregroundColor: Colors.blue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
