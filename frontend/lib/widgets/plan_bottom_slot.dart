import 'package:flutter/material.dart';

/// Bottom of a plan screen, in Scaffold.bottomNavigationBar with `extendBody: true` : its buttons, or the bar
/// of the selected shape, or the drawing bar. The new one comes up from the bottom of the screen while the
/// previous one goes down. The plan keeps its size behind it (no jump), ShapeCanvas centers it above.
/// Each child needs its own key (ValueKey('buttons'), ValueKey('selected')...).
class PlanBottomSlot extends StatelessWidget {
  const PlanBottomSlot({super.key, required this.child});

  static const duration = Duration(milliseconds: 220);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
        child: child,
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previous, if (current != null) current],
      ),
      child: child,
    );
  }
}
