import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'educator_profile_page.dart';

import '../theme/app_colors.dart';

class BrowseEducatorsTab extends StatefulWidget {
  const BrowseEducatorsTab({super.key, required this.user});
  final User user;

  @override
  State<BrowseEducatorsTab> createState() => _BrowseEducatorsTabState();
}

class _BrowseEducatorsTabState extends State<BrowseEducatorsTab> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar Part
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Browse Educators',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _searchCtrl,
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search educators by name...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.5),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),

        // List Part
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseService.instance.streamEducators(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allEducators = snapshot.data ?? [];
              final filtered = allEducators.where((e) {
                final uid = e['uid'] as String? ?? '';
                if (uid == widget.user.uid) return false;
                final name = (e['username'] as String? ?? '').toLowerCase();
                return name.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'No educators found matching your search.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final educator = filtered[index];
                  final photoUrl = educator['photoUrl'] as String?;
                  final name = educator['username'] as String? ?? 'Educator';
                  final bio =
                      educator['bio'] as String? ?? 'No bio description';

                  return Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EducatorProfilePage(
                              educator: educator,
                              currentUser: widget.user,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                backgroundImage:
                                    (photoUrl != null && photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: (photoUrl == null || photoUrl.isEmpty)
                                    ? const Icon(Icons.person_rounded,
                                        color: AppColors.primary)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                      ),
                                      if ((educator['averageRating'] ?? 0) >
                                          0) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.star_rounded,
                                          size: 18,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (educator['averageRating'] ?? 0.0)
                                              .toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    bio,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
