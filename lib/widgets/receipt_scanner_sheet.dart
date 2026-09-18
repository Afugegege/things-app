import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../providers/money_provider.dart';
import '../providers/notes_provider.dart';
import '../models/note_model.dart';
import '../models/currency_model.dart';
import 'package:uuid/uuid.dart';

class ReceiptScannerSheet extends StatefulWidget {
  const ReceiptScannerSheet({super.key});

  @override
  State<ReceiptScannerSheet> createState() => _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends State<ReceiptScannerSheet> {
  bool _isScanning = false;
  Map<String, dynamic>? _scannedData;
  final TextEditingController _rawTextController = TextEditingController(
    text: "Target Store\n1x Wireless Mouse \$24.99\n2x Notebooks \$9.00\nSubtotal \$33.99\nTax \$2.72\nTotal \$36.71",
  );

  final AiService _aiService = AiService();

  Future<void> _scanReceipt() async {
    setState(() {
      _isScanning = true;
    });

    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);
    final parsed = await _aiService.parseReceiptText(
      _rawTextController.text,
      defaultCurrency: moneyProv.currentCurrency,
    );

    setState(() {
      _isScanning = false;
      _scannedData = parsed;
    });
  }

  void _saveToWallet() {
    if (_scannedData == null) return;
    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);
    final String merchant = _scannedData!['merchant'] ?? 'Receipt Purchase';
    final double amt = (_scannedData!['amount'] as num?)?.toDouble() ?? 0.0;
    final String cat = _scannedData!['category'] ?? 'Shopping';
    final String cur = _scannedData!['currency'] ?? moneyProv.currentCurrency;
    final String sym = AppCurrency.getSymbol(cur);

    moneyProv.addTransaction(
      merchant,
      -amt.abs(),
      cat,
      currency: cur,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved $sym${amt.toStringAsFixed(2)} to Wallet!")),
    );
  }

  void _saveToNotes() {
    if (_scannedData == null) return;
    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);
    final String merchant = _scannedData!['merchant'] ?? 'Receipt Purchase';
    final double amt = (_scannedData!['amount'] as num?)?.toDouble() ?? 0.0;
    final List items = _scannedData!['items'] ?? [];
    final String cur = _scannedData!['currency'] ?? moneyProv.currentCurrency;
    final String sym = AppCurrency.getSymbol(cur);

    final String content = "Total: $sym${amt.toStringAsFixed(2)} ($cur)\n\nItems:\n" +
        items.map((i) => "- $i").join('\n') +
        "\n\n#receipt #expense #shopping";

    final Note note = Note(
      id: const Uuid().v4(),
      title: "Receipt: $merchant",
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: "Personal",
      widgetType: "expense",
    );

    Provider.of<NotesProvider>(context, listen: false).addNote(note);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Receipt saved to Notes!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SHEET HANDLE
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TITLE
          Row(
            children: [
              Icon(CupertinoIcons.camera_viewfinder, color: isDark ? Colors.white : Colors.black, size: 24),
              const SizedBox(width: 10),
              Text(
                "AI Receipt & Document Scanner",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // OCR INPUT AREA
          const Text(
            "RECEIPT TEXT / PASTE OCR:",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _rawTextController,
            maxLines: 4,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          // SCAN BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isScanning ? null : _scanReceipt,
              icon: _isScanning
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: isDark ? Colors.black : Colors.white, strokeWidth: 2))
                  : Icon(CupertinoIcons.sparkles, color: isDark ? Colors.black : Colors.white, size: 18),
              label: Text(
                _isScanning ? "AI Parsing Receipt..." : "Scan with AI",
                style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // PARSED RESULTS
          if (_scannedData != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _scannedData!['merchant'] ?? 'Merchant',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                      Text(
                        "${AppCurrency.getSymbol(_scannedData!['currency'] ?? Provider.of<MoneyProvider>(context, listen: false).currentCurrency)}${((_scannedData!['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Category: ${_scannedData!['category'] ?? 'Shopping'}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // SAVE ACTIONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveToNotes,
                    icon: const Icon(CupertinoIcons.doc_text, size: 18),
                    label: const Text("Save Note"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveToWallet,
                    icon: const Icon(CupertinoIcons.money_dollar_circle, color: Colors.white, size: 18),
                    label: const Text("Save Wallet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}
