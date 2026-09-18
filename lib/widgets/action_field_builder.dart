import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/action_registry.dart';
import '../utils/date_formatter.dart';

// ──────────────────────────────────────────────
//  ACTION FIELD BUILDER
//  Dynamically generates form fields from ActionFieldSchema.
// ──────────────────────────────────────────────

class ActionFieldBuilder extends StatelessWidget {
  final ActionFieldSchema schema;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool hasError;

  const ActionFieldBuilder({
    super.key,
    required this.schema,
    required this.value,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    const errorColor = Colors.redAccent;

    final fieldBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    final borderColor =
        hasError ? errorColor : (isDark ? Colors.white12 : Colors.black12);

    switch (schema.type) {
      case FieldType.text:
        return _buildTextField(
            context, textColor, secondaryColor, fieldBg, borderColor,
            maxLines: 1);

      case FieldType.longText:
        return _buildTextField(
            context, textColor, secondaryColor, fieldBg, borderColor,
            maxLines: 5);

      case FieldType.number:
        return _buildTextField(
            context, textColor, secondaryColor, fieldBg, borderColor,
            maxLines: 1,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true));

      case FieldType.dropdown:
        return _buildDropdown(
            context, textColor, secondaryColor, fieldBg, borderColor);

      case FieldType.date:
        return _buildDateField(
            context, textColor, secondaryColor, fieldBg, borderColor);

      case FieldType.boolean:
        return _buildBooleanField(context, textColor, secondaryColor);
    }
  }

  Widget _buildTextField(
    BuildContext context,
    Color textColor,
    Color secondaryColor,
    Color fieldBg,
    Color borderColor, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(textColor, secondaryColor),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: TextEditingController(text: value?.toString() ?? '')
              ..selection = TextSelection.collapsed(
                  offset: (value?.toString() ?? '').length),
            style: TextStyle(color: textColor, fontSize: 14),
            maxLines: maxLines,
            minLines: 1,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: schema.label,
              hintStyle: TextStyle(color: secondaryColor.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
            onChanged: (val) {
              if (schema.type == FieldType.number) {
                onChanged(num.tryParse(val) ?? val);
              } else {
                onChanged(val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    BuildContext context,
    Color textColor,
    Color secondaryColor,
    Color fieldBg,
    Color borderColor,
  ) {
    final options = schema.options ?? [];
    String currentStr = value?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(textColor, secondaryColor),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options
                      .any((o) => o.startsWith(currentStr) || o == currentStr)
                  ? options.firstWhere(
                      (o) => o.startsWith(currentStr) || o == currentStr,
                      orElse: () => options.first)
                  : null,
              hint: Text(schema.label,
                  style: TextStyle(color: secondaryColor.withOpacity(0.5))),
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(color: textColor, fontSize: 14),
              items: options.map((opt) {
                return DropdownMenuItem<String>(value: opt, child: Text(opt));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  // Extract the leading number if present (e.g. "1 - Low" → 1)
                  final numMatch = RegExp(r'^(\d+)').firstMatch(val);
                  if (numMatch != null && schema.type == FieldType.dropdown) {
                    onChanged(int.tryParse(numMatch.group(1)!) ?? val);
                  } else {
                    onChanged(val);
                  }
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
    BuildContext context,
    Color textColor,
    Color secondaryColor,
    Color fieldBg,
    Color borderColor,
  ) {
    DateTime? dateValue;
    if (value != null) {
      dateValue =
          value is DateTime ? value : DateHelper.parseFlexibleDate(value);
    }

    final displayStr = dateValue != null
        ? '${dateValue.year}-${dateValue.month.toString().padLeft(2, '0')}-${dateValue.day.toString().padLeft(2, '0')} (${DateHelper.formatFriendlyDate(dateValue)})'
        : 'Tap to select date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(textColor, secondaryColor),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dateValue ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (ctx, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onChanged(picked.toIso8601String());
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.calendar, size: 16, color: secondaryColor),
                const SizedBox(width: 10),
                Text(displayStr,
                    style: TextStyle(color: textColor, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBooleanField(
    BuildContext context,
    Color textColor,
    Color secondaryColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLabel(textColor, secondaryColor),
        CupertinoSwitch(
          value: value == true,
          onChanged: (val) => onChanged(val),
          activeTrackColor: Theme.of(context).primaryColor,
        ),
      ],
    );
  }

  Widget _buildLabel(Color textColor, Color secondaryColor) {
    return Row(
      children: [
        Text(
          schema.label,
          style: TextStyle(
              color: secondaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
        ),
        if (schema.required) ...[
          const SizedBox(width: 4),
          const Text('*',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}
