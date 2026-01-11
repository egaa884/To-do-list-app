import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'database_helper.dart';
import 'task_model.dart';
import 'transaction_model.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'auth_page.dart'; // Import Halaman Login

// --- GLOBAL STATE ---
final ValueNotifier<Color> appThemeColor = ValueNotifier(Colors.indigo);
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.system);
final ValueNotifier<double> appTextScale = ValueNotifier(1.0);
final ValueNotifier<String> filterTypeNotifier = ValueNotifier('Category');
final ValueNotifier<String> selectedFilterNotifier = ValueNotifier('Semua');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- PERUBAHAN 1: Inisialisasi Firebase ---
  await Firebase.initializeApp();
  // ------------------------------------------

  await initializeDateFormatting('id_ID', null);

  final prefs = await SharedPreferences.getInstance();

  // Load Settings
  final int? savedColor = prefs.getInt('theme_color');
  if (savedColor != null) appThemeColor.value = Color(savedColor);

  final String? savedThemeMode = prefs.getString('theme_mode');
  if (savedThemeMode == 'Dark')
    appThemeMode.value = ThemeMode.dark;
  else if (savedThemeMode == 'Light') appThemeMode.value = ThemeMode.light;

  final String? savedTextSize = prefs.getString('text_size');
  if (savedTextSize == 'Kecil')
    appTextScale.value = 0.85;
  else if (savedTextSize == 'Besar') appTextScale.value = 1.15;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appThemeColor,
      builder: (context, color, _) {
        return ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeMode,
            builder: (context, themeMode, _) {
              return ValueListenableBuilder<double>(
                  valueListenable: appTextScale,
                  builder: (context, textScale, _) {
                    return MaterialApp(
                      title: 'To-Do List Pro',
                      debugShowCheckedModeBanner: false,
                      themeMode: themeMode,
                      theme: ThemeData(
                        colorScheme: ColorScheme.fromSeed(
                            seedColor: color, brightness: Brightness.light),
                        useMaterial3: true,
                        fontFamily: 'Roboto',
                        scaffoldBackgroundColor: Colors.grey[50],
                      ),
                      darkTheme: ThemeData(
                        colorScheme: ColorScheme.fromSeed(
                            seedColor: color, brightness: Brightness.dark),
                        useMaterial3: true,
                        fontFamily: 'Roboto',
                      ),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              textScaler: TextScaler.linear(textScale)),
                          child: child!,
                        );
                      },
                      // --- PERUBAHAN 2: Logika Cek Login (StreamBuilder) ---
                      home: StreamBuilder<User?>(
                        stream: FirebaseAuth.instance.authStateChanges(),
                        builder: (context, snapshot) {
                          // Jika sedang loading cek status
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Scaffold(
                                body:
                                    Center(child: CircularProgressIndicator()));
                          }
                          // Jika User Ada (Sudah Login) -> Masuk ke MainScreen
                          if (snapshot.hasData) {
                            return const MainScreen();
                          }
                          // Jika User Kosong (Belum Login) -> Masuk ke AuthPage
                          else {
                            return AuthPage();
                          }
                        },
                      ),
                      // ----------------------------------------------------
                    );
                  });
            });
      },
    );
  }
}

// --- MAIN SCREEN ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<CalendarPageState> _calendarPageKey =
      GlobalKey<CalendarPageState>();
  final GlobalKey<ProfilePageState> _profilePageKey =
      GlobalKey<ProfilePageState>();
  final GlobalKey<TaskListPageState> _taskPageKey =
      GlobalKey<TaskListPageState>();
  final GlobalKey<FinancePageState> _financePageKey =
      GlobalKey<FinancePageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TaskListPage(
        key: _taskPageKey,
        onTaskChanged: () {
          _calendarPageKey.currentState?.refreshSelectedDate();
          _profilePageKey.currentState?.refreshStats();
        },
      ),
      FinancePage(key: _financePageKey), // HALAMAN KEUANGAN BARU
      CalendarPage(key: _calendarPageKey),
      ProfilePage(key: _profilePageKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _currentIndex == 0 ? const AppDrawer() : null,
      appBar: AppBar(
        title: Text(_getAppBarTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(
                    context: context,
                    delegate: TaskSearchDelegate(onUpdate: () {
                      _taskPageKey.currentState?.refresh();
                      _profilePageKey.currentState?.refreshStats();
                    }));
              },
            ),
          // Tambahkan tombol Logout di AppBar jika mau, atau biarkan di Drawer/Profil
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Tidak perlu navigator pop/push karena StreamBuilder di MyApp akan otomatis merender AuthPage
            },
          )
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          // Refresh data saat tab dibuka
          if (index == 3) _profilePageKey.currentState?.refreshStats();
          if (index == 1) _financePageKey.currentState?._loadTransactions();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.task_outlined),
              selectedIcon: Icon(Icons.task),
              label: 'Tugas'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Keuangan'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Kalender'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'To-Do List';
      case 1:
        return 'Keuangan';
      case 2:
        return 'Kalender';
      case 3:
        return 'Profil';
      default:
        return 'To-Do List';
    }
  }
}

