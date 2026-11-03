import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A robust, responsive dialog component designed to prevent overflow bugs
/// across varying screen widths (e.g. 320dp - 412dp) and large accessibility text scalers.
///
/// Features:
/// - Pinned header with overflow-safe title
/// - Scrollable body wrapped in [Flexible] + [SingleChildScrollView]
/// - Pinned footer actions accounting for [MediaQuery.viewPaddingOf(context).bottom]
/// - Clamped width and height constraints so it never exceeds the screen viewport
class ResponsiveDialog extends StatelessWidget {
  /// Dialog title, either as a [String] or custom [Widget].
  final dynamic title;

  /// Optional subtitle or helper text.
  final dynamic subtitle;

  /// Optional leading icon or widget in the header.
  final Widget? leading;

  /// Optional trailing widget in the header (defaults to a close [IconButton]).
  final Widget? trailing;

  /// Whether to show the default close button in the header if [trailing] is null.
  final bool showCloseButton;

  /// Callback when the close button is tapped. Defaults to `Navigator.pop(context)`.
  final VoidCallback? onClose;

  /// The main content of the dialog.
  final Widget child;

  /// Optional pinned bottom actions. Can be a [Widget] or [List<Widget>].
  final dynamic actions;

  /// Whether the body should be wrapped in a [SingleChildScrollView]. Defaults to `true`.
  final bool scrollable;

  /// Maximum allowed width for the dialog. Defaults to 540.
  final double maxWidth;

  /// Maximum allowed fraction of screen height (e.g. 0.85 for 85%).
  final double maxHeightFactor;

  /// Dialog background color. Defaults to theme surface color.
  final Color? backgroundColor;

  /// Dialog shape border. Defaults to 24px rounded corners.
  final ShapeBorder? shape;

  /// Clip behavior. Defaults to [Clip.antiAlias].
  final Clip clipBehavior;

  /// Inset padding around the dialog.
  final EdgeInsets? insetPadding;

  /// Padding for the scrollable body content.
  final EdgeInsetsGeometry? contentPadding;

  /// Padding for the pinned header.
  final EdgeInsetsGeometry? headerPadding;

  /// Padding for the pinned footer actions.
  final EdgeInsetsGeometry? actionsPadding;

  /// Header decoration / background.
  final Decoration? headerDecoration;

  const ResponsiveDialog({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.showCloseButton = true,
    this.onClose,
    required this.child,
    this.actions,
    this.scrollable = true,
    this.maxWidth = 540,
    this.maxHeightFactor = 0.88,
    this.backgroundColor,
    this.shape,
    this.clipBehavior = Clip.antiAlias,
    this.insetPadding,
    this.contentPadding,
    this.headerPadding,
    this.actionsPadding,
    this.headerDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    final bottomPadding = media.viewPadding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isNarrow = screenWidth < 450;
    final resolvedInset = insetPadding ??
        EdgeInsets.symmetric(
          horizontal: isNarrow ? 12.0 : 24.0,
          vertical: isNarrow ? 16.0 : 28.0,
        );

    final resolvedMaxWidth = min(maxWidth, max(280.0, screenWidth - 24.0));
    final resolvedMaxHeight = screenHeight * maxHeightFactor;

    final resolvedBg = backgroundColor ??
        (isDark ? const Color(0xFF1E293B) : Theme.of(context).colorScheme.surface);

    final resolvedShape = shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isNarrow ? 20 : 24),
          side: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        );

    final hasHeader = title != null || leading != null || showCloseButton || trailing != null;

    Widget? headerWidget;
    if (hasHeader) {
      headerWidget = Container(
        decoration: headerDecoration ??
            BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                ),
              ),
            ),
        padding: headerPadding ??
            EdgeInsets.fromLTRB(
              isNarrow ? 16 : 24,
              isNarrow ? 14 : 20,
              isNarrow ? 10 : 16,
              isNarrow ? 14 : 18,
            ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title is Widget)
                    title as Widget
                  else if (title is String && (title as String).isNotEmpty)
                    Text(
                      title as String,
                      style: GoogleFonts.outfit(
                        fontSize: isNarrow ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  if (subtitle is Widget) ...[
                    const SizedBox(height: 2),
                    subtitle as Widget,
                  ] else if (subtitle is String && (subtitle as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle as String,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showCloseButton)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                tooltip: 'Close',
                onPressed: onClose ?? () => Navigator.of(context).pop(),
              ),
          ],
        ),
      );
    }

    Widget? actionsWidget;
    if (actions != null) {
      Widget actionsContent;
      if (actions is List<Widget>) {
        actionsContent = Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: actions as List<Widget>,
        );
      } else {
        actionsContent = actions as Widget;
      }

      actionsWidget = Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            ),
          ),
        ),
        padding: actionsPadding ??
            EdgeInsets.fromLTRB(
              isNarrow ? 16 : 24,
              12,
              isNarrow ? 16 : 24,
              12 + bottomPadding,
            ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: actionsContent,
        ),
      );
    }

    Widget bodyWidget = child;
    if (scrollable) {
      bodyWidget = Flexible(
        child: SingleChildScrollView(
          padding: contentPadding ??
              EdgeInsets.all(isNarrow ? 16.0 : 24.0),
          child: child,
        ),
      );
    } else {
      bodyWidget = Padding(
        padding: contentPadding ??
            EdgeInsets.all(isNarrow ? 16.0 : 24.0),
        child: child,
      );
    }

    return Dialog(
      backgroundColor: resolvedBg,
      shape: resolvedShape,
      clipBehavior: clipBehavior,
      insetPadding: resolvedInset,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: resolvedMaxWidth,
          maxHeight: resolvedMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?headerWidget,
            bodyWidget,
            ?actionsWidget,
          ],
        ),
      ),
    );
  }
}

/// A responsive page wrapper/scaffold ensuring content stays nicely centered on
/// desktop and prevents overflowing on narrow mobile devices.
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Color? backgroundColor;
  final double maxContentWidth;
  final bool centerContent;
  final EdgeInsetsGeometry? padding;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.drawer,
    this.backgroundColor,
    this.maxContentWidth = 1200,
    this.centerContent = true,
    this.padding,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (centerContent) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: content,
        ),
      );
    }

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    content = SafeArea(
      top: safeAreaTop,
      bottom: safeAreaBottom,
      child: content,
    );

    return Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      drawer: drawer,
      backgroundColor: backgroundColor,
    );
  }
}
