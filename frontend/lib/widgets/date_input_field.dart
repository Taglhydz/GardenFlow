import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Date typed as dd/mm/yyyy with the number keyboard : only the digits are typed, the slashes are fixed.
/// The calendar button opens the date picker in calendar mode (its own text mode has no slash key).
class DateInputField extends StatefulWidget {
  const DateInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.icon = Icons.calendar_today,
    this.initialPickerDate,
    this.pickerHelpText,
    this.textInputAction,
  });

  final String label;
  final DateTime? value;

  /// null while the date is empty or incomplete
  final ValueChanged<DateTime?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final IconData icon;

  /// Date shown by the calendar when the field is empty (default : lastDate)
  final DateTime? initialPickerDate;
  final String? pickerHelpText;
  final TextInputAction? textInputAction;

  static String format(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year.toString().padLeft(4, '0')}';

  /// 'dd/mm/yyyy' -> date, null if incomplete or impossible (31/02/2000)
  static DateTime? parse(String text) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
    if (match == null) return null;
    final day   = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year  = int.parse(match[3]!);
    final date  = DateTime(year, month, day);
    return date.day == day && date.month == month && date.year == year ? date : null;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  State<DateInputField> createState() => _DateInputFieldState();
}

class _DateInputFieldState extends State<DateInputField> {
  late final _controller = TextEditingController(text: widget.value == null ? '' : DateInputField.format(widget.value!));

  @override
  void didUpdateWidget(DateInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // date changed by the parent : show it (not while the user is typing an incomplete date)
    final value = widget.value;
    if (value != null && !DateUtils.isSameDay(value, DateInputField.parse(_controller.text))) {
      _controller.text = DateInputField.format(value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime? _dateInRange(String text) {
    final date = DateInputField.parse(text);
    if (date == null || date.isBefore(DateUtils.dateOnly(widget.firstDate)) || date.isAfter(widget.lastDate)) return null;
    return date;
  }

  Future<void> _openCalendar() async {
    var initial = _dateInRange(_controller.text) ?? widget.initialPickerDate ?? widget.lastDate;
    if (initial.isBefore(widget.firstDate)) initial = widget.firstDate;
    if (initial.isAfter(widget.lastDate)) initial = widget.lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: widget.pickerHelpText,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    _controller.text = DateInputField.format(picked);
    widget.onChanged(picked);
  }

  String? _validate(String? text) {
    if (text == null || text.isEmpty) return null;
    final date = DateInputField.parse(text);
    if (date == null) return 'validation.date_invalid'.tr();
    if (_dateInRange(text) == null) {
      return 'validation.date_out_of_range'.tr(args: [DateInputField.format(widget.firstDate), DateInputField.format(widget.lastDate)]);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textInputAction: widget.textInputAction,
      inputFormatters: [DateMaskFormatter()],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'date_format_hint'.tr(),
        prefixIcon: Icon(widget.icon),
        suffixIcon: IconButton(
          icon: const Icon(Icons.event),
          tooltip: 'auth.select_date'.tr(),
          onPressed: _openCalendar,
        ),
        border: const OutlineInputBorder(),
      ),
      validator: _validate,
      onChanged: (text) => widget.onChanged(_dateInRange(text)),
    );
  }
}

/// Keeps only 8 digits and places the slashes : '12051990' -> '12/05/1990'.
/// A slash appears as soon as the day (or the month) is complete, and erasing it erases the digit before.
class DateMaskFormatter extends TextInputFormatter {
  static final _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(_nonDigit, '');
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    var digitsBeforeCursor = newValue.text.substring(0, cursor).replaceAll(_nonDigit, '').length;

    // backspace on a slash : the digits didn't change, remove the one before the slash
    final erasedSlash = newValue.text.length < oldValue.text.length && digits == oldValue.text.replaceAll(_nonDigit, '');
    if (erasedSlash && digitsBeforeCursor > 0) {
      digits = digits.substring(0, digitsBeforeCursor - 1) + digits.substring(digitsBeforeCursor);
      digitsBeforeCursor--;
    }

    if (digits.length > 8) digits = digits.substring(0, 8);
    digitsBeforeCursor = min(digitsBeforeCursor, digits.length);

    final text = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      text.write(digits[i]);
      if (i == 1 || i == 3) text.write('/');
    }

    // cursor after the same digits, after the slash that follows them if any
    final offset = digitsBeforeCursor + (digitsBeforeCursor >= 2 ? 1 : 0) + (digitsBeforeCursor >= 4 ? 1 : 0);

    return TextEditingValue(
      text: text.toString(),
      selection: TextSelection.collapsed(offset: min(offset, text.length)),
    );
  }
}
