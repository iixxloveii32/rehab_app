import 'package:flutter/material.dart';

class Responsive {
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 700;
  }

  static double horizontalPadding(BuildContext context) {
    return isTablet(context) ? 24 : 16;
  }

  static double maxContentWidth(BuildContext context) {
    return isTablet(context) ? 840 : double.infinity;
  }

  static double sectionSpacing(BuildContext context) {
    return isTablet(context) ? 20 : 16;
  }

  static double cardRadius(BuildContext context) {
    return isTablet(context) ? 24 : 20;
  }

  static double titleFontSize(BuildContext context) {
    return isTablet(context) ? 22 : 20;
  }

  static double bodyFontSize(BuildContext context) {
    return isTablet(context) ? 17 : 16;
  }

  static double largeTitleFontSize(BuildContext context) {
    return isTablet(context) ? 28 : 24;
  }
}