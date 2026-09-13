import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const MoneyTrackerApp());
}

// ---------------- SERVICE NOTIFIKASI CEPAT ----------------
class NotificationService {
  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'add_expense') {
          _openQuickAdd(0);
        } else if (response.actionId == 'add_income') {
          _openQuickAdd(1);
        } else {
          _openQuickAdd(0);
        }
      },
    );
  }

  static void _openQuickAdd(int type) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (ctx) => QuickAddNotificationLauncher(initialType: type),
      ),
    );
  }

  static Future<void> showOngoingNotification() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    const androidDetails = AndroidNotificationDetails(
      'mt_quick_tracker',
      'Notifikasi Cepat MT',
      channelDescription: 'Aksi cepat mencatat pemasukan dan pengeluaran',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'add_expense',
          '+ Pengeluaran',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'add_income',
          '+ Pemasukan',
          showsUserInterface: true,
        ),
      ],
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      888,
      'Money Tracker MT',
      null,
      notificationDetails,
    );
  }

  static Future<void> cancelOngoingNotification() async {
    await flutterLocalNotificationsPlugin.cancel(888);
  }
}

class MoneyTrackerApp extends StatefulWidget {
  const MoneyTrackerApp({super.key});

  @override
  State<MoneyTrackerApp> createState() => _MoneyTrackerAppState();
}

class _MoneyTrackerAppState extends State<MoneyTrackerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeAndNotification();
  }

  Future<void> _loadThemeAndNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    final isNotifEnabled = prefs.getBool('is_notif_enabled') ?? true;

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });

    if (isNotifEnabled) {
      await NotificationService.showOngoingNotification();
    }
  }

  void _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryLightGreen = Color(0xFF22C55E);
    const lightGreenHeader = Color(0xFF86EFAC);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLightGreen,
        brightness: Brightness.light,
        primary: const Color(0xFF16A34A),
        secondary: const Color(0xFF4ADE80),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightGreenHeader,
        foregroundColor: Color(0xFF064E3B),
        elevation: 0,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLightGreen,
        brightness: Brightness.dark,
        primary: const Color(0xFF4ADE80),
        secondary: const Color(0xFF86EFAC),
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Color(0xFF86EFAC),
        elevation: 0,
      ),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Money Tracker MT by Natanael',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: MainContainerScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

// ---------------- MODEL TRANSAKSI ----------------
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

// ---------------- MODEL KATEGORI KUSTOM ----------------
class CategoryItem {
  final String name;
  final int iconCode;
  final bool isExpense;

  CategoryItem({
    required this.name,
    required this.iconCode,
    required this.isExpense,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'iconCode': iconCode,
        'isExpense': isExpense,
      };

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
        name: json['name'] as String,
        iconCode: json['iconCode'] as int,
        isExpense: json['isExpense'] as bool,
      );
}

// ---------------- CONTAINER UTAMA ----------------
class MainContainerScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const MainContainerScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> with WidgetsBindingObserver {
  int _tabIndex = 0;
  List<Transaction> _transactions = [];
  List<CategoryItem> _categories = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    final txRaw = prefs.getString('mt_transactions');
    if (txRaw != null) {
      try {
        final List list = jsonDecode(txRaw);
        _transactions = list.map((e) => Transaction.fromJson(e)).toList();
      } catch (_) {}
    }

    final catRaw = prefs.getString('mt_categories');
    if (catRaw != null) {
      try {
        final List list = jsonDecode(catRaw);
        _categories = list.map((e) => CategoryItem.fromJson(e)).toList();
      } catch (_) {}
    }

