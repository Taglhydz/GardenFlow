import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Opening of a plan (0 -> 1), played backwards when it closes : a garden from the mini plan of its card,
/// a parcel from its shape on the garden plan. That small picture becomes the plan ([EntranceReveal]) and
/// the buttons around it slide in from the edges ([EntranceSlide]).
/// Without a PlanEntrance above them, these widgets show their child as it is.
class PlanEntrance extends InheritedWidget {
  const PlanEntrance({super.key, required this.animation, required this.from, required super.child});

  static const duration = Duration(milliseconds: 650);

  final Animation<double> animation;

  /// Where the plan comes from on the screen (global rect), null when it is not known
  final Rect? Function() from;

  /// Page opening a plan (parcel screen) : the page below is seen around the plan while it grows
  /// (a route is not opaque during its transition), then hidden.
  static Route<void> route({required Rect? Function() from, required WidgetBuilder builder}) {
    return PageRouteBuilder<void>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, _) => PlanEntrance(animation: animation, from: from, child: builder(context)),
    );
  }

  static PlanEntrance? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PlanEntrance>();

  @override
  bool updateShouldNotify(PlanEntrance old) => old.animation != animation || old.from != from;
}

/// Slides its child in from [offset] (in sizes of the child : Offset(0, -1) = from one height above).
/// It starts at [start] of the entrance, so the plan is already there when the buttons arrive.
class EntranceSlide extends StatelessWidget {
  const EntranceSlide({super.key, required this.offset, this.start = 0.4, required this.child});

  final Offset offset;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final entrance = PlanEntrance.of(context);
    if (entrance == null) return child;

    return SlideTransition(
      position: entrance.animation.drive(
        Tween(begin: offset, end: Offset.zero).chain(CurveTween(curve: Interval(start, 1, curve: Curves.easeOutCubic))),
      ),
      child: child,
    );
  }
}

/// Background of a page opened with [PlanEntrance.route] (its Scaffold is transparent) : it appears while the
/// plan grows, so the page below is seen around the plan at first.
class EntranceBackdrop extends StatelessWidget {
  const EntranceBackdrop({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final entrance = PlanEntrance.of(context);
    final background = ColoredBox(color: color);

    return Stack(
      children: [
        Positioned.fill(
          child: entrance == null
              ? background
              : FadeTransition(opacity: entrance.animation.drive(CurveTween(curve: const Interval(0.2, 0.8))), child: background),
        ),
        child,
      ],
    );
  }
}

/// The plan grows out of the mini plan of the card : it moves to its place while zooming, and the part of the
/// screen it covers spreads from the mini plan to the whole area (the grid extends over the screen).
class EntranceReveal extends StatelessWidget {
  const EntranceReveal({super.key, required this.child});

  /// Part of the entrance used by the plan, the buttons arrive during the rest
  static const _end = 0.7;

  /// Corners of the mini plan
  static const _radius = 10.0;

  /// Near the mini plan, the plan crossfades with it : both don't draw the garden exactly the same way
  /// (margins, grid), so the plan would jump a little when it is replaced by the mini plan (and back)
  static const _crossfade = 0.2;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final entrance = PlanEntrance.of(context);
    if (entrance == null) return child;

    final progress = entrance.animation.drive(CurveTween(curve: const Interval(0, _end, curve: Curves.easeInOutCubic)));

    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final t = progress.value;
        // area of the plan on the screen, known after its first layout
        final box = context.findRenderObject() as RenderBox?;
        final from = entrance.from();
        final area = box != null && box.hasSize && box.attached ? box.localToGlobal(Offset.zero) & box.size : null;

        var clip = RRect.fromRectAndRadius(Offset.zero & (area?.size ?? Size.zero), Radius.zero);
        var transform = Matrix4.identity();
        var opacity = 1.0;
        if (t < 1) {
          if (area == null || from == null) {
            // nothing to grow from : the plan simply fades in
            opacity = area == null ? 0 : t;
          } else {
            opacity = Curves.easeOut.transform((t / _crossfade).clamp(0.0, 1.0));
            final fromLocal = from.shift(-area.topLeft);
            final full = Offset.zero & area.size;
            clip = RRect.fromRectAndRadius(Rect.lerp(fromLocal, full, t)!, Radius.circular(lerpDouble(_radius, 0, t)!));
            // the plan is drawn at the size of the mini plan, centered on it, then goes back to its place
            final scale = lerpDouble(fromLocal.width / full.width, 1, t)!;
            final center = Offset.lerp(fromLocal.center, full.center, t)!;
            transform = Matrix4.translationValues(center.dx, center.dy, 0)
              ..scaleByDouble(scale, scale, 1, 1)
              ..translateByDouble(-full.center.dx, -full.center.dy, 0, 1);
          }
        }

        // same widgets on every frame : the plan below is never rebuilt
        return Opacity(
          opacity: opacity,
          child: ClipRRect(
            clipper: _RRectClipper(clip, enabled: t < 1),
            child: Transform(transform: transform, child: child),
          ),
        );
      },
    );
  }
}

class _RRectClipper extends CustomClipper<RRect> {
  _RRectClipper(this.rrect, {required this.enabled});

  final RRect rrect;

  /// Once the plan is in place, it is not clipped at all
  final bool enabled;

  @override
  RRect getClip(Size size) => enabled ? rrect : RRect.fromRectAndRadius(Offset.zero & size, Radius.zero);

  @override
  bool shouldReclip(_RRectClipper old) => old.rrect != rrect || old.enabled != enabled;
}
