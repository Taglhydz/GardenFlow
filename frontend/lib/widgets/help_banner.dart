import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../providers/help_provider.dart';

/// Help of a screen, under the app bar : the cross closes it, [HelpButton] shows it again.
/// Its height changes smoothly (text on one more line, closed...) : the plan below follows it without jumping.
class HelpBanner extends ConsumerWidget {
  const HelpBanner({super.key, required this.screen, required this.text});

  /// Name of the screen, the banner is closed for this screen only
  final String screen;
  final String text;

  static const _resizeDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenHelpProvider).contains(screen);

    return AnimatedSize(
      duration: _resizeDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: hidden ? const SizedBox(width: double.infinity) : _buildBanner(ref),
    );
  }

  Widget _buildBanner(WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16),
      color: AppColors.primaryLight.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Icon(Icons.touch_app, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.primaryDark)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.primaryDark),
            tooltip: 'help.hide'.tr(),
            onPressed: () => ref.read(hiddenHelpProvider.notifier).setHidden(screen, true),
          ),
        ],
      ),
    );
  }
}

/// Small round "i" shown while the [HelpBanner] of the screen is closed : shows it again.
class HelpButton extends ConsumerWidget {
  const HelpButton({super.key, required this.screen});

  final String screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hiddenHelpProvider).contains(screen)) return const SizedBox.shrink();

    return Material(
      color: AppColors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.info_outline, color: AppColors.primaryDark),
        tooltip: 'help.show'.tr(),
        visualDensity: VisualDensity.compact,
        onPressed: () => ref.read(hiddenHelpProvider.notifier).setHidden(screen, false),
      ),
    );
  }
}
