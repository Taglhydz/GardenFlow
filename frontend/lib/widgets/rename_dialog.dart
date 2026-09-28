import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Dialog to rename something : the new name (trimmed), or null when it is cancelled or closed.
///
/// The text controller belongs to the dialog and is disposed with it, after its closing
/// animation (disposing it as soon as showDialog returns crashes while the dialog fades out).
Future<String?> showRenameDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String name,
  String? helper,
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(title: title, label: label, name: name, helper: helper),
    );

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.title, required this.label, required this.name, this.helper});

  final String title;
  final String label;
  final String name;

  /// Small text under the field
  final String? helper;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: Text('save'.tr())),
      ],
    );
  }
}
