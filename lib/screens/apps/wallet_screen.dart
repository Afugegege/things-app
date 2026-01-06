import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/money_provider.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../config/theme.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final moneyProvider = Provider.of<MoneyProvider>(context);

    return LifeAppScaffold(
      title: "WALLET",
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTransaction(context),
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. CARD
          Container(
            height: 200,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Row( 
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Icon(Icons.memory, color: Colors.white54, size: 40),
                    Icon(CupertinoIcons.wifi, color: Colors.white54, size: 20),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TOTAL BALANCE", style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 5),
                    Text("\$${moneyProvider.balance.toStringAsFixed(2)}", style: Theme.of(context).textTheme.displayMedium),
                  ],
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("**** 8829", style: TextStyle(color: Colors.white70)),
                    Text("EXP 12/28", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),

          // 2. RECENT ACTIVITY
          Text("RECENT ACTIVITY", style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 15),
          ...moneyProvider.transactions.map((tx) {
            final bool isExp = (tx['amount'] as double) < 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isExp ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExp ? CupertinoIcons.arrow_down : CupertinoIcons.arrow_up,
                      color: isExp ? Colors.redAccent : Colors.greenAccent,
                      size: 20
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(tx['date'].toString().split(' ')[0], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(
                    "\$${tx['amount']}",
                    style: TextStyle(color: isExp ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _addTransaction(BuildContext context) {
    // Transaction logic
  }
}