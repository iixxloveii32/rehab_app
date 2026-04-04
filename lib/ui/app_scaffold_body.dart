import 'package:flutter/material.dart';

import 'responsive.dart';

class AppScaffoldBody extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool safeTop;
  final bool safeBottom;
  final Alignment alignment;

  const AppScaffoldBody({
    super.key,
    required this.child,
    this.padding,
    this.safeTop = true,
    this.safeBottom = true,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = Responsive.horizontalPadding(context);

    return SafeArea(
      top: safeTop,
      bottom: safeBottom,
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.maxContentWidth(context),
          ),
          child: Padding(
            padding: padding ??
                EdgeInsets.symmetric(
                  horizontal: horizontal,
                  vertical: 16,
                ),
            child: child,
          ),
        ),
      ),
    );
  }
}