// --- SEARCH DELEGATE ---
class TaskSearchDelegate extends SearchDelegate {
  final VoidCallback onUpdate;
  TaskSearchDelegate({required this.onUpdate});

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildList(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    return FutureBuilder<List<Task>>(
      future: DatabaseHelper.instance.getAllTasks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final results = snapshot.data!
            .where((task) =>
                task.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
        if (results.isEmpty)
          return const Center(child: Text("Tidak ditemukan"));
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final task = results[index];
            return ListTile(
              title: Text(task.title),
              subtitle: Text(DateFormat('dd MMM').format(task.dateTime)),
              leading: Icon(task.isCompleted
                  ? Icons.check_circle
                  : Icons.circle_outlined),
              onTap: () async {
                final updated = task.copyWith(isCompleted: !task.isCompleted);
                await DatabaseHelper.instance.updateTask(updated);
                onUpdate();
                close(context, null);
              },
            );
          },
        );
      },
    );
  }
}

// --- DRAWER MENU ---
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Ambil user saat ini dari Firebase
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? "Belum Login";

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration:
                BoxDecoration(color: Theme.of(context).colorScheme.primary),
            accountName: const Text("Pengguna",
                style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(userEmail), // Tampilkan Email Firebase
            currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.grey)),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text("Waktu",
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                _buildFilterItem(context, 'Hari Ini', Icons.today, 'Time'),
                _buildFilterItem(
                    context, 'Minggu Ini', Icons.date_range, 'Time'),
                const Divider(),
                ExpansionTile(
                  leading:
                      const Icon(Icons.category_outlined, color: Colors.blue),
                  title: const Text('Kategori'),
                  initiallyExpanded: true,
                  children: [
                    _buildFilterItem(context, 'Semua', Icons.list, 'Category'),
                    _buildFilterItem(
                        context, 'Kuliah', Icons.school, 'Category'),
                    _buildFilterItem(context, 'Kerja', Icons.work, 'Category'),
                    _buildFilterItem(
                        context, 'Pribadi', Icons.person, 'Category'),
                    _buildFilterItem(
                        context, 'Wishlist', Icons.card_giftcard, 'Category'),
                  ],
                ),
                const Divider(),
                ListTile(
                  leading:
                      const Icon(Icons.palette_outlined, color: Colors.purple),
                  title: const Text('Tema'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (c) => const ThemePage()));
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.settings_outlined, color: Colors.grey),
                  title: const Text('Pengaturan'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => const SettingsPage()));
                  },
                ),
                // Tombol Logout di Drawer
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Keluar (Logout)',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    // StreamBuilder akan otomatis handle redirect
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterItem(
      BuildContext context, String title, IconData icon, String type) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.grey[700]),
      title: Text(title),
      onTap: () {
        filterTypeNotifier.value = type;
        selectedFilterNotifier.value = title;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Menampilkan: $title"),
            duration: const Duration(milliseconds: 500)));
      },
    );
  }
}

// --- TASK LIST PAGE ---
class TaskListPage extends StatefulWidget {
  final VoidCallback? onTaskChanged;
  const TaskListPage({super.key, this.onTaskChanged});
  @override
  State<TaskListPage> createState() => TaskListPageState();
}

