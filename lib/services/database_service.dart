import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
      // v5 = categorias + dueDate + sensores/câmera/GPS + id INTEGER
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // ---------- Tabela de categorias (mantida do seu projeto) ----------
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorHex INTEGER NOT NULL
      )
    ''');

    // ---------- Tabela de tarefas (versão final com todos os campos) ----------
    // id INTEGER AUTOINCREMENT (pedido do professor)
    // mantém: dueDate, categoryId (seu projeto)
    // adiciona: photoPath, completedAt, completedBy, latitude, longitude, locationName
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        categoryId TEXT,
        photoPath TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories(id)
      )
    ''');

    // Índices úteis
    await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_createdAt ON tasks(createdAt)");
    await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)");

    // Semente de categorias padrão
    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrações incrementais (compatível com seu histórico + pedido do professor)

    // v2: índices básicos (se vier de um schema muito antigo)
    if (oldVersion < 2) {
      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_createdAt ON tasks(createdAt)");
    }

    // v3: categorias + dueDate/categoryId (seu projeto)
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          colorHex INTEGER NOT NULL
        )
      ''');
      // Pode falhar se colunas já existirem; ignore erros simples
      try { await db.execute("ALTER TABLE tasks ADD COLUMN dueDate TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE tasks ADD COLUMN categoryId TEXT"); } catch (_) {}
      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)");
      await _seedDefaultCategories(db);
    }

    // v4: campos de sensores/câmera/GPS (pedido do professor)
    if (oldVersion < 4) {
      try { await db.execute("ALTER TABLE tasks ADD COLUMN photoPath TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE tasks ADD COLUMN completedAt TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE tasks ADD COLUMN completedBy TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE tasks ADD COLUMN latitude REAL"); } catch (_) {}
      try { await db.execute("ALTER TABLE tasks ADD COLUMN longitude REAL"); } catch (_) {}
      try { await db.execute("ALTER TABLE tasks ADD COLUMN locationName TEXT"); } catch (_) {}
    }

    // v5: mudança crítica — id de TEXT para INTEGER AUTOINCREMENT
    // Estratégia DEV: recriar a tabela tasks (perde IDs antigos).
    // Se quiser preservar dados, me avise que mando migração com tabela temporária.
    if (oldVersion < 5) {
      await db.execute('PRAGMA foreign_keys = OFF');

      // Renomeia tabela antiga
      await db.execute('ALTER TABLE tasks RENAME TO tasks_old');

      // Cria nova tabela com id INTEGER AUTOINCREMENT e todos os campos
      await db.execute('''
        CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          priority TEXT NOT NULL,
          completed INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          dueDate TEXT,
          categoryId TEXT,
          photoPath TEXT,
          completedAt TEXT,
          completedBy TEXT,
          latitude REAL,
          longitude REAL,
          locationName TEXT,
          FOREIGN KEY (categoryId) REFERENCES categories(id)
        )
      ''');

      // Copia dados compatíveis (id novo será gerado ao reinserir)
      final oldRows = await db.query('tasks_old');
      for (final row in oldRows) {
        final map = Map<String, Object?>.from(row);
        map.remove('id'); // deixa o SQLite gerar novo id
        await db.insert('tasks', map);
      }

      // Remove a antiga e recria índices
      await db.execute('DROP TABLE tasks_old');
      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_createdAt ON tasks(createdAt)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)");

      await db.execute('PRAGMA foreign_keys = ON');
    }

    // Log útil
    // ignore: avoid_print
    print('✅ Banco migrado de v$oldVersion para v$newVersion');
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );
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
    final db = await instance.database;
    // deixa o SQLite gerar o id
    final generatedId = await db.insert('tasks', task.toMap()..remove('id'));
    return task.copyWith(id: generatedId);
  }

  Future<Task?> read(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) return Task.fromMap(maps.first);
    return null;
  }

  // Ordena por vencimento (mais próximos primeiro), nulos por último; depois por createdAt desc
  Future<List<Task>> readAll() async {
    final db = await instance.database;
    const orderBy = 'dueDate IS NULL, dueDate ASC, createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> update(Task task) async {
    final db = await instance.database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------------------ Categorias ------------------

  Future<Category> createCategory(Category c) async {
    final db = await instance.database;
    await db.insert('categories', c.toMap());
    return c;
  }

  Future<List<Category>> readAllCategories() async {
    final db = await instance.database;
    final res = await db.query('categories', orderBy: 'name ASC');
    return res.map((m) => Category.fromMap(m)).toList();
  }

  // ------- Método especial: tarefas perto de uma localização -------
  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final allTasks = await readAll();

    // Simplificação: distância aproximada (não usa Haversine completo)
    return allTasks.where((task) {
      if (!task.hasLocation) return false;

      final latDiff = (task.latitude! - latitude).abs();
      final lonDiff = (task.longitude! - longitude).abs();
      // 1 grau ~ 111km → 111000m
      final distance = ((latDiff * 111000) + (lonDiff * 111000)) / 2;

      return distance <= radiusInMeters;
    }).toList();
  }

  Future close() async {
    final db = await instance.database;
    await db.close();
  }
}
