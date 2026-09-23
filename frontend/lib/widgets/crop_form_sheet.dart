import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/json_utils.dart';
import '../models/plant.dart';
import '../providers/garden_providers.dart';
import '../providers/plant_providers.dart';
import 'plant_picker_sheet.dart';

/// Adds a crop to a parcel, or edits it. Returns true when saved.
///   await CropFormSheet.show(context, gardenId: 1, parcelId: 2, plant: tomato);
class CropFormSheet extends ConsumerStatefulWidget {
  const CropFormSheet({
    super.key,
    required this.gardenId,
    required this.parcelId,
    this.zoneId,
    this.crop,
    this.plant,
    this.sowDate,
  });

  final int gardenId;
  final int parcelId;

  /// Zone where the crop is planted (null = the whole parcel)
  final int? zoneId;

  /// null = creation
  final Crop? crop;

  /// Pre-selected plant (e.g. from a suggestion)
  final Plant? plant;

  /// Pre-filled sowing date (today by default)
  final DateTime? sowDate;

  static Future<bool> show(
    BuildContext context, {
    required int gardenId,
    required int parcelId,
    int? zoneId,
    Crop? crop,
    Plant? plant,
    DateTime? sowDate,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CropFormSheet(gardenId: gardenId, parcelId: parcelId, zoneId: zoneId, crop: crop, plant: plant, sowDate: sowDate),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<CropFormSheet> createState() => _CropFormSheetState();
}

class _CropFormSheetState extends ConsumerState<CropFormSheet> {
  late final TextEditingController _commentController;
  Plant? _plant;
  DateTime? _sowDate;
  DateTime? _expectedHarvestDate;

  /// The expected harvest follows the plant and the sowing date until the user picks one.
  bool _harvestDateEditedByUser = false;
  bool _isLoading = false;
  String? _error;

  bool get _isEdit => widget.crop != null;

  @override
  void initState() {
    super.initState();
    final crop = widget.crop;
    _commentController = TextEditingController(text: crop?.comment ?? '');
    _plant = widget.plant;
    _sowDate = crop?.sowDate ?? widget.sowDate ?? (crop == null ? DateUtils.dateOnly(DateTime.now()) : null);
    _expectedHarvestDate = crop?.expectedHarvestDate;
    _harvestDateEditedByUser = crop?.expectedHarvestDate != null;

    if (crop != null) {
      // the plant list is already loaded by the parcel screen
      _plant = ref.read(plantsByIdProvider)[crop.plantId];
    }
    _updateExpectedHarvest();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _updateExpectedHarvest() {
    if (_harvestDateEditedByUser || _plant == null || _sowDate == null) return;
    _expectedHarvestDate = _plant!.expectedHarvestFrom(_sowDate!);
  }

  Future<void> _pickPlant() async {
    final plant = await PlantPickerSheet.show(context);
    if (plant != null) {
      setState(() {
        _plant = plant;
        _updateExpectedHarvest();
      });
    }
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 3),
    );
  }

  Future<void> _save() async {
    if (_plant == null) {
      setState(() => _error = 'crop_form.plant_required'.tr());
      return;
    }
    if (_sowDate != null && _expectedHarvestDate != null && _expectedHarvestDate!.isBefore(_sowDate!)) {
      setState(() => _error = 'crop_form.harvest_before_sow'.tr());
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final comment = _commentController.text.trim();
    final notifier = ref.read(gardenCropsProvider(widget.gardenId).notifier);

    try {
      if (_isEdit) {
        await notifier.updateCrop(widget.crop!.id, {
          'plant_id': _plant!.id,
          'sow_date': JsonUtils.formatDate(_sowDate),
          'expected_harvest_date': JsonUtils.formatDate(_expectedHarvestDate),
          'comment': comment.isEmpty ? null : comment,
        });
      } else {
        await notifier.create(
          widget.parcelId,
          zoneId: widget.zoneId,
          plantId: _plant!.id,
          sowDate: _sowDate,
          expectedHarvestDate: _expectedHarvestDate,
          comment: comment.isEmpty ? null : comment,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.errorMessage(e);
        });
      }
    }
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value == null ? 'auth.select_date'.tr() : MaterialLocalizations.of(context).formatMediumDate(value),
          style: TextStyle(color: value == null ? AppColors.grey : AppColors.black),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plant = _plant;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'crop_form.title_edit'.tr() : 'crop_form.title_create'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // plant
            InkWell(
              onTap: _pickPlant,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'plant'.tr(),
                  prefixIcon: const Icon(Icons.eco),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  plant == null ? 'crop_form.choose_plant'.tr() : AppLocalizations.plantName(plant),
                  style: TextStyle(color: plant == null ? AppColors.grey : AppColors.black),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // sowing / planting date
            _dateField('sow_date'.tr(), _sowDate, () async {
              final date = await _pickDate(_sowDate);
              if (date != null) {
                setState(() {
                  _sowDate = date;
                  _updateExpectedHarvest();
                });
              }
            }),
            const SizedBox(height: 16),

            // expected harvest, computed from the plant until the user changes it
            _dateField('expected_harvest_date'.tr(), _expectedHarvestDate, () async {
              final date = await _pickDate(_expectedHarvestDate ?? _sowDate);
              if (date != null) {
                setState(() {
                  _expectedHarvestDate = date;
                  _harvestDateEditedByUser = true;
                });
              }
            }),
            if (!_harvestDateEditedByUser && plant?.daysToMaturity != null && _sowDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  'crop_form.expected_auto'.tr(args: ['${plant!.daysToMaturity}']),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 16),

            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'comment'.tr(), border: const OutlineInputBorder()),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context, false),
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
    );
  }
}
