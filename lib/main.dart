import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoneyTrackerApp());
}

class MoneyTrackerApp extends StatelessWidget {
  const MoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Tracker by Natanael',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D9488),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D9488),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class Transaction {
  final String id;
  final String title;
  final double amount;
  final bool isExpense;
  final String category;
  final String wallet;
  final DateTime date;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.category,
    required this.wallet,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'isExpense': isExpense,
        'category': category,
        'wallet': wallet,
        'date': date.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        isExpense: json['isExpense'] as bool,
        category: json['category'] as String,
        wallet: (json['wallet'] as String?) ?? 'Tunai',
        date: DateTime.parse(json['date'] as String),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('transactions');
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        _transactions = list.map((e) => Transaction.fromJson(e)).toList();
      } catch (_) {}
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_transactions.map((e) => e.toJson()).toList());
    await prefs.setString('transactions', raw);
  }

  void _addTransaction(Transaction tx) {
    setState(() {
      _transactions.insert(0, tx);
    });
    _saveData();
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((tx) => tx.id == id);
    });
    _saveData();
  }

  double get totalIncome => _transactions
      .where((tx) => !tx.isExpense)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get totalExpense => _transactions
      .where((tx) => tx.isExpense)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get currentBalance => totalIncome - totalExpense;

  String formatRp(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return 'Rp ${formatter.format(value).replaceAll(',', '.')}';
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final day = d.day.toString().padLeft(2, '0');
    final month = months[d.month - 1];
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day $month ${d.year}, $hour:$min';
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionSheet(onAdd: _addTransaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Money Tracker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'by Natanael',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentIndex == 0
              ? _buildTransactionsTab()
              : _buildAnalysisTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analisis',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        _buildBalanceCard(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Transaksi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_transactions.length} transaksi',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada transaksi tercatat.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tekan tombol + Catat untuk memulai.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ..._transactions.map((tx) => _buildTransactionItem(tx)),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Saldo',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Text(
              formatRp(currentBalance),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: currentBalance >= 0
                    ? Theme.of(context).colorScheme.primary
                    : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Pemasukan',
                              style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatRp(totalIncome),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.arrow_upward, color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Pengeluaran',
                              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatRp(totalExpense),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction tx) {
    final dateStr = _formatDate(tx.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tx.isExpense
              ? Colors.red.withOpacity(0.15)
              : Colors.green.withOpacity(0.15),
          child: Icon(
            _getCategoryIcon(tx.category),
            color: tx.isExpense ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          tx.title.isEmpty ? tx.category : tx.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          '${tx.wallet} • $dateStr',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${tx.isExpense ? '-' : '+'}${formatRp(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: tx.isExpense ? Colors.redAccent : Colors.green,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: () => _deleteTransaction(tx.id),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Makanan':
        return Icons.restaurant;
      case 'Transportasi':
        return Icons.directions_car;
      case 'Belanja':
        return Icons.shopping_bag;
      case 'Tagihan':
        return Icons.receipt;
      case 'Hiburan':
        return Icons.movie;
      case 'Kesehatan':
        return Icons.medication;
      case 'Gaji':
        return Icons.work;
      case 'Bonus':
        return Icons.card_giftcard;
      case 'Investasi':
        return Icons.trending_up;
      default:
        return Icons.attach_money;
    }
  }

  Widget _buildAnalysisTab() {
    final expenses = _transactions.where((tx) => tx.isExpense).toList();
    final Map<String, double> categoryMap = {};
    for (var tx in expenses) {
      categoryMap[tx.category] = (categoryMap[tx.category] ?? 0.0) + tx.amount;
    }

    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final Map<DateTime, double> dailyExpenses = {};
    final Map<DateTime, double> dailyIncomes = {};
    for (var d in last7Days) {
      dailyExpenses[d] = 0;
      dailyIncomes[d] = 0;
    }

    for (var tx in _transactions) {
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (dailyExpenses.containsKey(txDate)) {
        if (tx.isExpense) {
          dailyExpenses[txDate] = dailyExpenses[txDate]! + tx.amount;
        } else {
          dailyIncomes[txDate] = dailyIncomes[txDate]! + tx.amount;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // 1. Diagram Batang (Bar Chart)
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: Color(0xFF0D9488), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Diagram Batang (7 Hari Terakhir)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Perbandingan Pemasukan (Hijau) vs Pengeluaran (Merah)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: BarChartPainter(
                      dates: last7Days,
                      incomes: dailyIncomes,
                      expenses: dailyExpenses,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Diagram Garis (Line Chart)
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Diagram Garis (Tren Pengeluaran)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tren fluktuasi pengeluaran Anda dalam 7 hari terakhir',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      dates: last7Days,
                      values: dailyExpenses,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Diagram Lingkaran (Pie Chart)
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Diagram Lingkaran (Kategori)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Persentase pengeluaran berdasarkan kategori',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                if (categoryMap.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Text('Belum ada pengeluaran untuk dianalisis.'),
                    ),
                  )
                else ...[
                  Center(
                    child: SizedBox(
                      height: 180,
                      width: 180,
                      child: CustomPaint(
                        painter: PieChartPainter(categoryMap: categoryMap),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPieLegend(categoryMap),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieLegend(Map<String, double> map) {
    final total = map.values.fold(0.0, (sum, v) => sum + v);
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
    ];
    int idx = 0;
    return Column(
      children: map.entries.map((e) {
        final color = colors[idx % colors.length];
        idx++;
        final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : '0';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
              Text('$pct% (${formatRp(e.value)})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Custom Painter: Bar Chart
class BarChartPainter extends CustomPainter {
  final List<DateTime> dates;
  final Map<DateTime, double> incomes;
  final Map<DateTime, double> expenses;

  BarChartPainter({required this.dates, required this.incomes, required this.expenses});

  @override
  void paint(Canvas canvas, Size size) {
    double maxVal = 1000;
    for (var d in dates) {
      if ((incomes[d] ?? 0) > maxVal) maxVal = incomes[d]!;
      if ((expenses[d] ?? 0) > maxVal) maxVal = expenses[d]!;
    }

    final incomePaint = Paint()..color = const Color(0xFF10B981);
    final expensePaint = Paint()..color = const Color(0xFFEF4444);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final slotWidth = size.width / dates.length;
    final barWidth = (slotWidth - 12) / 2;

    for (int i = 0; i < dates.length; i++) {
      final d = dates[i];
      final inc = incomes[d] ?? 0;
      final exp = expenses[d] ?? 0;

      final incHeight = (inc / maxVal) * (size.height - 30);
      final expHeight = (exp / maxVal) * (size.height - 30);

      final x = i * slotWidth + 6;

      final incRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (size.height - 30) - incHeight, barWidth, incHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(incRect, incomePaint);

      final expRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + barWidth + 2, (size.height - 30) - expHeight, barWidth, expHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(expRect, expensePaint);

      const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      final dayLabel = days[d.weekday - 1];
      textPainter.text = TextSpan(
        text: dayLabel,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (slotWidth / 2) - (textPainter.width / 2) - 3, size.height - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Painter: Line Chart
class LineChartPainter extends CustomPainter {
  final List<DateTime> dates;
  final Map<DateTime, double> values;

  LineChartPainter({required this.dates, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    double maxVal = 1000;
    for (var d in dates) {
      if ((values[d] ?? 0) > maxVal) maxVal = values[d]!;
    }

    final linePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = Colors.orange;
    final dotInnerPaint = Paint()..color = Colors.white;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.orange.withOpacity(0.3), Colors.orange.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height - 30));

    final slotWidth = size.width / (dates.length - 1);
    final path = Path();
    final fillPath = Path();

    List<Offset> points = [];

    for (int i = 0; i < dates.length; i++) {
      final d = dates[i];
      final val = values[d] ?? 0;
      final y = (size.height - 30) - ((val / maxVal) * (size.height - 40));
      final x = i * slotWidth;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - 30);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height - 30);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5, dotPaint);
      canvas.drawCircle(points[i], 2.5, dotInnerPaint);

      const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      final dayLabel = days[dates[i].weekday - 1];
      textPainter.text = TextSpan(
        text: dayLabel,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(points[i].dx - (textPainter.width / 2), size.height - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Painter: Pie Chart
class PieChartPainter extends CustomPainter {
  final Map<String, double> categoryMap;

  PieChartPainter({required this.categoryMap});

  @override
  void paint(Canvas canvas, Size size) {
    final total = categoryMap.values.fold(0.0, (sum, v) => sum + v);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
    ];

    double startAngle = -math.pi / 2;
    int idx = 0;

    for (var entry in categoryMap.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[idx % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
      idx++;
    }

    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Add Transaction Modal
class AddTransactionSheet extends StatefulWidget {
  final Function(Transaction) onAdd;
  const AddTransactionSheet({super.key, required this.onAdd});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  bool _isExpense = true;
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  String _category = 'Makanan';
  String _wallet = 'Tunai';

  final List<String> _expenseCategories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Kesehatan',
    'Lainnya',
  ];

  final List<String> _incomeCategories = [
    'Gaji',
    'Usaha',
    'Bonus',
    'Investasi',
    'Lainnya',
  ];

  final List<String> _wallets = ['Tunai', 'Rekening Bank', 'E-Wallet'];

  @override
  Widget build(BuildContext context) {
    final categories = _isExpense ? _expenseCategories : _incomeCategories;
    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tambah Transaksi Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Pengeluaran')),
                ButtonSegment(value: false, label: Text('Pemasukan')),
              ],
              selected: {_isExpense},
              onSelectionChanged: (val) {
                setState(() {
                  _isExpense = val.first;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan / Judul (Opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _wallet,
                    decoration: const InputDecoration(labelText: 'Dompet', border: OutlineInputBorder()),
                    items: _wallets.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                    onChanged: (v) => setState(() => _wallet = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final amount = double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (amount == null || amount <= 0) return;

                  final newTx = Transaction(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: _titleCtrl.text.trim(),
                    amount: amount,
                    isExpense: _isExpense,
                    category: _category,
                    wallet: _wallet,
                    date: DateTime.now(),
                  );

                  widget.onAdd(newTx);
                  Navigator.pop(context);
                },
                child: const Text('Simpan Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
