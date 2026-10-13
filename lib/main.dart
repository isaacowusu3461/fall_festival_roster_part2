
import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'catalogue_repository.dart';
import 'catalogue_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();

    // Print database information to verify the Part II migration.
    final diagnostics = await helper.diagnostics();
    debugPrint('Database diagnostics: $diagnostics');

    runApp(DirectoryApp(helper: helper));
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not open local storage.\n'
                'Check the debug console for details.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Main application
class DirectoryApp extends StatelessWidget {
  const DirectoryApp({
    super.key,
    required this.helper,
  });

  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local Storage Part II',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Local Storage Part II'),
        ),
        body: Center(
          child: Builder(
            builder: (context) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CatalogueScreen(
                            repository: CatalogueRepository(helper),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder),
                    label: const Text('Open Card Catalogue'),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RosterScreen(helper: helper),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people),
                    label: const Text('Open Part I Guest Roster'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Part I Guest Roster
class RosterScreen extends StatefulWidget {
  const RosterScreen({
    super.key,
    required this.helper,
  });

  final DatabaseHelper helper;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];

  int _rowCount = 0;
  int? _editingId;

  bool _loading = true;
  bool _busy = false;

  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  Future<void> _loadRows() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _rowCount = count;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Failed to load guest records: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = 'Unable to load guest records.';
        _loading = false;
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    _ageController.clear();
    _editingId = null;
  }

  void _startEdit(Map<String, dynamic> row) {
    if (_busy) return;

    setState(() {
      _editingId = row[DatabaseHelper.columnId] as int;
      _nameController.text =
          row[DatabaseHelper.columnName].toString();
      _ageController.text =
          row[DatabaseHelper.columnAge].toString();
      _message = null;
    });
  }

  void _cancelEdit() {
    if (_busy) return;

    setState(() {
      _clearForm();
      _message = 'Edit canceled. No changes were saved.';
    });
  }

  Future<void> _saveRecord() async {
    if (_busy) return;

    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);

    if (name.isEmpty) {
      setState(() {
        _message = 'Name cannot be blank.';
      });
      return;
    }

    if (age == null || age < 0 || age > 130) {
      setState(() {
        _message = 'Age must be a whole number from 0 to 130.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final row = <String, dynamic>{
        DatabaseHelper.columnName: name,
        DatabaseHelper.columnAge: age,
      };

      String resultMessage;

      if (_editingId == null) {
        final id = await widget.helper.insert(row);
        resultMessage = 'Guest added with ID $id.';
      } else {
        final id = _editingId!;

        row[DatabaseHelper.columnId] = id;

        final affected = await widget.helper.update(row);

        resultMessage = affected == 1
            ? 'Guest ID $id updated successfully.'
            : 'Guest ID $id was not found. No row updated.';
      }

      if (!mounted) return;

      setState(() {
        _clearForm();
        _message = resultMessage;
      });

      await _loadRows();
    } catch (e, stackTrace) {
      debugPrint('Failed to save guest: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _message = 'Unable to save guest. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> row) async {
    if (_busy) return;

    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName].toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete guest?'),
          content: Text(
            'Are you sure you want to delete $name (ID $id)?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmed != true) {
      setState(() {
        _message = 'Delete canceled. No changes were made.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final affected = await widget.helper.delete(id);

      if (!mounted) return;

      setState(() {
        _message = affected == 1
            ? 'Guest ID $id deleted successfully.'
            : 'Guest ID $id was not found.';
      });

      await _loadRows();
    } catch (e, stackTrace) {
      debugPrint('Failed to delete guest: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _message = 'Unable to delete guest.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _loadRows,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Guest name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ageController,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _saveRecord,
                    child: Text(
                      _editingId == null ? 'Add Guest' : 'Save Changes',
                    ),
                  ),
                ),
                if (_editingId != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Records: $_rowCount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _loadRows,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null
                      ? Center(
                          child: Text(_error!),
                        )
                      : _rows.isEmpty
                          ? const Center(
                              child: Text('No guests saved yet.'),
                            )
                          : ListView.builder(
                              itemCount: _rows.length,
                              itemBuilder: (context, index) {
                                final row = _rows[index];

                                final id =
                                    row[DatabaseHelper.columnId] as int;
                                final name =
                                    row[DatabaseHelper.columnName].toString();
                                final age =
                                    row[DatabaseHelper.columnAge].toString();

                                return Card(
                                  child: ListTile(
                                    title: Text(name),
                                    subtitle: Text(
                                      'ID: $id | Age: $age',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          onPressed: _busy
                                              ? null
                                              : () => _startEdit(row),
                                          icon: const Icon(Icons.edit),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          onPressed: _busy
                                              ? null
                                              : () => _deleteRecord(row),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
