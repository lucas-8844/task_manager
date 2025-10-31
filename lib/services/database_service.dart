import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,                 // ⬅️ ATUALIZEI A VERSÃO DO DB
      onCreate: _createDB,
      onUpgrade: _onUpgrade,      // ⬅️ MIGRAÇÃO
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabela de categorias
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorHex INTEGER NOT NULL
      )
    ''');

    // Tabela de tarefas
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT,                -- ⬅️ NOVO
        categoryId TEXT,             -- ⬅️ NOVO
        FOREIGN KEY (categoryId) REFERENCES categories(id)
      )
    ''');

    // Índices úteis
    await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_createdAt ON tasks(createdAt)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)");

    // Seed de categorias padrão
    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_createdAt ON tasks(createdAt)");
    }
    if (oldV < 3) {
      // Criar tabela de categorias se ainda não existir
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          colorHex INTEGER NOT NULL
        )
      ''');

      // Adicionar colunas novas em tasks (idempotente)
      await db.execute("ALTER TABLE tasks ADD COLUMN dueDate TEXT");
      await db.execute("ALTER TABLE tasks ADD COLUMN categoryId TEXT");

      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)");
      await _seedDefaultCategories(db);
    }
  }

  Future<void> _seedDefaultCategories(Database db) async {
    // Insere categorias padrões se a tabela estiver vazia
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM categories'));
    if ((count ?? 0) == 0) {
      final defaults = [
        Category(name: 'Pessoal',  colorHex: 0xFF64B5F6),
        Category(name: 'Trabalho', colorHex: 0xFFFFB74D),
        Category(name: 'Estudos',  colorHex: 0xFF81C784),
      ];
      for (final c in defaults) {
        await db.insert('categories', c.toMap());
      }
    }
  }

  // ------------------ CRUD Tasks ------------------

  Future<Task> create(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap());
    return task;
  }

  Future<Task?> read(String id) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Task.fromMap(maps.first);
    return null;
  }

  // Ordena por vencimento (mais próximos primeiro), nulos por último; depois por createdAt desc
  Future<List<Task>> readAll() async {
    final db = await database;
    // truque p/ colocar NULLs por último: (dueDate IS NULL), dueDate ASC
    const orderBy = 'dueDate IS NULL, dueDate ASC, createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((m) => Task.fromMap(m)).toList();
  }

  Future<int> update(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------ Categorias ------------------

  Future<Category> createCategory(Category c) async {
    final db = await database;
    await db.insert('categories', c.toMap());
    return c;
  }

  Future<List<Category>> readAllCategories() async {
    final db = await database;
    final res = await db.query('categories', orderBy: 'name ASC');
    return res.map((m) => Category.fromMap(m)).toList();
  }
}
