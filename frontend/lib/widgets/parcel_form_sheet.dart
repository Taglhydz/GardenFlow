import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/parcel.dart';
import '../providers/garden_providers.dart';
import '../utils/plan_geometry.dart';
import '../utils/validators.dart';

/// Creates or edits a parcel. Returns the saved parcel, or null if cancelled.
///   final parcel = await ParcelFormSheet.show(context, gardenId: 1);
class ParcelFormSheet extends ConsumerStatefulWidget {
  const ParcelFormSheet({super.key, required this.gardenId, this.parcel});

  final int gardenId;

  /// null = creation
  final Parcel? parcel;

  static Future<Parcel?> show(BuildContext context, {required int gardenId, Parcel? parcel}) {
    return showModalBottomSheet<Parcel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ParcelFormSheet(gardenId: gardenId, parcel: parcel),
    );
  }

  @override
  ConsumerState<ParcelFormSheet> createState() => _ParcelFormSheetState();
}

class _ParcelFormSheetState extends ConsumerState<ParcelFormSheet> {
  static const _maxSize = 1000.0;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _widthController;
  late final TextEditingController _lengthController;
  late String _soilType;
  late String _sunlight;
  late String _moisture;
  bool _isLoading = false;

  bool get _isEdit => widget.parcel != null;

  @override
  void initState() {
    super.initState();
    final parcel = widget.parcel;
    final format = NumberFormat('0.##');
    _nameController   = TextEditingController(text: parcel?.name ?? '');
    _widthController  = TextEditingController(text: format.format(parcel?.width ?? 1));
    _lengthController = TextEditingController(text: format.format(parcel?.length ?? 1));
    _soilType = parcel?.soilType ?? 'standard';
    _sunlight = parcel?.sunlight ?? 'medium';
    _moisture = parcel?.moisture ?? 'medium';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  /// Accepts "1,5" as well as "1.5"
  double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validateSize(String? value) {
    final size = _parse(value ?? '');
    if (size == null || size < PlanGeometry.minParcelSize || size > _maxSize) {
      return 'parcel_form.invalid_size'.tr(args: [
        NumberFormat('0.##').format(PlanGeometry.minParcelSize),
        NumberFormat('0').format(_maxSize),
      ]);
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final fields = <String, dynamic>{
      'name': _nameController.text.trim(),
      'width': PlanGeometry.snapSize(_parse(_widthController.text)!),
      'length': PlanGeometry.snapSize(_parse(_lengthController.text)!),
      'soil_type': _soilType,
      'sunlight': _sunlight,
      'moisture': _moisture,
    };

    try {
      final notifier = ref.read(parcelsProvider(widget.gardenId).notifier);
      final Parcel saved;
      if (_isEdit) {
        saved = await notifier.updateParcel(widget.parcel!.id, fields);
      } else {
        // placed next to the existing parcels, the user moves it on the plan afterwards
        final existing = ref.read(parcelsProvider(widget.gardenId)).value ?? const [];
        final position = PlanGeometry.newParcelPosition(existing);
        saved = await notifier.create({...fields, 'pos_x': position.dx, 'pos_y': position.dy});
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.errorMessage(e)), backgroundColor: AppColors.error),
        );
      }
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
              Text(
                _isEdit ? 'parcel_form.title_edit'.tr() : 'parcel_form.title_create'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEdit,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'parcel_name'.tr(),
                  hintText: 'parcel_form.name_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: Validators.requiredName,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _widthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'parcel_form.width_m'.tr(), border: const OutlineInputBorder()),
                      validator: _validateSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'parcel_form.length_m'.tr(), border: const OutlineInputBorder()),
                      validator: _validateSize,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _dropdown('soil_type'.tr(), _soilType, AppLocalizations.soilTypes, (v) => setState(() => _soilType = v)),
              const SizedBox(height: 16),
              _dropdown('sunlight'.tr(), _sunlight, AppLocalizations.sunlightLevels, (v) => setState(() => _sunlight = v)),
              const SizedBox(height: 16),
              _dropdown('moisture'.tr(), _moisture, AppLocalizations.moistureLevels, (v) => setState(() => _moisture = v)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                        : Text(_isEdit ? 'save'.tr() : 'create'.tr()),
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
