import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../models/study_guide_models.dart';
import '../../theme/app_colors.dart';
import 'publish_content_dialogs.dart';

/// Interactive concept map powered by [GraphView], supporting pinch-to-zoom,
/// panning, and node inspection.
class MindMapView extends StatefulWidget {
  final MindMap mindMap;
  final String notebookId;
  final String outputId;
  final bool isLearnerView;
  final bool isShared;

  const MindMapView({
    super.key,
    required this.mindMap,
    required this.notebookId,
    required this.outputId,
    bool? isLearnerView,
    this.isShared = false,
  }) : isLearnerView = isLearnerView ?? isShared;

  @override
  State<MindMapView> createState() => _MindMapViewState();
}

class _MindMapViewState extends State<MindMapView> {
  final Graph _graph = Graph()..isTree = true;
  late BuchheimWalkerConfiguration _builder;
  final Map<String, Node> _nodeMap = {};

  @override
  void initState() {
    super.initState();
    _buildGraph();

    _builder = BuchheimWalkerConfiguration()
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
      ..siblingSeparation = 24
      ..levelSeparation = 48
      ..subtreeSeparation = 32;
  }

  void _buildGraph() {
    // 1. Create GraphView Node instances
    for (final node in widget.mindMap.nodes) {
      final gNode = Node.Id(node.id);
      _nodeMap[node.id] = gNode;
      _graph.addNode(gNode);
    }

    // 2. Connect parent to child edges
    for (final node in widget.mindMap.nodes) {
      if (node.parentId != null && _nodeMap.containsKey(node.parentId)) {
        final fromNode = _nodeMap[node.parentId]!;
        final toNode = _nodeMap[node.id]!;
        _graph.addEdge(fromNode, toNode);
      }
    }

    // 3. Connect explicit edges if any
    for (final edge in widget.mindMap.edges) {
      if (_nodeMap.containsKey(edge.fromId) && _nodeMap.containsKey(edge.toId)) {
        final from = _nodeMap[edge.fromId]!;
        final to = _nodeMap[edge.toId]!;
        try {
          _graph.addEdge(from, to);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Pan and Zoom Canvas
        InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(300),
          minScale: 0.2,
          maxScale: 2.5,
          child: Padding(
            padding: const EdgeInsets.all(80.0),
            child: GraphView(
              graph: _graph,
              algorithm: BuchheimWalkerAlgorithm(
                _builder,
                TreeEdgeRenderer(_builder),
              ),
              paint: Paint()
                ..color = isDark ? const Color(0xFF4A6B2F) : const Color(0xFFB0C99B)
                ..strokeWidth = 2
                ..style = PaintingStyle.stroke,
              builder: (Node node) {
                final nodeId = node.key!.value as String;
                final dataNode = widget.mindMap.nodes.firstWhere(
                  (n) => n.id == nodeId,
                  orElse: () => MindMapNode(id: nodeId, label: nodeId),
                );

                return _buildNodeWidget(dataNode, isDark);
              },
            ),
          ),
        ),

        // Header and Controls Floating Bar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1E261D) : Colors.white).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_rounded, color: Color(0xFFEC4899), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.mindMap.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Pinch to zoom, drag to pan • Tap any concept node for details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isLearnerView)
                  IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                    tooltip: 'Publish to Curriculum',
                    onPressed: () => _publishMindMap(context),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeWidget(MindMapNode node, bool isDark) {
    final isRoot = node.parentId == null;
    Color nodeColor = const Color(0xFF10B981);

    if (node.colorHex != null && node.colorHex!.isNotEmpty) {
      try {
        final hex = node.colorHex!.replaceAll('#', '');
        nodeColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _showNodeDetails(node),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isRoot ? 20 : 14,
          vertical: isRoot ? 14 : 10,
        ),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B241A) : Colors.white,
          borderRadius: BorderRadius.circular(isRoot ? 20 : 14),
          border: Border.all(
            color: nodeColor,
            width: isRoot ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: nodeColor.withValues(alpha: isRoot ? 0.35 : 0.15),
              blurRadius: isRoot ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (node.category != null && !isRoot)
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  node.category!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: nodeColor,
                  ),
                ),
              ),
            Text(
              node.label,
              style: TextStyle(
                fontSize: isRoot ? 16 : 13,
                fontWeight: isRoot ? FontWeight.w800 : FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNodeDetails(MindMapNode node) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (node.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    node.category!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                node.label,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                node.description != null && node.description!.isNotEmpty
                    ? node.description!
                    : 'Concept node derived from notebook source materials.',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _publishMindMap(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => PublishContentDialog(
        notebookId: widget.notebookId,
        output: widget.mindMap.toNotebookOutput(
          id: widget.outputId,
          notebookId: widget.notebookId,
        ),
        onPublished: () {
          setState(() {});
        },
      ),
    );
  }
}
