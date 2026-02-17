import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.shape = BoxShape.rectangle,
  });

  /// Factory for circular skeleton (profile pics)
  factory SkeletonLoader.circle({
    required double size,
  }) {
    return SkeletonLoader(
      width: size,
      height: size,
      shape: BoxShape.circle,
    );
  }

  /// Factory for rectangular skeleton (post images)
  factory SkeletonLoader.square({
    required double size,
    double borderRadius = 8.0,
  }) {
    return SkeletonLoader(
      width: size,
      height: size,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
        ),
      ),
    );
  }
}
