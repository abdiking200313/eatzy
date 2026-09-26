import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import '../../../../widgets/app_cards.dart';
import '../../../profile/presentation/profile_edit_controller.dart';

final _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(TwRadius.xl),
);

/// Describes a single text field rendered inside an [EditFieldSheet].
class EditFieldSpec {
  const EditFieldSpec({
    this.initialValue = '',
    required this.label,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.errorMessages = const [],
  });

  final String initialValue;
  final String label;
  final String? hintText;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;

  /// The subset of [ProfileEditController.fieldErrors] messages that belong
  /// to this field. The first one present in the controller's current
  /// errors is shown as this field's inline `errorText`.
  final List<String> errorMessages;
}

/// A reusable modal-bottom-sheet form for editing one or more profile
/// fields via a [ProfileEditController], so the Settings "Name" / "Phone
/// Number" / "Email Address" rows don't each need their own copy of the
/// save/loading/error boilerplate (issue: profile editing moves into
/// Settings).
///
/// Callers await the `showModalBottomSheet<ProfileEditResult>` call this is
/// built with: on a successful save this sheet pops itself with the
/// [ProfileEditResult], letting the caller update its own state and show a
/// confirmation `SnackBar`. On failure it stays open and re-renders with
/// the controller's field/general errors.
///
/// The sheet owns its text controllers: the modal's future completes before
/// its close animation finishes, so a caller disposing them after `await`
/// would crash the still-mounted fields.
class EditFieldSheet extends StatefulWidget {
  const EditFieldSheet({
    super.key,
    required this.title,
    required this.fields,
    required this.controller,
    required this.onSave,
    this.helperText,
    this.saveLabel = 'Save',
  });

  final String title;
  final List<EditFieldSpec> fields;
  final ProfileEditController controller;

  /// Receives the current text of each field, in [fields] order.
  final Future<ProfileEditResult> Function(List<String> values) onSave;
  final String? helperText;
  final String saveLabel;

  @override
  State<EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<EditFieldSheet> {
  late final List<TextEditingController> _textControllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initialValue),
  ];

  @override
  void dispose() {
    for (final textController in _textControllers) {
      textController.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    final result = await widget.onSave([
      for (final textController in _textControllers) textController.text,
    ]);
    if (result.isSuccess && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final fields = widget.fields;
    final helperText = widget.helperText;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        TwSpacing.x5,
        TwSpacing.x2,
        TwSpacing.x5,
        TwSpacing.x6 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final errors = controller.fieldErrors;
          final matchedErrors = <String>{};
          final fieldWidgets = <Widget>[];
          for (var i = 0; i < fields.length; i++) {
            final field = fields[i];
            String? errorText;
            for (final message in field.errorMessages) {
              if (errors.contains(message)) {
                errorText = message;
                matchedErrors.add(message);
                break;
              }
            }
            if (fieldWidgets.isNotEmpty) {
              fieldWidgets.add(const SizedBox(height: TwSpacing.x3));
            }
            fieldWidgets.add(
              TextField(
                controller: _textControllers[i],
                keyboardType: field.keyboardType,
                textCapitalization: field.textCapitalization,
                enabled: !controller.isSubmitting,
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.hintText,
                  prefixIcon: field.prefixIcon != null
                      ? Icon(field.prefixIcon)
                      : null,
                  border: _fieldBorder,
                  errorText: errorText,
                ),
              ),
            );
          }

          final unmatchedFieldError = errors.firstWhere(
            (message) => !matchedErrors.contains(message),
            orElse: () => '',
          );
          final generalError = controller.submissionError?.isNotEmpty == true
              ? controller.submissionError
              : (unmatchedFieldError.isEmpty ? null : unmatchedFieldError);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: TwText.textXl),
              const SizedBox(height: TwSpacing.x3_5),
              if (helperText != null) ...[
                Text(
                  helperText,
                  style: TwText.textSm.copyWith(color: TwColors.textMuted),
                ),
                const SizedBox(height: TwSpacing.x4),
              ],
              ...fieldWidgets,
              if (generalError != null) ...[
                const SizedBox(height: TwSpacing.x3),
                Text(
                  generalError,
                  style: TwText.textSm.copyWith(color: TwColors.error),
                ),
              ],
              const SizedBox(height: TwSpacing.x5),
              GradientActionButton(
                label: controller.isSubmitting ? 'Saving...' : widget.saveLabel,
                onPressed: controller.isSubmitting ? null : _handleSave,
              ),
            ],
          );
        },
      ),
    );
  }
}
