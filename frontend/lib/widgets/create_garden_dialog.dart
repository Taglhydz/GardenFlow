import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../providers/garden_providers.dart';
import '../utils/validators.dart';

/// Creates a garden and selects it. Returns true when a garden was created.
///   final created = await CreateGardenDialog.show(context);
class CreateGardenDialog extends ConsumerStatefulWidget {
  const CreateGardenDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final created = await showDialog<bool>(context: context, builder: (_) => const CreateGardenDialog());
    return created ?? false;
  }

  @override
  ConsumerState<CreateGardenDialog> createState() => _CreateGardenDialogState();
}

class _CreateGardenDialogState extends ConsumerState<CreateGardenDialog> {
  final _formKey               = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _locationController    = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

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

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(gardensProvider.notifier).create(
        name: _nameController.text.trim(),
        location: _optional(_locationController),
        description: _optional(_descriptionController),
      );
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
      title: Text('home.create_garden'.tr()),
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
                autofocus: true,
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
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'description'.tr(),
                  hintText: 'home.description_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
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
          onPressed: _isLoading ? null : _create,
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
              : Text('create'.tr()),
        ),
      ],
    );
  }
}
