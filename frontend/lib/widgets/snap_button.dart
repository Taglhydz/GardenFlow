import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../providers/snap_provider.dart';
import '../utils/plan_geometry.dart';

/// Small button on a plan : shows the magnet grid ("10 cm" / "Libre") and changes it.
class SnapButton extends ConsumerWidget {
  const SnapButton({super.key});

  /// 0 = magnet off in the menu
  static const _off = 0;

  static String stepLabel(int cm) =>
      cm >= 100 ? 'snap.step_m'.tr(args: ['${cm ~/ 100}']) : 'snap.step_cm'.tr(args: ['$cm']);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(snapProvider);

    return Material(
      color: AppColors.white,
      elevation: 2,
      shape: const StadiumBorder(),
      child: PopupMenuButton<int>(
        tooltip: 'snap.title'.tr(),
        onSelected: (value) {
          final notifier = ref.read(snapProvider.notifier);
          value == _off ? notifier.setEnabled(false) : notifier.setStep(value);
        },
        itemBuilder: (context) => [
          PopupMenuItem<int>(
            enabled: false,
            child: Text('snap.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final cm in PlanGeometry.snapSteps)
            CheckedPopupMenuItem<int>(
              value: cm,
              checked: snap.enabled && snap.stepCm == cm,
              child: Text(stepLabel(cm)),
            ),
          CheckedPopupMenuItem<int>(value: _off, checked: !snap.enabled, child: Text('snap.off'.tr())),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(snap.enabled ? Icons.grid_on : Icons.grid_off, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(
                snap.enabled ? stepLabel(snap.stepCm) : 'snap.free'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
