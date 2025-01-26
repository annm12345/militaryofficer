import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:military_officer/views/telegraph/src/utils.dart';

/// A compass for flutter_map that shows the map rotation and allows resetting
/// the rotation back to 0.
class MapCompass extends StatefulWidget {
  /// Use this constructor if you want to customize your compass.
  ///
  /// Use [MapCompass.cupertino] to use the default.
  const MapCompass({
    required this.icon,
    super.key,
    this.rotationOffset = 0,
    this.rotationDuration = const Duration(seconds: 1),
    this.animationCurve = Curves.fastOutSlowIn,
    this.onPressed,
    this.onPressedOverridesDefault = true,
    this.hideIfRotatedNorth = false,
    this.alignment = Alignment.topRight,
    this.padding = const EdgeInsets.all(10),
  });

  /// The default map compass based on the Cupertino compass icon.
  const MapCompass.cupertino({
    super.key,
    this.onPressed,
    this.hideIfRotatedNorth = false,
    this.onPressedOverridesDefault = true,
    this.rotationDuration = const Duration(seconds: 1),
    this.animationCurve = Curves.fastOutSlowIn,
    this.alignment = Alignment.topRight,
    this.padding = const EdgeInsets.all(10),
  })  : rotationOffset = -45,
        icon = const Stack(
          children: [
            Icon(CupertinoIcons.compass, color: Colors.red, size: 50),
            Icon(CupertinoIcons.compass_fill, color: Colors.white54, size: 50),
            Icon(CupertinoIcons.circle, color: Colors.black, size: 50),
          ],
        );

  /// This child widget, for example an [Icon] widget with a compass icon.
  final Widget icon;

  /// Sometimes icons are rotated themselves. Use this to fix the rotation offset.
  final double rotationOffset;

  /// Overrides the default behavior for a tap or click event.
  ///
  /// This will override the default behavior.
  final VoidCallback? onPressed;

  /// Set to true to hide the compass while the map is not rotated.
  ///
  /// Defaults to false (always visible).
  final bool hideIfRotatedNorth;

  /// The [Alignment] of the compass on the map.
  ///
  /// Defaults to [Alignment.topRight].
  final Alignment alignment;

  /// The padding of the compass widget.
  ///
  /// Defaults to 10px on all sides.
  final EdgeInsets padding;

  /// The duration of the rotation animation.
  ///
  /// Defaults to 1 second.
  final Duration rotationDuration;

  /// The curve of the rotation animation.
  final Curve animationCurve;

  /// When [onPressedOverridesDefault] is true, [onPressed] overrides
  /// the default rotation behavior.
  final bool onPressedOverridesDefault;

  @override
  State<MapCompass> createState() => _MapCompassState();
}

class _MapCompassState extends State<MapCompass> with TickerProviderStateMixin {
  AnimationController? _animationController;
  late Animation<double> _rotateAnimation;
  late Tween<double> _rotationTween;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.maybeOf(context);

    // If no camera is found or compass is hidden when rotated north, return an empty widget.
    if (camera == null || (widget.hideIfRotatedNorth && camera.rotation == 0)) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: widget.alignment,
      child: Padding(
        padding: widget.padding,
        child: Transform.rotate(
          angle: (camera.rotation + widget.rotationOffset) * deg2Rad,
          child: IconButton(
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
            icon: widget.icon,
            onPressed: () {
              if (widget.onPressedOverridesDefault) {
                if (widget.onPressed != null) {
                  widget.onPressed!();
                } else {
                  _resetRotation(camera);
                }
              } else {
                _resetRotation(camera);
                widget.onPressed?.call();
              }
            },
          ),
        ),
      ),
    );
  }

  void _resetRotation(MapCamera camera) {
    // Current rotation of the map
    final rotation = camera.rotation;
    // Nearest north (0°, 360°, -360°, ...)
    final endRotation = (rotation / 360).round() * 360.0;
    // Don't start animation if rotation doesn't need to change
    if (rotation == endRotation) return;

    _animationController = AnimationController(
      duration: widget.rotationDuration,
      vsync: this,
    )..addListener(_handleAnimation);
    _rotateAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: widget.animationCurve,
    );

    _rotationTween = Tween<double>(begin: rotation, end: endRotation);
    _animationController!.forward(from: 0);
  }

  void _handleAnimation() {
    final controller = MapController.maybeOf(context);
    if (controller != null) {
      controller.rotate(_rotationTween.evaluate(_rotateAnimation));
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
}
