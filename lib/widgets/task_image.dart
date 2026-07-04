import 'package:flutter/material.dart';

class TaskImage extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const TaskImage({
    super.key,
    required this.imagePath,
    this.width = 96,
    this.height = 96,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: borderRadius,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey.shade500,
              size: 32,
            ),
          );
        },
      ),
    );
  }
}