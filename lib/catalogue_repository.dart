import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'models/catalogue_models.dart';

class CatalogueRepository {
  CatalogueRepository(this.helper);
  final DatabaseHelper helper;
  Database get db => helper.database;

  Future<List<FolderRecord>> getFoldersWithCounts() async {
    final rows = await db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders f LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.id ASC
    ''');
    return rows.map(FolderRecord.fromMap).toList();
  }

  Future<int> insertFolder(String name) => db.insert('folders', {
    'name': name, 'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  Future<int> deleteFolder(int id) => db.delete(
    'folders', where: 'id = ?', whereArgs: [id]);

  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await db.query('cards', where: 'folder_id = ?',
      whereArgs: [folderId], orderBy: 'title COLLATE NOCASE ASC, id ASC');
    return rows.map(CardRecord.fromMap).toList();
  }

  Future<int> insertCard(CardRecord card) {
    final values = card.toMap()..remove('id');
    return db.insert('cards', values);
  }

  Future<int> updateCard(CardRecord card) {
    final values = card.toMap()..remove('id');
    return db.update('cards', values, where: 'id = ?', whereArgs: [card.id]);
  }

  Future<int> deleteCard(int id) => db.delete(
    'cards', where: 'id = ?', whereArgs: [id]);
}