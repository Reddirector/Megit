import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Premium glass container — Megit's signature surface treatment.
/// Layered: backdrop blur → tinted fill → subtle inner gradient → hairline border.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? backgroundColor;
  final double borderOpacity;
  final bool showInnerGradient;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.blur = 18,
    this.backgroundColor,
    this.borderOpacity = 0.10,
    this.showInnerGradient = true,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.glassBackground,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderOpacity),
                width: 0.8,
              ),
              gradient: showInnerGradient
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.white.withValues(alpha: 0.005),
                      ],
                    )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A premium gradient-bordered card — used for hero / featured items.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? gradientColor;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.gradientColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = gradientColor ?? Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.18),
                AppColors.backgroundElevated,
                AppColors.backgroundElevated,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
