import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Buttons shown while a shape is being drawn : undo the last point, cancel, finish.
class DrawingBar extends StatelessWidget {
  const DrawingBar({
    super.key,
    required this.pointCount,
    required this.onUndo,
    required this.onCancel,
    required this.onFinish,
    this.isSaving = false,
  });

  final int pointCount;
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback onFinish;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              TextButton(onPressed: isSaving ? null : onCancel, child: Text('cancel'.tr())),
              const Spacer(),
              TextButton.icon(
                onPressed: pointCount > 0 && !isSaving ? onUndo : null,
                icon: const Icon(Icons.undo),
                label: Text('drawing.undo'.tr()),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: pointCount >= 3 && !isSaving ? onFinish : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white),
                icon: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                    : const Icon(Icons.check),
                label: Text('drawing.finish'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
