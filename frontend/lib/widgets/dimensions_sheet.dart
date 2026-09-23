import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../utils/geometry.dart';
import '../utils/plan_geometry.dart';

/// Result of the dimensions sheet : the new shape and how far it was moved with the position fields.
/// The two are separate because a parcel keeps its origin when its sides change (its zones are relative to it).
class DimensionsResult {
  const DimensionsResult({required this.shape, required this.move});

  /// Points after the side changes, not moved
  final List<Offset> shape;

  /// Change of the position (top-left corner)
  final Offset move;

  /// Points where the shape ends up
  List<Offset> get finalShape => Geometry.translate(shape, move);
}

/// Dimensions of a shape in meters : the length of each side (A → B, B → C, …) and the position of its
/// top-left corner. Changing a side stretches the shape in the direction of that side
/// ([PlanGeometry.setSideLength]) : the other values are updated at once.
class DimensionsSheet extends StatefulWidget {
  const DimensionsSheet({
    super.key,
    required this.title,
    required this.shape,
    required this.positionLabel,
    this.validate,
  });

  final String title;
  final List<Offset> shape;

  /// What the position is relative to (the garden, the parcel)
  final String positionLabel;

  /// Error message shown in the sheet (the sheet stays open), null if the result can be saved
  final String? Function(DimensionsResult result)? validate;

  /// Null if cancelled.
  static Future<DimensionsResult?> show(
    BuildContext context, {
    required String title,
    required List<Offset> shape,
    required String positionLabel,
    String? Function(DimensionsResult result)? validate,
  }) {
    return showModalBottomSheet<DimensionsResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DimensionsSheet(title: title, shape: shape, positionLabel: positionLabel, validate: validate),
    );
  }

  @override
  State<DimensionsSheet> createState() => _DimensionsSheetState();
}

class _DimensionsSheetState extends State<DimensionsSheet> {
  late List<Offset> _shape = widget.shape;
  Offset _move = Offset.zero;

  late final List<TextEditingController> _sides = [
    for (var i = 0; i < widget.shape.length; i++) TextEditingController(),
  ];
  late final List<FocusNode> _sideFocus = [
    for (var i = 0; i < widget.shape.length; i++) FocusNode()..addListener(_onFocusChange),
  ];
  final _x = TextEditingController();
  final _y = TextEditingController();
  final _xFocus = FocusNode();
  final _yFocus = FocusNode();

  /// Field in error (index of the side, -1 = X, -2 = Y) and its message
  (int, String)? _fieldError;
  String? _error;

  /// Side highlighted on the preview (the one being edited)
  int? _focusedSide;

  Offset get _position => Geometry.bounds(_shape).topLeft + _move;

  @override
  void initState() {
    super.initState();
    _xFocus.addListener(_onFocusChange);
    _yFocus.addListener(_onFocusChange);
    _refreshFields();
  }