class TaskListPageState extends State<TaskListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Task> _tasks = [];
  String _activeFilter = 'Semua';
  String _activeType = 'Category';

  @override
  void initState() {
    super.initState();
    _loadTasks();
    void updateFilter() {
      if (mounted) {
        setState(() {
          _activeType = filterTypeNotifier.value;
          _activeFilter = selectedFilterNotifier.value;
        });
        _loadTasks();
      }
    }

    selectedFilterNotifier.addListener(updateFilter);
    filterTypeNotifier.addListener(updateFilter);
  }

  Future<void> _loadTasks() async {
    List<Task> data;
    if (_activeType == 'Time') {
      if (_activeFilter == 'Hari Ini') {
        data = await _dbHelper.getTasksForToday();
      } else if (_activeFilter == 'Minggu Ini') {
        data = await _dbHelper.getTasksForWeek();
      } else {
        data = await _dbHelper.getAllTasks();
      }
    } else {
      if (_activeFilter == 'Semua') {
        data = await _dbHelper.getAllTasks();
      } else {
        data = await _dbHelper.getTasksByCategory(_activeFilter);
      }
    }
    if (mounted) setState(() => _tasks = data);
  }

  Future<void> _reload() async {
    await _loadTasks();
    widget.onTaskChanged?.call();
  }

  Future<void> _toggleComplete(Task task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await _dbHelper.updateTask(updated);

    if (updated.isCompleted) {
      final prefs = await SharedPreferences.getInstance();
      int total = (prefs.getInt('total_completed_lifetime') ?? 0) + 1;
      await prefs.setInt('total_completed_lifetime', total);
      if ([10, 50, 100, 500].contains(total)) {
        if (mounted) _showAchievementDialog(total);
      }
    }
    _reload();
  }

  void _showAchievementDialog(int total) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text("🎉 PENCAPAIAN BARU!"),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.emoji_events, size: 60, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text("Selamat! Anda telah menyelesaikan $total tugas.",
                      textAlign: TextAlign.center)
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Mantap!"))
                ]));
  }

  Future<void> _toggleStar(Task task) async {
    final updated = task.copyWith(isStarred: !task.isStarred);
    await _dbHelper.updateTask(updated);
    _reload();
  }

  Future<void> _deleteTask(int id) async {
    await _dbHelper.deleteTask(id);
    _reload();
  }

  Future<void> _editTask(Task task) async {
    await _showAddTaskBottomSheet(taskToEdit: task);
  }

  void refresh() {
    _loadTasks();
  }

  Future<void> _showAddTaskBottomSheet({Task? taskToEdit}) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskBottomSheet(taskToEdit: taskToEdit),
    );
    if (result != null) {
      if (taskToEdit != null) {
        final updatedTask = result.copyWith(
            id: taskToEdit.id,
            isCompleted: taskToEdit.isCompleted,
            isStarred: taskToEdit.isStarred,
            priority: result.priority);
        await _dbHelper.updateTask(updatedTask);
      } else {
        await _dbHelper.createTask(result);
      }
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((t) => !t.isCompleted).toList();
    final completed = _tasks.where((t) => t.isCompleted).toList();

    return Scaffold(
      body: Column(
        children: [
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.indigo[50],
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_activeType == 'Time' ? Icons.access_time : Icons.category,
                    size: 16, color: Colors.indigo),
                const SizedBox(width: 8),
                Text("Menampilkan: $_activeFilter",
                    style: const TextStyle(
                        color: Colors.indigo, fontWeight: FontWeight.bold))
              ])),
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Text("Tidak ada tugas di '$_activeFilter'",
                        style: const TextStyle(color: Colors.grey)))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pending.isNotEmpty) ...[
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text("Daftar Tugas",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey))),
                        ...pending.map((t) => _buildSlidableTask(t)),
                      ],
                      if (completed.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ExpansionTile(
                            title: Text("Selesai (${completed.length})"),
                            children: completed
                                .map((t) => _buildSlidableTask(t))
                                .toList()),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddTaskBottomSheet(),
          child: const Icon(Icons.add)),
    );
  }

  Widget _buildSlidableTask(Task task) {
    final dateFormat = DateFormat('dd MMM, HH:mm', 'id_ID');
    Color priorityColor;
    if (task.priority == 2)
      priorityColor = Colors.red;
    else if (task.priority == 0)
      priorityColor = Colors.green;
    else
      priorityColor = Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Slidable(
        key: ValueKey(task.id),
        startActionPane: ActionPane(
            motion: const ScrollMotion(),
            dismissible:
                DismissiblePane(onDismissed: () => _toggleComplete(task)),
            children: [
              SlidableAction(
                  onPressed: (_) => _toggleComplete(task),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  icon: Icons.check,
                  label: 'Selesai',
                  borderRadius: BorderRadius.circular(12))
            ]),
        endActionPane: ActionPane(motion: const ScrollMotion(), children: [
          SlidableAction(
              onPressed: (_) => _toggleStar(task),
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              icon: task.isStarred ? Icons.star : Icons.star_border,
              label: 'Bintang'),
          SlidableAction(
              onPressed: (_) => _showAddTaskBottomSheet(taskToEdit: task),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit'),
          SlidableAction(
              onPressed: (_) => _deleteTask(task.id!),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Hapus',
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(12)))
        ]),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                  left: BorderSide(
                      color: priorityColor == Colors.transparent
                          ? Theme.of(context).primaryColor
                          : priorityColor,
                      width: 4)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ]),
          child: Row(children: [
            InkWell(
                onTap: () => _toggleComplete(task),
                child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: task.isCompleted
                                ? Colors.grey
                                : Theme.of(context).primaryColor,
                            width: 2),
                        color: task.isCompleted
                            ? Colors.grey.withOpacity(0.2)
                            : null),
                    child: task.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.grey)
                        : null)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(task.title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? Colors.grey : null)),
                  const SizedBox(height: 4),
                  Text(dateFormat.format(task.dateTime),
                      style: const TextStyle(fontSize: 12, color: Colors.grey))
                ])),
            if (task.isStarred)
              const Icon(Icons.star, color: Colors.amber, size: 20)
            else
              const Icon(Icons.drag_indicator, color: Colors.grey, size: 16)
          ]),
        ),
      ),
    );
  }
}

