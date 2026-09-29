import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/parcel.dart';
import '../providers/garden_providers.dart';
import '../utils/validators.dart';

/// Edits the name and the growing conditions of a parcel (its shape is drawn on the plan), or deletes it
/// after a confirmation. Returns the saved parcel, or null if cancelled or deleted.
class ParcelFormSheet extends ConsumerStatefulWidget {
  const ParcelFormSheet({super.key, required this.gardenId, required this.parcel, this.onDeleted});

  final int gardenId;
  final Parcel parcel;

  /// Called once the parcel is deleted and the sheet closed (e.g. the parcel screen goes back to the garden)
  final VoidCallback? onDeleted;

  static Future<Parcel?> show(
    BuildContext context, {
    required int gardenId,
    required Parcel parcel,
    VoidCallback? onDeleted,
  }) {
    return showModalBottomSheet<Parcel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ParcelFormSheet(gardenId: gardenId, parcel: parcel, onDeleted: onDeleted),
    );
  }

  @override
  ConsumerState<ParcelFormSheet> createState() => _ParcelFormSheetState();
}

class _ParcelFormSheetState extends ConsumerState<ParcelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _soilType;
  late String _sunlight;
  late String _moisture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.parcel.name);
    _soilType = widget.parcel.soilType;
    _sunlight = widget.parcel.sunlight;
    _moisture = widget.parcel.moisture;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.errorMessage(error)), backgroundColor: AppColors.error),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final saved = await ref.read(parcelsProvider(widget.gardenId).notifier).updateParcel(widget.parcel.id, {
        'name': _nameController.text.trim(),
        'soil_type': _soilType,
        'sunlight': _sunlight,
        'moisture': _moisture,
      });
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  /// After a confirmation : the parcel, its zones and its crops are deleted, the sheet closes.
  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_parcel'.tr()),
        content: Text('parcel_screen.delete_confirm'.tr(args: [widget.parcel.name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(parcelsProvider(widget.gardenId).notifier).delete(widget.parcel.id);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDeleted?.call();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Widget _dropdown(String label, String value, List<Map<String, String>> items, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [for (final item in items) DropdownMenuItem(value: item['value'], child: Text(item['label']!))],
      onChanged: (v) => v != null ? onChanged(v) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // keeps the fields above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('parcel_form.title_edit'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                maxLength: 100,
                decoration: InputDecoration(labelText: 'parcel_name'.tr(), border: const OutlineInputBorder()),
                validator: Validators.requiredName,
              ),
              const SizedBox(height: 8),
              _dropdown('soil_type'.tr(), _soilType, AppLocalizations.soilTypes, (v) => setState(() => _soilType = v)),
              const SizedBox(height: 16),
              _dropdown('sunlight'.tr(), _sunlight, AppLocalizations.sunlightLevels, (v) => setState(() => _sunlight = v)),
              const SizedBox(height: 16),
              _dropdown('moisture'.tr(), _moisture, AppLocalizations.moistureLevels, (v) => setState(() => _moisture = v)),
              const SizedBox(height: 24),
              Row(
                children: [
                  // on the left, away from the save button
                  TextButton.icon(
                    onPressed: _isLoading ? null : _delete,
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline),
                    label: Text('delete'.tr()),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text('cancel'.tr()),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.white),
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                        : Text('save'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
