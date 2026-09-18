import 'package:flutter/material.dart';

class ConfirmationCard extends StatelessWidget {
  final String action;
  final String details;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmationCard({
    super.key,
    required this.action,
    required this.details,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = isDark ? Colors.white54 : Colors.black54;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100;
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Text(
                "AI REQUEST: $action",
                style: const TextStyle(
                  color: Colors.amber, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 12
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            details,
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? Colors.white38 : Colors.black38),
                  ),
                  child: Text("Cancel", style: TextStyle(color: secondaryTextColor)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white
                  ),
                  onPressed: onConfirm,
                  child: const Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}