// --- FINANCE PAGE (HALAMAN KEUANGAN BARU) ---
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => FinancePageState();
}

class FinancePageState extends State<FinancePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<TransactionModel> _transactions = [];
  double _balance = 0;
  double _income = 0;
  double _expense = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final data = await _dbHelper.getAllTransactions();
    final stats = await _dbHelper.getFinancialSummary();
    if (mounted) {
      setState(() {
        _transactions = data;
        _income = stats['income'] ?? 0;
        _expense = stats['expense'] ?? 0;
        _balance = _income - _expense;
      });
    }
  }

  Future<void> _deleteTransaction(int id) async {
    await _dbHelper.deleteTransaction(id);
    _loadTransactions();
  }

  void _showAddTransactionSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionSheet(),
    );
    if (result == true) {
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      body: Column(
        children: [
          // Header Card (Saldo)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                const Text("Total Saldo",
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(currencyFormat.format(_balance),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.arrow_downward,
                              color: Colors.greenAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Masuk",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(currencyFormat.format(_income),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.arrow_upward,
                              color: Colors.redAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Keluar",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(currencyFormat.format(_expense),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),

          // List Transaksi
          Expanded(
            child: _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("Belum ada transaksi",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final trans = _transactions[index];
                      final isIncome = trans.type == 'Pemasukan';
                      return Dismissible(
                        key: ValueKey(trans.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteTransaction(trans.id!),
                        child: Card(
                          elevation: 0,
                          color: Theme.of(context).cardColor,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isIncome
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward
                                    : (trans.type == 'Transfer'
                                        ? Icons.swap_horiz
                                        : Icons.arrow_upward),
                                color: isIncome
                                    ? Colors.green
                                    : (trans.type == 'Transfer'
                                        ? Colors.orange
                                        : Colors.red),
                              ),
                            ),
                            title: Text(trans.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                "${DateFormat('dd MMM yyyy').format(trans.date)} • ${trans.type}"),
                            trailing: Text(
                              "${isIncome ? '+' : '-'} ${currencyFormat.format(trans.amount)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionSheet,
        icon: const Icon(Icons.add),
        label: const Text("Transaksi"),
      ),
    );
  }
}

// --- ADD TRANSACTION SHEET ---
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'Pengeluaran'; // Default
  DateTime _selectedDate = DateTime.now();

  void _save() async {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) return;

    final amount = double.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;

    final trans = TransactionModel(
      title: _titleController.text,
      amount: amount,
      type: _type,
      date: _selectedDate,
    );

    await DatabaseHelper.instance.createTransaction(trans);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Catat Transaksi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          // Type Selector
          Row(
            children: [
              _buildTypeButton('Pemasukan', Colors.green),
              const SizedBox(width: 10),
              _buildTypeButton('Pengeluaran', Colors.red),
              const SizedBox(width: 10),
              _buildTypeButton('Transfer', Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Nominal (Rp)",
              border: OutlineInputBorder(),
              prefixText: "Rp ",
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: "Keterangan (misal: Makan Siang)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100));
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
              )
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text("SIMPAN TRANSAKSI"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, Color color) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: isSelected ? color : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: color, width: 2) : null),
          child: Text(
            type,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
        ),
      ),
    );
  }
}