  @override
  void dispose() {
    for (final c in [..._sides, _x, _y]) {
      c.dispose();
    }
    for (final f in [..._sideFocus, _xFocus, _yFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  static String _format(double meters) => NumberFormat('0.00').format(meters);

  static double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  /// Text last written in each field : a field is applied only if the user changed it
  /// (changing a side can change the length of the others, their old value must not be applied back).
  final Map<TextEditingController, String> _written = {};

  void _write(TextEditingController controller, FocusNode focus, double meters) {
    if (focus.hasFocus) return; // don't replace what is being typed
    controller.text = _written[controller] = _format(meters);
  }

  /// Writes the current values in the fields (except the one being typed in and the one in error).
  void _refreshFields() {
    final errorField = _fieldError?.$1;
    for (var i = 0; i < _sides.length; i++) {
      if (errorField != i) _write(_sides[i], _sideFocus[i], PlanGeometry.sideLength(_shape, i));
    }
    if (errorField != -1) _write(_x, _xFocus, _position.dx);
    if (errorField != -2) _write(_y, _yFocus, _position.dy);
  }

  /// A field is applied when it loses the focus (or with the "next" key).
  void _onFocusChange() {
    if (!mounted) return;
    final focused = _sideFocus.indexWhere((f) => f.hasFocus);
    _focusedSide = focused >= 0 ? focused : null;
    _applyAll();
  }

  /// Applies the values typed by the user. False if one of them is not a valid length.
  bool _applyAll() {
    (int, String)? fieldError;
    bool changed(TextEditingController c) => c.text != _written[c];

    for (var i = 0; i < _sides.length; i++) {
      if (!changed(_sides[i])) continue;
      final value = _parse(_sides[i].text);
      if (value == null || value < 0.01) {
        fieldError ??= (i, value == null ? 'dimensions.invalid_number'.tr() : 'dimensions.too_short'.tr());
        continue;
      }
      _shape = PlanGeometry.setSideLength(_shape, i, value);
      _written[_sides[i]] = _sides[i].text;
    }

    for (final (field, controller, isX) in [(-1, _x, true), (-2, _y, false)]) {
      if (!changed(controller)) continue;
      final value = _parse(controller.text);
      if (value == null) {
        fieldError ??= (field, 'dimensions.invalid_number'.tr());
        continue;
      }
      final current = isX ? _position.dx : _position.dy;
      _move = PlanGeometry.roundCm(_move + (isX ? Offset(value - current, 0) : Offset(0, value - current)));
      _written[controller] = controller.text;
    }

    setState(() {
      _fieldError = fieldError;
      _error = null;
      _refreshFields();
    });
    return fieldError == null;
  }

  void _save() {
    if (!_applyAll()) return;
    final result = DimensionsResult(shape: _shape, move: _move);
    final error = !PlanGeometry.isValidShape(result.finalShape)
        ? 'garden_view.invalid_shape'.tr()
        : widget.validate?.call(result);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, result);
  }

  String? _errorOf(int field) => _fieldError?.$1 == field ? _fieldError!.$2 : null;

  @override
  Widget build(BuildContext context) {
    final count = _shape.length;

    return Padding(
      // the keyboard pushes the sheet up
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${AppLocalizations.area(Geometry.area(_shape))} · ${'dimensions.hint'.tr()}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: CustomPaint(painter: _PreviewPainter(_shape, highlighted: _focusedSide)),
              ),
              const SizedBox(height: 12),
              Text('dimensions.sides'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (var i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MeterField(
                    key: ValueKey('side_$i'),
                    label: '${PlanGeometry.cornerName(i)} → ${PlanGeometry.cornerName((i + 1) % count)}',
                    controller: _sides[i],
                    focusNode: _sideFocus[i],
                    error: _errorOf(i),
                  ),
                ),
              const SizedBox(height: 4),
              Text(widget.positionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MeterField(
                      key: const ValueKey('position_x'),
                      label: 'X',
                      controller: _x,
                      focusNode: _xFocus,
                      error: _errorOf(-1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MeterField(
                      key: const ValueKey('position_y'),
                      label: 'Y',
                      controller: _y,
                      focusNode: _yFocus,
                      error: _errorOf(-2),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ),
                    child: Text('save'.tr()),
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

class _MeterField extends StatelessWidget {
  const _MeterField({super.key, required this.label, required this.controller, required this.focusNode, this.error});

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'm',
        errorText: error,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// The shape fitted in the box, with the names of its corners and the edited side highlighted.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.points, {this.highlighted});

  final List<Offset> points;
  final int? highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 3) return;
    const padding = 16.0;
    final bounds = Geometry.bounds(points);
    final scale = [
      (size.width - 2 * padding) / (bounds.width == 0 ? 1 : bounds.width),
      (size.height - 2 * padding) / (bounds.height == 0 ? 1 : bounds.height),
    ].reduce((a, b) => a < b ? a : b);
    final origin = Offset((size.width - bounds.width * scale) / 2, (size.height - bounds.height * scale) / 2);
    Offset px(Offset p) => origin + (p - bounds.topLeft) * scale;

    final path = Path()..addPolygon([for (final p in points) px(p)], true);
    canvas.drawPath(path, Paint()..color = AppColors.primaryLight.withValues(alpha: 0.6));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primaryDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (highlighted != null && highlighted! < points.length) {
      canvas.drawLine(
        px(points[highlighted!]),
        px(points[(highlighted! + 1) % points.length]),
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < points.length; i++) {
      final center = px(points[i]);
      canvas.drawCircle(center, 8, Paint()..color = AppColors.primary);
      final name = TextPainter(
        text: TextSpan(
          text: PlanGeometry.cornerName(i),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      name.paint(canvas, center - Offset(name.width / 2, name.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.points != points || old.highlighted != highlighted;
}
