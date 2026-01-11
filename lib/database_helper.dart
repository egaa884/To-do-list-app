import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'task_model.dart';
import 'transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Ubah nama DB jika perlu, atau biarkan sama tapi naikkan version
    _database = await _initDB('todo_app_ultimate_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Naikkan version ke 2 untuk memicu onUpgrade jika db lama sudah ada
    return await openDatabase(path,
        version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    // Tabel Tasks (Lama)
    await db.execute('''
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      desc TEXT,
      category TEXT,
      dateTime TEXT,
      isCompleted INTEGER,
      isStarred INTEGER,
      priority INTEGER
    )
    ''');

    // Tabel Transactions (Baru)
    await _createTransactionTable(db);
  }

  // Handle jika user update aplikasi
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTransactionTable(db);
    }
  }

  Future _createTransactionTable(Database db) async {
    await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      amount REAL,
      type TEXT,
      date TEXT,
      description TEXT
    )
    ''');
  }

  // --- CRUD TASKS (Kode Lama Tetap Sama) ---
  Future<int> createTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final maps =
        await db.query('tasks', orderBy: 'priority DESC, dateTime ASC');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<List<Task>> getTasksByCategory(String category) async {
    final db = await database;
    final maps = await db.query('tasks',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'priority DESC, dateTime ASC');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<List<Task>> getTasksForToday() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final maps = await db.query('tasks',
        where: 'dateTime BETWEEN ? AND ?',
        whereArgs: [start, end],
        orderBy: 'priority DESC, dateTime ASC');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<List<Task>> getTasksForWeek() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = now.add(const Duration(days: 7)).toIso8601String();
    final maps = await db.query('tasks',
        where: 'dateTime BETWEEN ? AND ?',
        whereArgs: [start, end],
        orderBy: 'priority DESC, dateTime ASC');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end =
        DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final maps = await db.query('tasks',
        where: 'dateTime BETWEEN ? AND ?',
        whereArgs: [start, end],
        orderBy: 'priority DESC, dateTime ASC');
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db
        .update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllTasks() async {
    final db = await database;
    await db.delete('tasks');
  }

  // --- CRUD TRANSACTIONS (Fitur Baru) ---

  Future<int> createTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Helper untuk mendapatkan Total Pemasukan & Pengeluaran
  Future<Map<String, double>> getFinancialSummary() async {
    final db = await database;
    final result = await db.query('transactions');
    double income = 0;
    double expense = 0;

    for (var map in result) {
      double amount = map['amount'] as double;
      String type = map['type'] as String;

      if (type == 'Pemasukan') {
        income += amount;
      } else {
        // Pengeluaran & Transfer dianggap mengurangi saldo
        expense += amount;
      }
    }
    return {'income': income, 'expense': expense};
  }
}
