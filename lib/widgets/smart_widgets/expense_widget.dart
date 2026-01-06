import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';

class ExpenseSummaryWidget extends StatelessWidget {
  const ExpenseSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final moneyProvider = Provider.of<MoneyProvider>(context);
    final transactions = moneyProvider.transactions;
    
    // Calculate Today's Spend
    final double todaySpent = transactions
        .where((t) => (t['amount'] as double) < 0)
        .fold(0.0, (sum, t) => sum + (t['amount'] as double));

    return Container(
      height: 140, 
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Matte Black
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12), // Subtle border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SPENDING", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              Icon(Icons.arrow_outward, color: Colors.white38, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            "\$${todaySpent.abs().toStringAsFixed(0)}",
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300), // Thin clean font
          ),
          const SizedBox(height: 5),
          const Text("Today", style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}