// --- PROFILE PAGE (ULTIMATE: STATS + BADGES + CHART + UPCOMING) ---
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  String _userName = "Pengguna";
  String _userBio = "Tulis status atau bio Anda di sini";
  String? _imagePath;

  int _completedCount = 0;
  int _pendingCount = 0;
  List<double> _weeklyStats = [0, 0, 0, 0, 0, 0, 0];
  List<Task> _upcomingTasks = [];
  int _lifetimeCompleted = 0;
  int _dailyGoal = 5;
  int _todayFinished = 0;
  double _dailyProgress = 0.0;

  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    refreshStats();
  }

  Future<void> refreshStats() async {
    final allTasks = await _dbHelper.getAllTasks();
    final financeStats = await _dbHelper.getFinancialSummary();
    final now = DateTime.now();
    int completed = 0;
    int pending = 0;
    int todayCount = 0;
    List<double> weeklyCounts = [0, 0, 0, 0, 0, 0, 0];
    List<Task> upcoming = [];

    // Load Daily Goal dari Settings
    final prefs = await SharedPreferences.getInstance();
    int savedGoal = prefs.getInt('daily_goal_target') ?? 5;

    for (var task in allTasks) {
      if (task.isCompleted) {
        completed++;
        int dayIndex = task.dateTime.weekday % 7;
        weeklyCounts[dayIndex] += 1.0;
        if (task.dateTime.day == now.day &&
            task.dateTime.month == now.month &&
            task.dateTime.year == now.year) {
          todayCount++;
        }
      } else {
        pending++;
        if (task.dateTime.isAfter(now) &&
            task.dateTime.isBefore(now.add(const Duration(days: 7)))) {
          upcoming.add(task);
        }
      }
    }

    int lifetime = prefs.getInt('total_completed_lifetime') ?? 0;
    if (lifetime < completed) {
      lifetime = completed;
      await prefs.setInt('total_completed_lifetime', lifetime);
    }

    if (mounted)
      setState(() {
        _dailyGoal = savedGoal;
        _completedCount = completed;
        _pendingCount = pending;
        _weeklyStats = weeklyCounts;
        _upcomingTasks = upcoming;
        _lifetimeCompleted = lifetime;
        _todayFinished = todayCount;
        _dailyProgress =
            (_dailyGoal > 0) ? (todayCount / _dailyGoal).clamp(0.0, 1.0) : 0.0;

        _totalIncome = financeStats['income'] ?? 0;
        _totalExpense = financeStats['expense'] ?? 0;
      });
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "Pengguna";
      _userBio =
          prefs.getString('user_bio') ?? "Tulis status atau bio Anda di sini";
      _imagePath = prefs.getString('user_image');
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
        context: context,
        builder: (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text("Ambil Foto"),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? photo =
                        await picker.pickImage(source: ImageSource.camera);
                    if (photo != null) _saveImage(photo.path);
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text("Pilih dari Galeri"),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) _saveImage(image.path);
                  })
            ])));
  }

  Future<void> _saveImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_image', path);
    setState(() {
      _imagePath = path;
    });
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _userName);
    final bioController = TextEditingController(text: _userBio);
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text("Edit Profil"),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: "Nama Lengkap",
                          border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(
                      controller: bioController,
                      decoration: const InputDecoration(
                          labelText: "Bio / Status",
                          border: OutlineInputBorder()),
                      maxLines: 2)
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Batal")),
                  ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('user_name', nameController.text);
                        await prefs.setString('user_bio', bioController.text);
                        setState(() {
                          _userName = nameController.text;
                          _userBio = bioController.text;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Simpan"))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    // Gunakan Theme.of(context) untuk warna agar support dark mode
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ]),
                child: Row(children: [
                  Stack(children: [
                    GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _imagePath != null
                                ? FileImage(File(_imagePath!))
                                : null,
                            child: _imagePath == null
                                ? Icon(Icons.person,
                                    size: 40,
                                    color: Theme.of(context).primaryColor)
                                : null)),
                    Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: cardColor, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.grey)))
                  ]),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(_userName,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis)),
                              IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: Colors.grey),
                                  onPressed: _showEditProfileDialog)
                            ]),
                        Text(_userBio,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13))
                      ]))
                ])),
            const SizedBox(height: 24),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: cardColor, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Stack(alignment: Alignment.center, children: [
                    SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                            value: _dailyProgress,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey[100],
                            color: Colors.blueAccent)),
                    Text("${(_dailyProgress * 100).toInt()}%",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))
                  ]),
                  const SizedBox(width: 16),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Target Harian",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("$_todayFinished dari $_dailyGoal tugas selesai",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey))
                      ])
                ])),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: _buildStatBox(
                      "Selesai", "$_completedCount", Colors.green, cardColor)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatBox(
                      "Tertunda", "$_pendingCount", Colors.orange, cardColor))
            ]),
            const SizedBox(height: 24),

            // --- WIDGET LAPORAN KEUANGAN BARU ---
            _buildFinanceReportCard(cardColor),

            const SizedBox(height: 24),

            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Produktivitas Mingguan",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBar(0, 'Min'),
                            _buildBar(1, 'Sen'),
                            _buildBar(2, 'Sel'),
                            _buildBar(3, 'Rab'),
                            _buildBar(4, 'Kam'),
                            _buildBar(5, 'Jum'),
                            _buildBar(6, 'Sab')
                          ])
                    ])),
            const SizedBox(height: 24),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Koleksi Lencana",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Total Skor: $_lifetimeCompleted",
                                style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold))
                          ]),
                      const Divider(height: 24),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildBadge(
                                "Perunggu", Icons.verified, Colors.brown, 10),
                            _buildBadge(
                                "Perak", Icons.military_tech, Colors.grey, 50),
                            _buildBadge(
                                "Emas", Icons.emoji_events, Colors.amber, 100),
                            _buildBadge(
                                "Berlian", Icons.diamond, Colors.blue, 500)
                          ])
                    ])),
            const SizedBox(height: 24),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text("Tugas dalam 7 hari ke depan",
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            if (_upcomingTasks.isEmpty)
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.event_available, size: 16, color: Colors.grey),
                    SizedBox(width: 12),
                    Text("Tidak ada jadwal minggu ini",
                        style: TextStyle(color: Colors.grey))
                  ]))
            else
              ..._upcomingTasks.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(
                        width: 4,
                        height: 30,
                        decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(t.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    Text(DateFormat('dd MMM').format(t.dateTime),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey))
                  ]))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceReportCard(Color cardColor) {
    final balance = _totalIncome - _totalExpense;
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Laporan Keuangan",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Saldo Saat Ini",
                  style: TextStyle(color: Colors.grey)),
              Text(currencyFormat.format(balance),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: balance >= 0 ? Colors.blue : Colors.red)),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Pemasukan",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(currencyFormat.format(_totalIncome),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Pengeluaran",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(currencyFormat.format(_totalExpense),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, Color bgColor) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: Colors.grey))
        ]));
  }

  Widget _buildBar(int index, String label) {
    double count = _weeklyStats[index];
    double height = (count * 10).clamp(5.0, 80.0);
    Color barColor =
        count > 0 ? Theme.of(context).primaryColor : Colors.grey[200]!;
    return Column(children: [
      Container(
          width: 8,
          height: height,
          decoration: BoxDecoration(
              color: barColor, borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))
    ]);
  }

  Widget _buildBadge(String title, IconData icon, Color color, int target) {
    bool unlocked = _lifetimeCompleted >= target;
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: unlocked ? color.withOpacity(0.1) : Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(
                  color: unlocked ? color : Colors.grey[300]!, width: 2)),
          child:
              Icon(icon, size: 24, color: unlocked ? color : Colors.grey[400])),
      const SizedBox(height: 8),
      Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: unlocked ? Colors.black : Colors.grey)),
      if (!unlocked)
        Text("${target - _lifetimeCompleted} lg",
            style: const TextStyle(fontSize: 9, color: Colors.red))
    ]);
  }
}

