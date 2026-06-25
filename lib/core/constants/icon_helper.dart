import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Helper widget to display CRM SVG icons
/// Requires flutter_svg package: flutter pub add flutter_svg
class AppSVGIcon extends StatelessWidget {
  final String iconName;
  final double size;
  final Color? color;

  const AppSVGIcon({
    super.key,
    required this.iconName,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/$iconName.svg',
      width: size,
      height: size,
      // Use the 'color' parameter which is supported in all versions
      // Pass null to use the original SVG colors
      color: color,
    );
  }
}

/// Extension to add CRM icon methods to Icon widget
extension AppSVGIconExtension on Icon {
  /// Creates a container with colored background matching the icon
  Widget withColoredBackground({
    double padding = 12,
    double borderRadius = 12,
    Color? backgroundColor,
  }) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor ?? color?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: this,
    );
  }
}

/// Quick icon with background helper
class AppSVGIconButton extends StatelessWidget {
  final String iconName;
  final double iconSize;
  final double containerSize;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double borderRadius;

  const AppSVGIconButton({
    super.key,
    required this.iconName,
    this.iconSize = 24,
    this.containerSize = 48,
    this.color,
    this.backgroundColor,
    this.onTap,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: backgroundColor ??
              color?.withOpacity(0.1) ??
              Colors.grey.shade100,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: AppSVGIcon(
            iconName: iconName,
            size: iconSize,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Icon with label widget for grid layouts
class AppSVGIconWithLabel extends StatelessWidget {
  final String iconName;
  final String label;
  final Color color;
  final double iconSize;
  final VoidCallback? onTap;

  const AppSVGIconWithLabel({
    super.key,
    required this.iconName,
    required this.label,
    required this.color,
    this.iconSize = 28,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: AppSVGIcon(
              iconName: iconName,
              size: iconSize,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