    if (_categories.isEmpty) {
      _categories = _getDefaultCategories();
      await _saveCategories();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  List<CategoryItem> _getDefaultCategories() {
    return [
      CategoryItem(name: 'Makanan', iconCode: Icons.restaurant.codePoint, isExpense: true),
      CategoryItem(name: 'Minuman', iconCode: Icons.local_cafe.codePoint, isExpense: true),
      CategoryItem(name: 'Bensin', iconCode: Icons.local_gas_station.codePoint, isExpense: true),
      CategoryItem(name: 'Belanja', iconCode: Icons.shopping_bag.codePoint, isExpense: true),
      CategoryItem(name: 'wifi / internet', iconCode: Icons.wifi.codePoint, isExpense: true),
      CategoryItem(name: 'Transportasi', iconCode: Icons.directions_bus.codePoint, isExpense: true),
      CategoryItem(name: 'Mobil / Kereta', iconCode: Icons.directions_car.codePoint, isExpense: true),
      CategoryItem(name: 'Pakaian', iconCode: Icons.checkroom.codePoint, isExpense: true),
      CategoryItem(name: 'Perbaikan', iconCode: Icons.build.codePoint, isExpense: true),
      CategoryItem(name: 'Kesehatan', iconCode: Icons.medication.codePoint, isExpense: true),
      CategoryItem(name: 'Hiburan', iconCode: Icons.movie.codePoint, isExpense: true),
      CategoryItem(name: 'Telepon', iconCode: Icons.phone_android.codePoint, isExpense: true),
      CategoryItem(name: 'Pendidikan', iconCode: Icons.school.codePoint, isExpense: true),
      CategoryItem(name: 'Sosial', iconCode: Icons.people.codePoint, isExpense: true),
      CategoryItem(name: 'Elektronik', iconCode: Icons.devices.codePoint, isExpense: true),
      CategoryItem(name: 'Bepergian', iconCode: Icons.flight.codePoint, isExpense: true),
      CategoryItem(name: 'Rumah', iconCode: Icons.home.codePoint, isExpense: true),
      CategoryItem(name: 'Hadiah', iconCode: Icons.card_giftcard.codePoint, isExpense: true),
      CategoryItem(name: 'Donasi', iconCode: Icons.favorite.codePoint, isExpense: true),
      CategoryItem(name: 'Lainnya', iconCode: Icons.more_horiz.codePoint, isExpense: true),
      CategoryItem(name: 'Gaji', iconCode: Icons.work.codePoint, isExpense: false),
      CategoryItem(name: 'Bonus', iconCode: Icons.card_giftcard.codePoint, isExpense: false),
      CategoryItem(name: 'Usaha', iconCode: Icons.storefront.codePoint, isExpense: false),
      CategoryItem(name: 'Investasi', iconCode: Icons.trending_up.codePoint, isExpense: false),
      CategoryItem(name: 'Hadiah', iconCode: Icons.redeem.codePoint, isExpense: false),
      CategoryItem(name: 'Lainnya', iconCode: Icons.attach_money.codePoint, isExpense: false),
    ];
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_transactions.map((e) => e.toJson()).toList());
    await prefs.setString('mt_transactions', raw);
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_categories.map((e) => e.toJson()).toList());
    await prefs.setString('mt_categories', raw);
  }

  void _addTransaction(Transaction tx) {
    setState(() {
      _transactions.insert(0, tx);
    });
    _saveTransactions();
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((tx) => tx.id == id);
    });
    _saveTransactions();
  }

  void _addCustomCategory(CategoryItem cat) {
    setState(() {
      _categories.add(cat);
    });
    _saveCategories();
  }

  String formatRp(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(value).replaceAll(',', '.');
  }

  String _formatDateShort(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final dayName = days[d.weekday - 1];
    final monthName = months[d.month - 1];
    return '${d.day} $monthName $dayName';
  }

  List<Transaction> get _filteredTransactions {
    return _transactions.where((tx) {
      return tx.date.year == _selectedMonth.year && tx.date.month == _selectedMonth.month;
    }).toList();
  }

  double get _monthExpense {
    return _filteredTransactions
        .where((tx) => tx.isExpense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get _monthIncome {
    return _filteredTransactions
        .where((tx) => !tx.isExpense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get _monthBalance => _monthIncome - _monthExpense;

  void _openAddTransactionScreen([int initialType = 0]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AddTransactionScreen(
          categories: _categories,
          initialType: initialType,
          onAddTransaction: _addTransaction,
          onAddCategory: _addCustomCategory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      _buildHistoryTab(),
      AnalyticsScreen(
        transactions: _filteredTransactions,
        selectedMonth: _selectedMonth,
        onMonthChanged: (m) => setState(() => _selectedMonth = m),
        formatRp: formatRp,
        categories: _categories,
      ),
      ExportReportScreen(
        transactions: _transactions,
        selectedMonth: _selectedMonth,
        formatRp: formatRp,
      ),
      ProfileScreen(
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        totalTransactions: _transactions.length,
        categories: _categories,
        onAddCategory: _addCustomCategory,
      ),
    ];

    return Scaffold(
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Grafik',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Saya',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4ADE80),
        foregroundColor: const Color(0xFF064E3B),
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: () => _openAddTransactionScreen(0),
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHistoryTab() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final monthName = months[_selectedMonth.month - 1];

    final Map<String, List<Transaction>> grouped = {};
    for (var tx in _filteredTransactions) {
      final key = _formatDateShort(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return Column(
      children: [
        Container(
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFF86EFAC)
              : const Color(0xFF1E293B),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'MT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengelola Keuangan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'by Natanael',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).brightness == Brightness.light
                              ? const Color(0xFF065F46)
                              : const Color(0xFF86EFAC),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: _showMonthPicker,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  InkWell(
                    onTap: _showMonthPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_selectedMonth.year}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          Row(
                            children: [
                              Text(monthName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Icon(Icons.keyboard_arrow_down, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pengeluaran', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(formatRp(_monthExpense), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pemasukan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(formatRp(_monthIncome), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saldo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          formatRp(_monthBalance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _monthBalance >= 0 ? const Color(0xFF047857) : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Belum ada transaksi di bulan $monthName ${_selectedMonth.year}.',
                          style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 6),
                      const Text('Tekan tombol + di bawah untuk mencatat.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: grouped.keys.length,
                  itemBuilder: (ctx, idx) {
                    final dateKey = grouped.keys.elementAt(idx);
                    final txs = grouped[dateKey]!;

                    final dayExpense = txs.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
                    final dayIncome = txs.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[100]
                              : Colors.grey[900],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateKey, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  if (dayExpense > 0)
                                    Text('Pengeluaran: ${formatRp(dayExpense)}  ',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  if (dayIncome > 0)
                                    Text('Pemasukan: ${formatRp(dayIncome)}',
                                        style: const TextStyle(fontSize: 11, color: Colors.green)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ...txs.map((tx) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: tx.isExpense
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFDCFCE7),
                              child: Icon(
                                _getIconForCategory(tx.category),
                                color: tx.isExpense ? Colors.redAccent : Colors.green,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              tx.title.isEmpty ? tx.category : tx.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              '${tx.category} • ${tx.wallet}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                            trailing: Text(
                              '${tx.isExpense ? '-' : '+'}${formatRp(tx.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: tx.isExpense ? Colors.black87 : Colors.green[700],
                              ),
                            ),
                            onLongPress: () => _showDeleteConfirm(tx),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getIconForCategory(String name) {
    final found = _categories.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => CategoryItem(name: name, iconCode: Icons.attach_money.codePoint, isExpense: true),
    );
    return IconData(found.iconCode, fontFamily: 'MaterialIcons');
  }

  void _showDeleteConfirm(Transaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: Text('Hapus catatan "${tx.title.isEmpty ? tx.category : tx.title}" sebesar Rp ${formatRp(tx.amount)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _deleteTransaction(tx.id);
              Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMonthPicker() {
    int pickerYear = _selectedMonth.year;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setPickerState) {
            const shortNames = [
              'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
              'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
            ];

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih Periode Bulan & Tahun',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF86EFAC).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          onPressed: () => setPickerState(() => pickerYear--),
                        ),
                        Text(
                          '$pickerYear',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 18),
                          onPressed: () => setPickerState(() => pickerYear++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (ctx, idx) {
                      final monthNum = idx + 1;
                      final isSelected = pickerYear == _selectedMonth.year &&
                          monthNum == _selectedMonth.month;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedMonth = DateTime(pickerYear, monthNum, 1);
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4ADE80)
                                : Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey[100]
                                    : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF16A34A), width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              shortNames[idx],
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF064E3B)
                                    : null,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _selectedMonth = DateTime(now.year, now.month, 1);
                      });
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.today, size: 16, color: Color(0xFF16A34A)),
                    label: const Text(
                      'Kembali ke Bulan Ini',
                      style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------- ANALISIS SCREEN ----------------
class AnalyticsScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;
  final String Function(double) formatRp;
  final List<CategoryItem> categories;

  const AnalyticsScreen({
    super.key,
    required this.transactions,
    required this.selectedMonth,
    required this.onMonthChanged,
    required this.formatRp,
    required this.categories,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isExpense = true;
  int _chartType = 0;

  void _showAnalyticsMonthPicker(BuildContext context) {
    int pickerYear = widget.selectedMonth.year;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setPickerState) {
            const shortNames = [
              'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
              'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
            ];

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih Periode Bulan & Tahun',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF86EFAC).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          onPressed: () => setPickerState(() => pickerYear--),
                        ),
                        Text(
                          '$pickerYear',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 18),
                          onPressed: () => setPickerState(() => pickerYear++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (ctx, idx) {
                      final monthNum = idx + 1;
                      final isSelected = pickerYear == widget.selectedMonth.year &&
                          monthNum == widget.selectedMonth.month;

                      return InkWell(
                        onTap: () {
                          widget.onMonthChanged(DateTime(pickerYear, monthNum, 1));
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4ADE80)
                                : Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey[100]
                                    : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF16A34A), width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              shortNames[idx],
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF064E3B)
                                    : null,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      widget.onMonthChanged(DateTime(now.year, now.month, 1));
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.today, size: 16, color: Color(0xFF16A34A)),
                    label: const Text(
                      'Kembali ke Bulan Ini',
                      style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.transactions.where((tx) => tx.isExpense == _isExpense).toList();
    final double total = filtered.fold(0.0, (sum, tx) => sum + tx.amount);

    final Map<String, double> catMap = {};
    for (var tx in filtered) {
      catMap[tx.category] = (catMap[tx.category] ?? 0.0) + tx.amount;
    }
    final sortedCategories = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isExpense ? 'Analisis Pengeluaran' : 'Analisis Pemasukan',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Money Tracker MT by Natanael', style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _showAnalyticsMonthPicker(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFF86EFAC)
                : const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isExpense = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isExpense ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            'Pengeluaran',
                            style: TextStyle(
                              color: _isExpense ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isExpense = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isExpense ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            'Pemasukan',
                            style: TextStyle(
                              color: !_isExpense ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 48,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: 13,
              itemBuilder: (ctx, i) {
                final m = DateTime(widget.selectedMonth.year, widget.selectedMonth.month - 6 + i, 1);
                final isSelected = m.year == widget.selectedMonth.year && m.month == widget.selectedMonth.month;

                return GestureDetector(
                  onTap: () => widget.onMonthChanged(m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      border: isSelected
                          ? const Border(bottom: BorderSide(color: Color(0xFF16A34A), width: 3))
                          : null,
                    ),
                    child: Text(
                      '${monthNames[m.month - 1]} ${m.year}',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF16A34A) : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, icon: Icon(Icons.pie_chart_outline, size: 16), label: Text('Pie')),
                    ButtonSegment(value: 1, icon: Icon(Icons.show_chart, size: 16), label: Text('Garis')),
                    ButtonSegment(value: 2, icon: Icon(Icons.bar_chart, size: 16), label: Text('Batang')),
                  ],
                  selected: {_chartType},
                  onSelectionChanged: (val) => setState(() => _chartType = val.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Belum ada data untuk periode ini.', style: TextStyle(color: Colors.grey[600]))),
            )
          else ...[
            if (_chartType == 0) _buildPieView(sortedCategories, total),
            if (_chartType == 1) _buildLineView(filtered),
            if (_chartType == 2) _buildBarView(filtered),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Rincian per Kategori (Ketuk untuk melihat detail grafik)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
          ),
          ...sortedCategories.map((entry) {
            final catName = entry.key;
            final catAmount = entry.value;
            final pct = total > 0 ? (catAmount / total) : 0.0;
            final pctStr = (pct * 100).toStringAsFixed(2).replaceAll('.', ',');

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => CategoryDetailScreen(
                      categoryName: catName,
                      selectedMonth: widget.selectedMonth,
                      transactions: filtered.where((t) => t.category == catName).toList(),
                      formatRp: widget.formatRp,
                      isExpense: _isExpense,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF86EFAC).withOpacity(0.3),
                      child: Icon(_getIconByName(catName), size: 18, color: const Color(0xFF16A34A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(catName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(widget.formatRp(catAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('$pctStr%', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _getIconByName(String name) {
    final f = widget.categories.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => CategoryItem(name: name, iconCode: Icons.attach_money.codePoint, isExpense: true),
    );
    return IconData(f.iconCode, fontFamily: 'MaterialIcons');
  }

  Widget _buildPieView(List<MapEntry<String, double>> sorted, double total) {
    return Column(
      children: [
        Center(
          child: SizedBox(
            height: 190,
            width: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: CleanDonutPainter(data: sorted, total: total),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      widget.formatRp(total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: sorted.take(5).map((e) {
            final pct = (e.value / total * 100).toStringAsFixed(1);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${e.key} $pct%', style: const TextStyle(fontSize: 11)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildLineView(List<Transaction> txs) {
    final daysInMonth = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
    final Map<int, double> daily = {};
    for (int d = 1; d <= daysInMonth; d++) daily[d] = 0;
    for (var t in txs) {
      daily[t.date.day] = (daily[t.date.day] ?? 0) + t.amount;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tren Harian (Bulan Ini)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: CleanTrendLinePainter(dailyData: daily, daysInMonth: daysInMonth),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tgl 1', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Tgl ${daysInMonth ~/ 2}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Tgl $daysInMonth', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarView(List<Transaction> txs) {
    final weeks = [0.0, 0.0, 0.0, 0.0];
    for (var t in txs) {
      final w = ((t.date.day - 1) / 7).floor().clamp(0, 3);
      weeks[w] += t.amount;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribusi Mingguan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: CleanWeeklyBarPainter(weekValues: weeks),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Minggu 1', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Minggu 2', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Minggu 3', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Minggu 4+', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- DETAIL KATEGORI SCREEN ----------------
class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;
  final DateTime selectedMonth;
  final List<Transaction> transactions;
  final String Function(double) formatRp;
  final bool isExpense;

  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    required this.selectedMonth,
    required this.transactions,
    required this.formatRp,
    required this.isExpense,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  bool _sortByAmount = true;

  @override
  Widget build(BuildContext context) {
    final double total = widget.transactions.fold(0.0, (s, t) => s + t.amount);
    final daysInMonth = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
    final double average = daysInMonth > 0 ? (total / daysInMonth) : 0;

    final sortedList = List<Transaction>.from(widget.transactions);
    if (_sortByAmount) {
      sortedList.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      sortedList.sort((a, b) => b.date.compareTo(a.date));
    }

    final Map<int, double> daily = {};
    for (int d = 1; d <= daysInMonth; d++) daily[d] = 0;
    for (var t in widget.transactions) {
      daily[t.date.day] = (daily[t.date.day] ?? 0) + t.amount;
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${months[widget.selectedMonth.month - 1]} ${widget.selectedMonth.year}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total: ${widget.formatRp(total)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Rata-rata: ${widget.formatRp(average)} / hari', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: CustomPaint(
                painter: CleanTrendLinePainter(dailyData: daily, daysInMonth: daysInMonth),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tgl 1', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const Text('8', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const Text('15', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const Text('22', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('$daysInMonth', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  widget.isExpense ? 'Pengeluaran' : 'Pemasukan',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _sortByAmount = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _sortByAmount ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Urutkan jumlah',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _sortByAmount ? FontWeight.bold : FontWeight.normal,
                                  color: _sortByAmount ? Colors.black : Colors.grey[600])),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _sortByAmount = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: !_sortByAmount ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Urutkan tanggal',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: !_sortByAmount ? FontWeight.bold : FontWeight.normal,
                                  color: !_sortByAmount ? Colors.black : Colors.grey[600])),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...sortedList.map((tx) {
            final pct = total > 0 ? (tx.amount / total) : 0.0;
            final pctStr = (pct * 100).toStringAsFixed(2).replaceAll('.', ',');
            const mNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF86EFAC).withOpacity(0.3),
                    radius: 18,
                    child: const Icon(Icons.receipt, size: 16, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tx.title.isEmpty ? tx.category : tx.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(widget.formatRp(tx.amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${tx.date.day} ${mNames[tx.date.month - 1]} ${tx.date.year}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                            Text('$pctStr%', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------- TAMBAH TRANSAKSI SCREEN ----------------
class AddTransactionScreen extends StatefulWidget {
  final List<CategoryItem> categories;
  final Function(Transaction) onAddTransaction;
  final Function(CategoryItem) onAddCategory;
  final int initialType;

  const AddTransactionScreen({
    super.key,
    required this.categories,
    required this.onAddTransaction,
    required this.onAddCategory,
    this.initialType = 0,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late int _tabType;

  @override
  void initState() {
    super.initState();
    _tabType = widget.initialType;
  }

  void _onCategorySelected(CategoryItem cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => InputTransactionBottomSheet(
        category: cat,
        isExpense: _tabType == 0,
        onSave: (tx) {
          widget.onAddTransaction(tx);
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    int selectedIconCode = Icons.star.codePoint;

    final sampleIcons = [
      Icons.fastfood,
      Icons.icecream,
      Icons.sports_esports,
      Icons.local_hospital,
      Icons.fitness_center,
      Icons.pool,
      Icons.flight,
      Icons.directions_bike,
      Icons.camera_alt,
      Icons.music_note,
      Icons.work,
      Icons.savings,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Tambah / Kustomisasi Kategori'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Kategori', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerLeft, child: Text('Pilih Ikon:', style: TextStyle(fontSize: 12))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sampleIcons.map((ic) {
                      final isSel = ic.codePoint == selectedIconCode;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIconCode = ic.codePoint),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF86EFAC) : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(ic, size: 20),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    widget.onAddCategory(
                      CategoryItem(name: name, iconCode: selectedIconCode, isExpense: _tabType == 0),
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _tabType == 0;
    final filteredCategories = widget.categories.where((c) => c.isExpense == isExpense).toList();

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batalkan', style: TextStyle(color: Color(0xFF064E3B), fontSize: 13)),
        ),
        leadingWidth: 80,
        title: const Text('Tambahkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFF86EFAC)
                : const Color(0xFF1E293B),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _buildTypeTab(0, 'Pengeluaran'),
                _buildTypeTab(1, 'Pemasukan'),
                _buildTypeTab(2, 'Transfer'),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: filteredCategories.length + 1,
              itemBuilder: (ctx, idx) {
                if (idx == filteredCategories.length) {
                  return GestureDetector(
                    onTap: _showAddCategoryDialog,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.grey[200],
                          child: const Icon(Icons.add, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        const Text('Pengaturan', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                }

                final cat = filteredCategories[idx];
                return GestureDetector(
                  onTap: () => _onCategorySelected(cat),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey[200],
                        child: Icon(IconData(cat.iconCode, fontFamily: 'MaterialIcons'), size: 24, color: Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Text(cat.name, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(int idx, String title) {
    final isSel = _tabType == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabType = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSel ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- QUICK ADD LAUNCHER ----------------
class QuickAddNotificationLauncher extends StatefulWidget {
  final int initialType;
  const QuickAddNotificationLauncher({super.key, required this.initialType});

  @override
  State<QuickAddNotificationLauncher> createState() => _QuickAddNotificationLauncherState();
}

class _QuickAddNotificationLauncherState extends State<QuickAddNotificationLauncher> {
  List<CategoryItem> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final catRaw = prefs.getString('mt_categories');
    if (catRaw != null) {
      try {
        final List list = jsonDecode(catRaw);
        _categories = list.map((e) => CategoryItem.fromJson(e)).toList();
      } catch (_) {}
    }
    if (_categories.isEmpty) {
      _categories = [
        CategoryItem(name: 'Makanan', iconCode: Icons.restaurant.codePoint, isExpense: true),
        CategoryItem(name: 'Minuman', iconCode: Icons.local_cafe.codePoint, isExpense: true),
        CategoryItem(name: 'Bensin', iconCode: Icons.local_gas_station.codePoint, isExpense: true),
        CategoryItem(name: 'Belanja', iconCode: Icons.shopping_bag.codePoint, isExpense: true),
        CategoryItem(name: 'wifi / internet', iconCode: Icons.wifi.codePoint, isExpense: true),
        CategoryItem(name: 'Transportasi', iconCode: Icons.directions_bus.codePoint, isExpense: true),
        CategoryItem(name: 'Gaji', iconCode: Icons.work.codePoint, isExpense: false),
        CategoryItem(name: 'Bonus', iconCode: Icons.card_giftcard.codePoint, isExpense: false),
        CategoryItem(name: 'Lainnya', iconCode: Icons.more_horiz.codePoint, isExpense: true),
      ];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveTransaction(Transaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final txRaw = prefs.getString('mt_transactions');
    List<Transaction> list = [];
    if (txRaw != null) {
      try {
        final List l = jsonDecode(txRaw);
        list = l.map((e) => Transaction.fromJson(e)).toList();
      } catch (_) {}
    }
    list.insert(0, tx);
    await prefs.setString('mt_transactions', jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AddTransactionScreen(
      categories: _categories,
      initialType: widget.initialType,
      onAddTransaction: (tx) async {
        await _saveTransaction(tx);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Transaksi ${tx.category} Rp ${NumberFormat('#,##0', 'en_US').format(tx.amount).replaceAll(',', '.')} tersimpan!',
              ),
            ),
          );
        }
      },
      onAddCategory: (cat) {},
    );
  }
}

// ---------------- INPUT TRANSACTION BOTTOM SHEET ----------------
class InputTransactionBottomSheet extends StatefulWidget {
  final CategoryItem category;
  final bool isExpense;
  final Function(Transaction) onSave;

  const InputTransactionBottomSheet({
    super.key,
    required this.category,
    required this.isExpense,
    required this.onSave,
  });

  @override
  State<InputTransactionBottomSheet> createState() => _InputTransactionBottomSheetState();
}

class _InputTransactionBottomSheetState extends State<InputTransactionBottomSheet> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  String _wallet = 'Tunai';
  final _wallets = ['Tunai', 'Rekening Bank', 'E-Wallet'];
  DateTime _transactionDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF86EFAC),
                child: Icon(IconData(widget.category.iconCode, fontFamily: 'MaterialIcons'), color: const Color(0xFF064E3B)),
              ),
              const SizedBox(width: 10),
              Text(
                'Catat ${widget.category.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
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
              labelText: 'Catatan / Deskripsi (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _wallet,
            decoration: const InputDecoration(labelText: 'Pilih Dompet / Akun', border: OutlineInputBorder()),
            items: _wallets.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
            onChanged: (v) => setState(() => _wallet = v!),
          ),
          const SizedBox(height: 12),
          // Pemilih Tanggal Bebas (Date & Time Picker)
          InkWell(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _transactionDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2050),
              );
              if (pickedDate != null) {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_transactionDate),
                );
                setState(() {
                  _transactionDate = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime?.hour ?? _transactionDate.hour,
                    pickedTime?.minute ?? _transactionDate.minute,
                  );
                });
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 10),
                  Text(
                    'Tanggal: ${DateFormat('dd MMM yyyy, HH:mm').format(_transactionDate)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  const Text('Ubah', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ADE80),
                foregroundColor: const Color(0xFF064E3B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final amount = double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                if (amount == null || amount <= 0) return;

                final newTx = Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  amount: amount,
                  isExpense: widget.isExpense,
                  category: widget.category.name,
                  wallet: _wallet,
                  date: _transactionDate,
                );
                widget.onSave(newTx);
              },
              child: const Text('Simpan Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- TAB 3: LAPORAN ----------------
class ExportReportScreen extends StatelessWidget {
  final List<Transaction> transactions;
  final DateTime selectedMonth;
  final String Function(double) formatRp;

  const ExportReportScreen({
    super.key,
    required this.transactions,
    required this.selectedMonth,
    required this.formatRp,
  });

  Future<void> _exportSpreadsheet(BuildContext context) async {
    final csv = StringBuffer();
    csv.writeln('ID,Tanggal,Tipe,Kategori,Dompet,Catatan,Nominal');

    for (var tx in transactions) {
      final type = tx.isExpense ? 'Pengeluaran' : 'Pemasukan';
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.date);
      csv.writeln('"${tx.id}","$dateStr","$type","${tx.category}","${tx.wallet}","${tx.title.replaceAll('"', '""')}",${tx.amount}');
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Laporan_Keuangan_MT_Natanael.csv');
      await file.writeAsString(csv.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Keuangan MT (Spreadsheet CSV) by Natanael',
      );
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: csv.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format CSV berhasil disalin ke clipboard!')),
        );
      }
    }
  }

  Future<void> _exportDocument(BuildContext context) async {
    final double totalIncome = transactions.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final double totalExpense = transactions.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
    final double balance = totalIncome - totalExpense;

    final doc = StringBuffer();
    doc.writeln('<html><head><meta charset="utf-8"><title>Laporan Keuangan MT by Natanael</title>');
    doc.writeln('<style>');
    doc.writeln('body { font-family: sans-serif; padding: 20px; color: #1E293B; }');
    doc.writeln('h1 { color: #15803D; margin-bottom: 4px; }');
    doc.writeln('.sub { color: #64748B; font-size: 13px; margin-bottom: 20px; }');
    doc.writeln('.card { background-color: #F0FDF4; border: 1px solid #BBF7D0; border-radius: 8px; padding: 15px; margin-bottom: 25px; }');
    doc.writeln('table { width: 100%; border-collapse: collapse; margin-top: 15px; }');
    doc.writeln('th, td { border: 1px solid #E2E8F0; padding: 8px; text-align: left; font-size: 13px; }');
    doc.writeln('th { background-color: #86EFAC; color: #064E3B; }');
    doc.writeln('tr:nth-child(even) { background-color: #F8FAFC; }');
    doc.writeln('.income { color: #16A34A; font-weight: bold; }');
    doc.writeln('.expense { color: #DC2626; font-weight: bold; }');
    doc.writeln('</style></head><body>');
    doc.writeln('<h1>Money Tracker (MT)</h1>');
    doc.writeln('<div class="sub">Laporan Arus Kas • Dibuat oleh: Natanael • Tanggal: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}</div>');
    doc.writeln('<div class="card">');
    doc.writeln('<p><strong>Total Pemasukan:</strong> Rp ${formatRp(totalIncome)}</p>');
    doc.writeln('<p><strong>Total Pengeluaran:</strong> Rp ${formatRp(totalExpense)}</p>');
    doc.writeln('<p><strong>Total Saldo Akhir:</strong> Rp ${formatRp(balance)}</p>');
    doc.writeln('</div>');
    doc.writeln('<h3>Rincian Riwayat Transaksi</h3>');
    doc.writeln('<table><tr><th>Tanggal</th><th>Tipe</th><th>Kategori</th><th>Dompet</th><th>Catatan</th><th>Nominal</th></tr>');

    for (var tx in transactions) {
      final type = tx.isExpense ? 'Pengeluaran' : 'Pemasukan';
      final typeClass = tx.isExpense ? 'expense' : 'income';
      final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(tx.date);
      doc.writeln('<tr><td>$dateStr</td><td class="$typeClass">$type</td><td>${tx.category}</td><td>${tx.wallet}</td><td>${tx.title.isEmpty ? '-' : tx.title}</td><td>Rp ${formatRp(tx.amount)}</td></tr>');
    }

    doc.writeln('</table></body></html>');

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Laporan_Keuangan_MT_Natanael.doc');
      await file.writeAsString(doc.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Keuangan MT (Dokumen Word / Office) by Natanael',
      );
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: doc.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan Dokumen berhasil disalin ke clipboard!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Ekspor Laporan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Money Tracker MT by Natanael', style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ringkasan Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Total transaksi tersimpan: ${transactions.length} transaksi.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Data dapat diekspor langsung ke spreadsheet atau dokumen untuk dibagikan / dibuka di Excel dan Word.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(Icons.table_chart, color: Color(0xFF16A34A)),
              ),
              title: const Text('Ekspor File Spreadsheet (.csv)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Kompatibel dengan Microsoft Excel & Google Sheets', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.share, color: Color(0xFF16A34A)),
              onTap: () => _exportSpreadsheet(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.description, color: Color(0xFF2563EB)),
              ),
              title: const Text('Ekspor File Dokumen (.doc / Word)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Laporan berformat tabel rapi untuk Microsoft Word & WPS Office', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.share, color: Color(0xFF2563EB)),
              onTap: () => _exportDocument(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- TAB 4: SAYA (PENGATURAN) ----------------
class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final int totalTransactions;
  final List<CategoryItem> categories;
  final Function(CategoryItem) onAddCategory;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.totalTransactions,
    required this.categories,
    required this.onAddCategory,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isNotifEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotifState();
  }

  Future<void> _loadNotifState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotifEnabled = prefs.getBool('is_notif_enabled') ?? true;
    });
  }

  Future<void> _toggleNotification(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_notif_enabled', val);
    setState(() {
      _isNotifEnabled = val;
    });

    if (val) {
      await NotificationService.showOngoingNotification();
    } else {
      await NotificationService.cancelOngoingNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'MT',
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Money Tracker MT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  const Text('by Natanael', style: TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Versi 2.2.0 • 100% Offline', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF22C55E)),
              title: const Text('Notifikasi Cepat di Atas Layar', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Selalu aktif di bilah status (+ Pengeluaran & + Pemasukan)', style: TextStyle(fontSize: 12)),
              value: _isNotifEnabled,
              activeColor: const Color(0xFF22C55E),
              onChanged: _toggleNotification,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              secondary: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF22C55E)),
              title: const Text('Mode Gelap (Dark Mode)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(widget.isDarkMode ? 'Tema gelap aktif' : 'Tema terang aktif (Hijau Muda)', style: const TextStyle(fontSize: 12)),
              value: widget.isDarkMode,
              activeColor: const Color(0xFF22C55E),
              onChanged: widget.onThemeChanged,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.category_outlined, color: Color(0xFF22C55E)),
              title: const Text('Jumlah Kategori Aktif', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text('${widget.categories.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.storage_outlined, color: Color(0xFF22C55E)),
              title: const Text('Total Riwayat Catatan', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text('${widget.totalTransactions} transaksi', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- CUSTOM PAINTERS ----------------
class CleanDonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final double total;

  CleanDonutPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final colors = [
      const Color(0xFF4ADE80),
      const Color(0xFFF87171),
      const Color(0xFF60A5FA),
      const Color(0xFFFBBF24),
      const Color(0xFFA78BFA),
      const Color(0xFF34D399),
      const Color(0xFFF472B6),
      const Color(0xFF38BDF8),
    ];

    double startAngle = -math.pi / 2;
    int idx = 0;

    for (var item in data) {
      final sweep = (item.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[idx % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );

      startAngle += sweep;
      idx++;
    }

    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.65, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CleanTrendLinePainter extends CustomPainter {
  final Map<int, double> dailyData;
  final int daysInMonth;

  CleanTrendLinePainter({required this.dailyData, required this.daysInMonth});

  @override
  void paint(Canvas canvas, Size size) {
    double maxVal = 1000;
    for (var v in dailyData.values) {
      if (v > maxVal) maxVal = v;
    }

    final linePaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = const Color(0xFF16A34A);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF4ADE80).withOpacity(0.35), const Color(0xFF4ADE80).withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (daysInMonth - 1);

    for (int day = 1; day <= daysInMonth; day++) {
      final val = dailyData[day] ?? 0;
      final x = (day - 1) * stepX;
      final y = size.height - ((val / maxVal) * (size.height - 15));

      if (day == 1) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (val > 0) {
        canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CleanWeeklyBarPainter extends CustomPainter {
  final List<double> weekValues;

  CleanWeeklyBarPainter({required this.weekValues});

  @override
  void paint(Canvas canvas, Size size) {
    double maxVal = 1000;
    for (var v in weekValues) {
      if (v > maxVal) maxVal = v;
    }

    final barPaint = Paint()..color = const Color(0xFF4ADE80);
    final slotWidth = size.width / 4;
    final barWidth = slotWidth * 0.45;

    for (int i = 0; i < 4; i++) {
      final val = weekValues[i];
      final h = (val / maxVal) * (size.height - 10);
      final x = (i * slotWidth) + (slotWidth / 2) - (barWidth / 2);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barWidth, h),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