// --- STANDARD WIDGETS ---
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Task> _tasksForSelectedDate = [];
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadTasksForDate(_selectedDate!);
  }

  Future<void> _loadTasksForDate(DateTime date) async {
    final tasks = await _dbHelper.getTasksByDate(date);
    if (mounted) setState(() => _tasksForSelectedDate = tasks);
  }

  void refreshSelectedDate() {
    if (_selectedDate != null) _loadTasksForDate(_selectedDate!);
  }

  void _previousMonth() => setState(() =>
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
  void _nextMonth() => setState(() =>
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));
  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadTasksForDate(date);
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    List<DateTime> days = [];
    for (int i = 1; i < firstWeekday; i++) days.add(DateTime(0));
    for (int day = 1; day <= lastDay.day; day++)
      days.add(DateTime(_currentMonth.year, _currentMonth.month, day));
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMM, yyyy', 'id_ID');
    final days = _getDaysInMonth();
    final today = DateTime.now();
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(monthFormat.format(_currentMonth),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor)),
              Row(children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth),
                IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextMonth)
              ])
            ]),
            const SizedBox(height: 16),
            GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, childAspectRatio: 1),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final date = days[index];
                  if (date.year == 0) return const SizedBox.shrink();
                  final isSelected = _selectedDate != null &&
                      date.year == _selectedDate!.year &&
                      date.month == _selectedDate!.month &&
                      date.day == _selectedDate!.day;
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  return GestureDetector(
                      onTap: () => _selectDate(date),
                      child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: isToday && !isSelected
                                  ? Border.all(
                                      color: Theme.of(context).primaryColor)
                                  : null),
                          child: Center(
                              child: Text('${date.day}',
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: isSelected || isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal)))));
                }),
            const SizedBox(height: 24),
            Text(
                "Jadwal ${_selectedDate != null ? DateFormat('dd MMM').format(_selectedDate!) : ''}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_tasksForSelectedDate.isEmpty)
              const Text("Tidak ada jadwal",
                  style: TextStyle(color: Colors.grey))
            else
              ..._tasksForSelectedDate.map((task) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                          left: BorderSide(
                              color: Theme.of(context).primaryColor, width: 4)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1), blurRadius: 4)
                      ]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(DateFormat('HH:mm').format(task.dateTime),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12))
                      ])))
          ],
        ));
  }
}

