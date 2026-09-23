import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../utils/plan_geometry.dart';
import 'core_providers.dart';

/// Magnet of the plans : the points drawn or dragged go to the nearest multiple of [stepCm].
class SnapSettings {
  const SnapSettings({required this.enabled, required this.stepCm});

  final bool enabled;
  final int stepCm;

  /// Step really applied : without magnet, points are only rounded to the cm (like the server).
  int get effectiveCm => enabled ? stepCm : 1;
}

/// ref.watch(snapProvider), remembered between launches (same for all the plans).
final snapProvider = NotifierProvider<SnapNotifier, SnapSettings>(SnapNotifier.new);

class SnapNotifier extends Notifier<SnapSettings> {
  @override
  SnapSettings build() {
    // stored value : the step in cm, negative when the magnet is off (the step is kept for when it comes back)
    final stored = ref.read(sharedPreferencesProvider).getInt(AppConstants.snapKey);
    final stepCm = stored == null || !PlanGeometry.snapSteps.contains(stored.abs())
        ? PlanGeometry.defaultSnapCm
        : stored.abs();
    return SnapSettings(enabled: stored == null || stored > 0, stepCm: stepCm);
  }

  void setStep(int stepCm) => _save(SnapSettings(enabled: true, stepCm: stepCm));

  void setEnabled(bool enabled) => _save(SnapSettings(enabled: enabled, stepCm: state.stepCm));

  void _save(SnapSettings settings) {
    state = settings;
    ref
        .read(sharedPreferencesProvider)
        .setInt(AppConstants.snapKey, settings.enabled ? settings.stepCm : -settings.stepCm);
  }
}
