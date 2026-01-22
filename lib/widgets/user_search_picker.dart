import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/database_service.dart';

class UserSearchPicker extends StatefulWidget {
  final List<String> selectedUserIds;
  final ValueChanged<List<String>> onChanged;

  const UserSearchPicker({
    super.key,
    required this.selectedUserIds,
    required this.onChanged,
  });

  @override
  State<UserSearchPicker> createState() => _UserSearchPickerState();
}

class _UserSearchPickerState extends State<UserSearchPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await DatabaseService.instance.fetchUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredUsers = _allUsers);
    } else {
      setState(() {
        _filteredUsers = _allUsers.where((u) {
          final name = (u['username'] ?? '').toString().toLowerCase();
          final email = (u['email'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      });
    }
  }

  void _toggleUser(String uid) {
    final newSelection = List<String>.from(widget.selectedUserIds);
    if (newSelection.contains(uid)) {
      newSelection.remove(uid);
    } else {
      newSelection.add(uid);
    }
    widget.onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Row(
            children: [
              const Icon(CupertinoIcons.person_add, size: 20),
              const SizedBox(width: 8),
              Text(
                'Limit Access to Specific Users',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Icon(
                _isExpanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 16,
              ),
            ],
          ),
        ),
        if (widget.selectedUserIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedUserIds.map((uid) {
                final user = _allUsers.firstWhere(
                  (u) => u['uid'] == uid,
                  orElse: () => {'username': 'Unknown', 'email': '...'},
                );
                return Chip(
                  label: Text(user['username'] ?? user['email']),
                  onDeleted: () => _toggleUser(uid),
                );
              }).toList(),
            ),
          ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: const Icon(CupertinoIcons.search),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final uid = user['uid'] as String;
                      final isSelected = widget.selectedUserIds.contains(uid);
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(
                            (user['username'] ?? '?')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(user['username'] ?? 'Unknown'),
                        subtitle: Text(user['email'] ?? 'No Email'),
                        trailing: isSelected
                            ? const Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                color: Colors.green,
                              )
                            : const Icon(CupertinoIcons.circle),
                        onTap: () => _toggleUser(uid),
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
