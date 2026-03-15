import 'package:flutter/material.dart';

class AppSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearch;
  final VoidCallback? onFilterPressed;

  const AppSearchBar({
    super.key,
    required this.hintText,
    required this.onSearch,
    this.onFilterPressed,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  final TextEditingController _controller = TextEditingController();

  void _handleSearch() {
    widget.onSearch(_controller.text.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.onFilterPressed != null)
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: widget.onFilterPressed,
          ),
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _handleSearch(),
            decoration: InputDecoration(hintText: widget.hintText),
          ),
        ),
        IconButton(icon: const Icon(Icons.search), onPressed: _handleSearch),
      ],
    );
  }
}
