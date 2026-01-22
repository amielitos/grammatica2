import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/role_service.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';

class UserVisibilitySelector extends StatefulWidget {
  final List<String> selectedUserIds;
  final Function(List<String>) onChanged;

  const UserVisibilitySelector({
    super.key,
    required this.selectedUserIds,
    required this.onChanged,
  });

  @override
  State<UserVisibilitySelector> createState() => _UserVisibilitySelectorState();
}

class _UserVisibilitySelectorState extends State<UserVisibilitySelector> {
  String _searchQuery = '';
  final TextEditingController _controller = TextEditingController();

  void _toggleUser(String uid) {
    final newList = List<String>.from(widget.selectedUserIds);
    if (newList.contains(uid)) {
      newList.remove(uid);
    } else {
      newList.add(uid);
    }
    widget.onChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specific User Visibility',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Search users to grant access...',
            prefixIcon: const Icon(CupertinoIcons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _controller.clear();
                      });
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim();
            });
          },
        ),
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: RoleService.instance.allUsersStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final users = snapshot.data!
                  .where((u) {
                    final query = _searchQuery.toLowerCase();
                    final name = (u['username'] as String? ?? '').toLowerCase();
                    final email = (u['email'] as String? ?? '').toLowerCase();
                    return name.contains(query) || email.contains(query);
                  })
                  .take(5)
                  .toList();

              if (users.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'No users found',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              }

              return GlassCard(
                child: Column(
                  children: users.map((u) {
                    final uid = u['uid'] as String;
                    final isSelected = widget.selectedUserIds.contains(uid);
                    return ListTile(
                      dense: true,
                      title: Text(u['username'] ?? 'Unknown'),
                      subtitle: Text(u['email'] ?? ''),
                      trailing: Icon(
                        isSelected
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.add_circled,
                        color: isSelected ? AppColors.primaryGreen : null,
                      ),
                      onTap: () => _toggleUser(uid),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        if (widget.selectedUserIds.isNotEmpty) ...[
          const Text(
            'Users with access:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: RoleService.instance.allUsersStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final selectedUsers = snapshot.data!
                  .where((u) => widget.selectedUserIds.contains(u['uid']))
                  .toList();

              return Wrap(
                spacing: 8,
                runSpacing: 4,
                children: selectedUsers.map((u) {
                  return Chip(
                    label: Text(
                      u['username'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onDeleted: () => _toggleUser(u['uid']),
                    deleteIcon: const Icon(CupertinoIcons.xmark, size: 12),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}
