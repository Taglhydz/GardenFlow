import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/garden.dart';
import '../providers/garden_providers.dart';
import '../utils/validators.dart';

/// Creates a garden and selects it, or edits the name, location and description of [garden].
/// Returns true when the garden was saved.
///   final created = await GardenFormDialog.show(context);
///   final saved   = await GardenFormDialog.show(context, garden: garden);
class GardenFormDialog extends ConsumerStatefulWidget {
  const GardenFormDialog({super.key, this.garden});

  /// null = new garden
  final Garden? garden;

  static Future<bool> show(BuildContext context, {Garden? garden}) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => GardenFormDialog(garden: garden));
    return saved ?? false;
  }

  @override
  ConsumerState<GardenFormDialog> createState() => _GardenFormDialogState();
}

class _GardenFormDialogState extends ConsumerState<GardenFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController        = TextEditingController(text: widget.garden?.name);
  late final _locationController    = TextEditingController(text: widget.garden?.location);
  late final _descriptionController = TextEditingController(text: widget.garden?.description);
  bool _isLoading = false;

  bool get _isEdit => widget.garden != null;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(gardensProvider.notifier);
      final garden = widget.garden;
      if (garden == null) {
        await notifier.create(
          name: _nameController.text.trim(),
          location: _optional(_locationController),
          description: _optional(_descriptionController),
        );
      } else {
        // only what changed is sent, '' clears an optional field
        final name = _nameController.text.trim();
        final location = _locationController.text.trim();
        final description = _descriptionController.text.trim();
        if (name != garden.name || location != (garden.location ?? '') || description != (garden.description ?? '')) {
          await notifier.updateGarden(
            garden.id,
            name: name != garden.name ? name : null,
            location: location != (garden.location ?? '') ? location : null,
            description: description != (garden.description ?? '') ? description : null,
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.errorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'edit_garden'.tr() : 'home.create_garden'.tr()),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'home.garden_name_required'.tr(),
                  hintText: 'home.garden_name_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                maxLength: 100,
                autofocus: !_isEdit,
                validator: Validators.requiredName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'location'.tr(),
                  hintText: 'home.location_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                maxLength: 255,
                // the server also puts a capital on each word
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'description'.tr(),
                  hintText: 'home.description_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                maxLength: 2000,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                )
              : Text(_isEdit ? 'save'.tr() : 'create'.tr()),
        ),
      ],
    );
  }
}