class AddTaskBottomSheet extends StatefulWidget {
  final Task? taskToEdit;
  const AddTaskBottomSheet({super.key, this.taskToEdit});
  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Kuliah';
  int _selectedPriority = 1;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<String> _categories = ['Kuliah', 'Personal', 'Kerja', 'Wishlist'];
  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _descController.text = t.desc;
      _selectedCategory =
          _categories.contains(t.category) ? t.category : _categories[0];
      _selectedPriority = t.priority;
      _selectedDate = t.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(t.dateTime);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked =
        await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final dateTime = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
      final task = Task(
          title: _titleController.text.trim(),
          desc: _descController.text.trim(),
          category: _selectedCategory,
          dateTime: dateTime,
          priority: _selectedPriority);
      Navigator.pop(context, task);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Form(
            key: _formKey,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.taskToEdit == null ? "Tambah Tugas" : "Edit Tugas",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Judul Tugas'),
                  validator: (v) => v!.isEmpty ? 'Isi judul' : null),
              const SizedBox(height: 10),
              TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Deskripsi')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField(
                        value: _selectedCategory,
                        decoration:
                            const InputDecoration(labelText: 'Kategori'),
                        items: _categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategory = v!))),
                const SizedBox(width: 12),
                Expanded(
                    child: DropdownButtonFormField(
                        value: _selectedPriority,
                        decoration:
                            const InputDecoration(labelText: 'Prioritas'),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text("Rendah")),
                          DropdownMenuItem(value: 1, child: Text("Sedang")),
                          DropdownMenuItem(value: 2, child: Text("Tinggi"))
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedPriority = v!)))
              ]),
              Row(children: [
                TextButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('dd MMM').format(_selectedDate))),
                TextButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)))
              ]),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50)),
                  child: const Text("SIMPAN")),
              const SizedBox(height: 20)
            ]))));
  }
}

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});
  final List<Color> colors = const [
    Colors.indigo,
    Colors.teal,
    Colors.pink,
    Colors.orange,
    Colors.blueGrey,
    Colors.purple
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Pilih Tema")),
        body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: colors.length,
            itemBuilder: (ctx, i) => InkWell(
                onTap: () async {
                  appThemeColor.value = colors[i];
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('theme_color', colors[i].value);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(color: colors[i]))));
  }
}

