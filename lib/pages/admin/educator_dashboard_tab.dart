import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';

class EducatorDashboardTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Function(int)? onTabChange;
  const EducatorDashboardTab({super.key, required this.userData, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid ?? '';
    final username = userData['username'] ?? 'Educator';
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
              Text(
                'Welcome, $username!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'Monitor your teaching progress and student engagement in real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final avgRating = (userData['averageRating'] ?? 0.0).toDouble();
                  
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('lessons').where('createdByUid', isEqualTo: uid).snapshots(),
                    builder: (context, lessonSnap) {
                      final lessonCount = lessonSnap.data?.docs.length ?? 0;
                      
                      return Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildStatCard('Total Lessons', lessonCount.toString(), Icons.book, brandGreen),
                          _buildStatCard('Educator Rating', avgRating.toStringAsFixed(1), Icons.star, Colors.amber),
                        ],
                      );
                    },
                  );
                },
              ),
              
              const SizedBox(height: 64),
              
              // Quick Actions Header
              const Text(
                'Quick Actions', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildQuickAction(
                    context, 
                    'Create New Lesson', 
                    Icons.add_circle_outline, 
                    brandGreen, 
                    () => onTabChange?.call(1)
                  ),
                  const SizedBox(width: 24),
                  _buildQuickAction(
                    context, 
                    'English Assessment', 
                    Icons.assignment_turned_in_outlined, 
                    Colors.blue, 
                    () => onTabChange?.call(4)
                  ),
                ],
              ),
              
              const SizedBox(height: 64),
              _buildRecentActivitySection(),
            ],
          ),
        ),
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
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
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

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 44),
                const SizedBox(height: 16),
                Text(
                  label, 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_graph_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Engagement Insights', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'Keep track of your teaching impact. Detailed charts and subscriber analytics will be displayed here as your classroom grows.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}
