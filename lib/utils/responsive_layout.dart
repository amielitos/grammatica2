import 'package:flutter/material.dart';

// Responsive layout utility classes
class ResponsiveLayout {
  static const double mobileMaxWidth = 768.0;
  static const double tabletMaxWidth = 1024.0;
  static const double desktopMinWidth = 1025.0;

  // Determine if the current screen is mobile-sized
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= mobileMaxWidth;
  }

  // Determine if the current screen is tablet-sized
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > mobileMaxWidth && width <= tabletMaxWidth;
  }

  // Determine if the current screen is desktop-sized
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > tabletMaxWidth;
  }

  // Get the current device type
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width <= mobileMaxWidth) {
      return DeviceType.mobile;
    } else if (width <= tabletMaxWidth) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  // Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.all(16.0);
      case DeviceType.tablet:
        return const EdgeInsets.all(24.0);
      case DeviceType.desktop:
        return const EdgeInsets.all(32.0);
    }
  }

  // Get responsive container width
  static double getResponsiveContainerWidth(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return double.infinity; // Full width on mobile
      case DeviceType.tablet:
        return double.infinity; // Full width on tablet
      case DeviceType.desktop:
        return double
            .infinity; // Full width on desktop (will be centered with max width)
    }
  }

  // Get responsive text style
  static TextStyle getResponsiveTextStyle(
    BuildContext context, {
    TextStyle? baseStyle,
  }) {
    final deviceType = getDeviceType(context);
    final scale = deviceType == DeviceType.mobile ? 0.9 : 1.0;
    return (baseStyle ?? const TextStyle()).copyWith(
      fontSize: (baseStyle?.fontSize ?? 16.0) * scale,
    );
  }

  // Get responsive button size
  static Size getResponsiveButtonSize(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return const Size(double.infinity, 48.0);
      case DeviceType.tablet:
        return const Size(double.infinity, 50.0);
      case DeviceType.desktop:
        return const Size(double.infinity, 52.0);
    }
  }

  // Get responsive max width for content containers
  static double getMaxContentWidth(BuildContext context) {
    if (isMobile(context)) {
      return double.infinity; // Full width on mobile
    } else if (isTablet(context)) {
      return 600.0; // Moderate width on tablet
    } else {
      return 800.0; // Limited width on desktop for better readability
    }
  }

  // Get responsive font size scaling factor
  static double getFontScale(BuildContext context) {
    if (isMobile(context)) {
      return 0.9; // Slightly smaller on mobile
    } else if (isTablet(context)) {
      return 1.0; // Standard size on tablet
    } else {
      return 1.1; // Slightly larger on desktop
    }
  }
}

enum DeviceType { mobile, tablet, desktop }

// Responsive widget that adapts to screen size
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? fallback;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

// Improved responsive container that constrains width based on screen size and prevents overflow
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? maxWidth;
  final Color? color;
  final Decoration? decoration;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.maxWidth,
    this.color,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Container(
            width: ResponsiveLayout.getResponsiveContainerWidth(context),
            padding: padding ?? ResponsiveLayout.getResponsivePadding(context),
            margin: margin,
            constraints: BoxConstraints(
              maxWidth:
                  maxWidth ?? ResponsiveLayout.getMaxContentWidth(context),
            ),
            color: color,
            decoration: decoration,
            child: child,
          ),
        );
      },
    );
  }
}

// Responsive scaffold that handles both mobile and desktop layouts
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? actions;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.actions,
    this.drawer,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout.isMobile(context)
        ? Scaffold(
            appBar: appBar,
            body: body,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            drawer: drawer,
            bottomNavigationBar: bottomNavigationBar,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            extendBody: extendBody,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
          )
        : Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                if (drawer != null) drawer!,
                if (body != null) Expanded(child: body!),
              ],
            ),
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            bottomNavigationBar: bottomNavigationBar,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            extendBody: extendBody,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
          );
  }
}

// Responsive grid view that adapts the number of columns based on screen size
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final int mobileCrossAxisCount;
  final int tabletCrossAxisCount;
  final int desktopCrossAxisCount;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.mobileCrossAxisCount = 1,
    this.tabletCrossAxisCount = 2,
    this.desktopCrossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    int crossAxisCount;
    if (ResponsiveLayout.isMobile(context)) {
      crossAxisCount = mobileCrossAxisCount;
    } else if (ResponsiveLayout.isTablet(context)) {
      crossAxisCount = tabletCrossAxisCount;
    } else {
      crossAxisCount = desktopCrossAxisCount;
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

// Responsive dialog that adjusts size based on screen
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final double? widthRatio;
  final double? heightRatio;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.widthRatio,
    this.heightRatio,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);
    final mediaQuery = MediaQuery.of(context);

    double width;
    double height;

    switch (deviceType) {
      case DeviceType.mobile:
        width = mediaQuery.size.width * (widthRatio ?? 0.9);
        height = mediaQuery.size.height * (heightRatio ?? 0.6);
        break;
      case DeviceType.tablet:
        width = mediaQuery.size.width * (widthRatio ?? 0.7);
        height = mediaQuery.size.height * (heightRatio ?? 0.7);
        break;
      case DeviceType.desktop:
        width = mediaQuery.size.width * (widthRatio ?? 0.5);
        height = mediaQuery.size.height * (heightRatio ?? 0.6);
        break;
    }

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: (mediaQuery.size.width - width) / 2,
        vertical: (mediaQuery.size.height - height) / 2,
      ),
      child: Container(
        width: width,
        height: height,
        constraints: BoxConstraints(maxWidth: width, maxHeight: height),
        child: child,
      ),
    );
  }
}

// SafeArea wrapper that prevents overflow errors
class SafeResponsiveWidget extends StatelessWidget {
  final Widget child;
  final EdgeInsets minimum;
  final bool maintainBottomViewPadding;

  const SafeResponsiveWidget({
    super.key,
    required this.child,
    this.minimum = EdgeInsets.zero,
    this.maintainBottomViewPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SafeArea(
          minimum: minimum,
          maintainBottomViewPadding: maintainBottomViewPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