// --- SETTINGS PAGE (NEW COMPLETE VERSION) ---
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Notifikasi
  bool _notifEnabled = true;
  String _defaultReminder = '30 menit';
  bool _repeatReminder = false;

  // Waktu
  String _timeFormat = '24 jam';
  String _startWeek = 'Senin';

  // Tampilan
  String _darkMode = 'System';
  String _textSize = 'Normal';

  // Produktivitas
  bool _dailyGoalEnabled = true;
  double _targetGoal = 5.0; // Pakai double untuk Slider
  String _autoArchive = 'Off';

  // Data
  bool _confirmDelete = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      _defaultReminder = prefs.getString('default_reminder') ?? '30 menit';
      _repeatReminder = prefs.getBool('repeat_reminder') ?? false;

      _timeFormat = prefs.getString('time_format') ?? '24 jam';
      _startWeek = prefs.getString('start_week') ?? 'Senin';

      _darkMode = prefs.getString('theme_mode') ?? 'System';
      _textSize = prefs.getString('text_size') ?? 'Normal';

      _dailyGoalEnabled = prefs.getBool('daily_goal_enabled') ?? true;
      _targetGoal = (prefs.getInt('daily_goal_target') ?? 5).toDouble();
      _autoArchive = prefs.getString('auto_archive') ?? 'Off';

      _confirmDelete = prefs.getBool('confirm_delete') ?? true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  // --- LOGIC HAPUS DATA ---
  Future<void> _deleteAllData() async {
    await DatabaseHelper.instance.deleteAllTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Semua data berhasil dihapus"),
          backgroundColor: Colors.red));
      Navigator.pop(context);
    }
  }

  void _onDeletePressed() {
    if (_confirmDelete) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text("Hapus Semua Data?"),
                  content: const Text("Tindakan ini tidak bisa dibatalkan."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Batal")),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteAllData();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        child: const Text("Hapus"))
                  ]));
    } else {
      _deleteAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan")),
      body: ListView(
        children: [
          // 🔔 NOTIFIKASI
          _buildHeader("Notifikasi", Icons.notifications_outlined),
          SwitchListTile(
            title: const Text("Aktifkan Notifikasi"),
            value: _notifEnabled,
            onChanged: (v) {
              setState(() => _notifEnabled = v);
              _saveBool('notif_enabled', v);
            },
          ),
          ListTile(
            title: const Text("Waktu Pengingat Default"),
            subtitle: Text(_defaultReminder),
            trailing: _buildDropdown(
                _defaultReminder, ['10 menit', '30 menit', '1 jam'], (v) {
              setState(() => _defaultReminder = v!);
              _saveString('default_reminder', v!);
            }),
          ),
          SwitchListTile(
            title: const Text("Reminder Ulang"),
            subtitle: const Text("Ingatkan lagi jika deadline terlewat"),
            value: _repeatReminder,
            onChanged: (v) {
              setState(() => _repeatReminder = v);
              _saveBool('repeat_reminder', v);
            },
          ),

          const Divider(),

          // ⏰ WAKTU & TANGGAL
          _buildHeader("Waktu & Tanggal", Icons.access_time),
          ListTile(
            title: const Text("Format Waktu"),
            trailing: _buildDropdown(_timeFormat, ['12 jam', '24 jam'], (v) {
              setState(() => _timeFormat = v!);
              _saveString('time_format', v!);
            }),
          ),
          ListTile(
            title: const Text("Hari Pertama Minggu"),
            trailing: _buildDropdown(_startWeek, ['Senin', 'Minggu'], (v) {
              setState(() => _startWeek = v!);
              _saveString('start_week', v!);
            }),
          ),

          const Divider(),

          // 🎨 TAMPILAN
          _buildHeader("Tampilan", Icons.palette_outlined),
          ListTile(
            title: const Text("Dark Mode"),
            trailing:
                _buildDropdown(_darkMode, ['System', 'Light', 'Dark'], (v) {
              setState(() => _darkMode = v!);
              _saveString('theme_mode', v!);
              // Update Global
              if (v == 'Dark')
                appThemeMode.value = ThemeMode.dark;
              else if (v == 'Light')
                appThemeMode.value = ThemeMode.light;
              else
                appThemeMode.value = ThemeMode.system;
            }),
          ),
          ListTile(
            title: const Text("Ukuran Teks"),
            trailing:
                _buildDropdown(_textSize, ['Kecil', 'Normal', 'Besar'], (v) {
              setState(() => _textSize = v!);
              _saveString('text_size', v!);
              // Update Global
              if (v == 'Kecil')
                appTextScale.value = 0.85;
              else if (v == 'Besar')
                appTextScale.value = 1.15;
              else
                appTextScale.value = 1.0;
            }),
          ),

          const Divider(),

          // 🎯 PRODUKTIVITAS
          _buildHeader("Produktivitas", Icons.track_changes),
          SwitchListTile(
            title: const Text("Daily Goal"),
            value: _dailyGoalEnabled,
            onChanged: (v) {
              setState(() => _dailyGoalEnabled = v);
              _saveBool('daily_goal_enabled', v);
            },
          ),
          if (_dailyGoalEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Target: ${_targetGoal.toInt()} tugas",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _targetGoal,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: _targetGoal.toInt().toString(),
                    onChanged: (v) {
                      setState(() => _targetGoal = v);
                      _saveInt('daily_goal_target', v.toInt());
                    },
                  ),
                ],
              ),
            ),
          ListTile(
            title: const Text("Auto Archive Tugas Selesai"),
            trailing:
                _buildDropdown(_autoArchive, ['Off', '7 hari', '30 hari'], (v) {
              setState(() => _autoArchive = v!);
              _saveString('auto_archive', v!);
            }),
          ),

          const Divider(),

          // 🗂️ DATA
          _buildHeader("Data", Icons.storage),
          SwitchListTile(
            title: const Text("Konfirmasi Hapus"),
            subtitle: const Text("Tanya sebelum hapus semua data"),
            value: _confirmDelete,
            onChanged: (v) {
              setState(() => _confirmDelete = v);
              _saveBool('confirm_delete', v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Hapus Semua Data",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _onDeletePressed,
          ),

          const Divider(),

          // ℹ️ TENTANG
          _buildHeader("Tentang", Icons.info_outline),
          const ListTile(
            title: Text("Versi Aplikasi"),
            subtitle: Text("1.2.0 (Build 2025)"),
          ),
          ListTile(
            title: const Text("Kontak Developer"),
            subtitle: const Text("laporkan bug atau saran"),
            trailing: const Icon(Icons.mail_outline),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Email: support@todolistapp.com")));
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS HELPER ---
  Widget _buildHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDropdown(
      String currentVal, List<String> items, Function(String?) onChanged) {
    return DropdownButton<String>(
      value: currentVal,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
      underline: const SizedBox(),
    );
  }
}

class WidgetPage extends StatelessWidget {
  const WidgetPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Widget")),
        body: const Center(child: Text("Galeri Widget")));
  }
}
