import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/widgets/date_input_field.dart';

/// Applies the formatter as the text field does : the new text with the cursor at [cursor] (end by default).
TextEditingValue edit(String oldText, String newText, {int? cursor}) => DateMaskFormatter().formatEditUpdate(
      TextEditingValue(text: oldText, selection: TextSelection.collapsed(offset: oldText.length)),
      TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: cursor ?? newText.length)),
    );

/// Types [digits] one by one in an empty field.
String type(String digits) {
  var text = '';
  for (final digit in digits.split('')) {
    text = edit(text, text + digit).text;
  }
  return text;
}

void main() {
  group('DateMaskFormatter', () {
    test('the slashes appear by themselves', () {
      expect(type('1'), '1');
      expect(type('12'), '12/');
      expect(type('1205'), '12/05/');
      expect(type('12051990'), '12/05/1990');
    });

    test('no more than 8 digits', () {
      expect(type('120519901'), '12/05/1990');
    });

    test('backspace on a slash erases the digit before it', () {
      expect(edit('12/', '12').text, '1');
      expect(edit('12/05/', '12/05').text, '12/0');
    });

    test('backspace on a digit', () {
      expect(edit('12/05/1990', '12/05/199').text, '12/05/199');
      expect(edit('12/0', '12/').text, '12/');
    });

    test('letters and typed slashes are ignored, a pasted date is kept', () {
      expect(edit('', 'a').text, '');
      expect(edit('12/', '12//').text, '12/');
      expect(edit('', '12/05/1990').text, '12/05/1990');
    });

    test('the cursor stays after the same digit when editing in the middle', () {
      // '12/05/1990' -> 3 typed before '05'
      final value = edit('12/05/1990', '12/305/1990', cursor: 4);
      expect(value.text, '12/30/5199');
      expect(value.selection.baseOffset, 4);
    });
  });

  group('DateInputField.parse', () {
    test('complete and possible dates only', () {
      expect(DateInputField.parse('12/05/1990'), DateTime(1990, 5, 12));
      expect(DateInputField.parse('29/02/2024'), DateTime(2024, 2, 29));
      expect(DateInputField.parse('31/02/2000'), isNull);
      expect(DateInputField.parse('00/05/1990'), isNull);
      expect(DateInputField.parse('12/13/1990'), isNull);
      expect(DateInputField.parse('12/05/'), isNull);
    });
  });
}
