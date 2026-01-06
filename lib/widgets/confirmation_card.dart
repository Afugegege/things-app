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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
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
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: onConfirm,
                  child: const Text("Confirm", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}