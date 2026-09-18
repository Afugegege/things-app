class AppCurrency {
  final String code;
  final String symbol;
  final String name;
  final String flag;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
  });

  static const List<AppCurrency> currencies = [
    AppCurrency(code: 'USD', symbol: '\$', name: 'US Dollar', flag: 'USD'),
    AppCurrency(code: 'EUR', symbol: '€', name: 'Euro', flag: 'EUR'),
    AppCurrency(code: 'GBP', symbol: '£', name: 'British Pound', flag: 'GBP'),
    AppCurrency(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', flag: 'MYR'),
    AppCurrency(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', flag: 'SGD'),
    AppCurrency(code: 'JPY', symbol: '¥', name: 'Japanese Yen', flag: 'JPY'),
    AppCurrency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', flag: 'CNY'),
    AppCurrency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', flag: 'AUD'),
    AppCurrency(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', flag: 'CAD'),
    AppCurrency(code: 'KRW', symbol: '₩', name: 'South Korean Won', flag: 'KRW'),
    AppCurrency(code: 'INR', symbol: '₹', name: 'Indian Rupee', flag: 'INR'),
    AppCurrency(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', flag: 'CHF'),
    AppCurrency(code: 'THB', symbol: '฿', name: 'Thai Baht', flag: 'THB'),
    AppCurrency(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', flag: 'IDR'),
    AppCurrency(code: 'PHP', symbol: '₱', name: 'Philippine Peso', flag: 'PHP'),
    AppCurrency(code: 'VND', symbol: '₫', name: 'Vietnamese Dong', flag: 'VND'),
  ];

  static AppCurrency fromCode(String? code) {
    if (code == null || code.isEmpty) {
      return currencies.first; // Default USD
    }
    final upper = code.trim().toUpperCase();
    return currencies.firstWhere(
      (c) => c.code == upper,
      orElse: () => AppCurrency(
        code: upper,
        symbol: upper,
        name: upper,
        flag: upper,
      ),
    );
  }

  static String getSymbol(String? code) {
    return fromCode(code).symbol;
  }

  static String format(double amount, String? code, {bool isExpense = false}) {
    final cur = fromCode(code);
    final absAmount = amount.abs().toStringAsFixed(2);
    if (amount < 0 || isExpense) {
      return '-${cur.symbol}$absAmount';
    }
    return '${cur.symbol}$absAmount';
  }
}
