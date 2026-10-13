
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;

  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  late Database _db;

  Database get database => _db;

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = join(directory.path, _databaseName);

    _db = await openDatabase(
      dbPath,
      version: _databaseVersion,

      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (db, version) async {
        await _createGuestTable(db);
        await _createCatalogueTables(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCatalogueTables(db);
        }
      },
    );
  }

  Future<void> _createGuestTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createCatalogueTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id)
          REFERENCES folders(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cards_folder_id
      ON cards(folder_id)
    ''');
  }

  // PART I GUEST ROSTER METHODS

  Future<int> insert(Map<String, dynamic> row) async {
    return _db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return _db.query(
      table,
      orderBy: '$columnId ASC',
    );
  }

  Future<int> queryRowCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM $table',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> update(Map<String, dynamic> row) async {
    final id = row[columnId] as int;

    return _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    return _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // DATABASE DIAGNOSTICS

  Future<Map<String, Object?>> diagnostics() async {
    final version = await _db.rawQuery(
      'PRAGMA user_version',
    );

    final foreignKeys = await _db.rawQuery(
      'PRAGMA foreign_keys',
    );

    final foreignKeyList = await _db.rawQuery(
      'PRAGMA foreign_key_list(cards)',
    );

    final indexes = await _db.rawQuery(
      'PRAGMA index_list(cards)',
    );

    final guests = await queryAllRows();

    return {
      'user_version': version.first,
      'foreign_keys': foreignKeys.first,
      'foreign_key_list': foreignKeyList,
      'indexes': indexes,
      'guests': guests,
    };
  }
}
