
import 'package:flutter/material.dart';

import 'catalogue_repository.dart';
import 'models/catalogue_models.dart';

// FOLDER SCREEN

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({
    super.key,
    required this.repository,
  });

  final CatalogueRepository repository;

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  List<FolderRecord> folders = [];

  bool loading = true;
  bool busy = false;

  String? error;
  String? feedback;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await widget.repository.getFoldersWithCounts();

      if (!mounted) return;

      setState(() {
        folders = result;
        loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Folder read failed: $e\n$stackTrace');

      if (!mounted) return;

      setState(() {
        error = 'Unable to load folders. Tap Refresh.';
        loading = false;
      });
    }
  }

  Future<void> createFolder() async {
    if (busy) return;

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String folderName = '';

        return AlertDialog(
          title: const Text('New folder'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              folderName = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, folderName);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (!mounted || name == null) return;

    if (name.trim().isEmpty) {
      setState(() {
        feedback = 'Folder name cannot be blank.';
      });
      return;
    }

    setState(() {
      busy = true;
      feedback = null;
    });

    try {
      final id = await widget.repository.insertFolder(name.trim());

      if (!mounted) return;

      setState(() {
        feedback = 'Created folder ID $id.';
      });

      await load();
    } catch (e, stackTrace) {
      debugPrint('Folder insert failed: $e\n$stackTrace');

      if (mounted) {
        setState(() {
          feedback =
              'Could not create folder. The name may already exist.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> deleteFolder(FolderRecord folder) async {
    if (busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete ${folder.name}?'),
          content: Text(
            'This will also delete its ${folder.cardCount} cards.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || busy) return;

    setState(() {
      busy = true;
      feedback = null;
    });

    try {
      final affected =
          await widget.repository.deleteFolder(folder.id);

      if (!mounted) return;

      setState(() {
        feedback = affected == 1
            ? 'Deleted folder ID ${folder.id} (1 row).'
            : 'Folder no longer exists (0 rows).';
      });

      await load();
    } catch (e, stackTrace) {
      debugPrint('Folder delete failed: $e\n$stackTrace');

      if (mounted) {
        setState(() {
          feedback = 'Could not delete folder. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Catalogue'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : createFolder,
        icon: const Icon(Icons.create_new_folder),
        label: const Text('New folder'),
      ),
      body: Column(
        children: [
          if (feedback != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(feedback!),
            ),

          if (busy) const LinearProgressIndicator(),

          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : error != null
                    ? Center(
                        child: Text(error!),
                      )
                    : folders.isEmpty
                        ? const Center(
                            child: Text(
                              'No folders yet. Create one to begin.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: folders.length,
                            itemBuilder: (context, index) {
                              final folder = folders[index];

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.folder),
                                  title: Text(
                                    '${folder.name} (ID ${folder.id})',
                                  ),
                                  subtitle: Text(
                                    '${folder.cardCount} cards',
                                  ),
                                  onTap: busy
                                      ? null
                                      : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CardsScreen(
                                                repository:
                                                    widget.repository,
                                                folder: folder,
                                              ),
                                            ),
                                          );

                                          if (mounted) {
                                            await load();
                                          }
                                        },
                                  trailing: IconButton(
                                    tooltip: 'Delete folder',
                                    onPressed: busy
                                        ? null
                                        : () => deleteFolder(folder),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// CARDS SCREEN

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.repository,
    required this.folder,
  });

  final CatalogueRepository repository;
  final FolderRecord folder;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<CardRecord> cards = [];

  bool loading = true;
  bool busy = false;

  String? error;
  String? feedback;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result =
          await widget.repository.getCards(widget.folder.id);

      if (!mounted) return;

      setState(() {
        cards = result;
        loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Card read failed: $e\n$stackTrace');

      if (!mounted) return;

      setState(() {
        error = 'Unable to load cards. Tap Refresh.';
        loading = false;
      });
    }
  }

  Future<void> editCard([CardRecord? original]) async {
    if (busy) return;

    final card = await showDialog<CardRecord>(
      context: context,
      builder: (dialogContext) {
        return CardEditor(
          original: original,
          folderId: widget.folder.id,
        );
      },
    );

    if (!mounted || card == null) return;

    setState(() {
      busy = true;
      feedback = null;
    });

    try {
      final result = original == null
          ? await widget.repository.insertCard(card)
          : await widget.repository.updateCard(card);

      if (!mounted) return;

      setState(() {
        if (original == null) {
          feedback = 'Inserted card ID $result.';
        } else if (result == 1) {
          feedback = 'Updated card ID ${card.id} (1 row).';
        } else {
          feedback = 'Card no longer exists (0 rows).';
        }
      });

      await load();
    } catch (e, stackTrace) {
      debugPrint('Card save failed: $e\n$stackTrace');

      if (mounted) {
        setState(() {
          feedback = 'Card save failed. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> deleteCard(CardRecord card) async {
    if (busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete ${card.title}?'),
          content: Text(
            'Card ID ${card.id} will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || busy) return;

    setState(() {
      busy = true;
      feedback = null;
    });

    try {
      final affected =
          await widget.repository.deleteCard(card.id);

      if (!mounted) return;

      setState(() {
        feedback = affected == 1
            ? 'Deleted card ID ${card.id} (1 row).'
            : 'Card no longer exists (0 rows).';
      });

      await load();
    } catch (e, stackTrace) {
      debugPrint('Card delete failed: $e\n$stackTrace');

      if (mounted) {
        setState(() {
          feedback = 'Card delete failed.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  String suitSymbol(String suit) {
    switch (suit) {
      case 'Hearts':
        return '♥';
      case 'Diamonds':
        return '♦';
      case 'Clubs':
        return '♣';
      case 'Spades':
        return '♠';
      default:
        return '♠';
    }
  }

  Widget artwork(CardRecord card) {
    final ref = card.imageRef;

    final fallback = SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Text(
          suitSymbol(card.suit),
          style: const TextStyle(fontSize: 34),
        ),
      ),
    );

    if (ref == null || ref.trim().isEmpty) {
      return fallback;
    }

    final uri = Uri.tryParse(ref);

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return fallback;
    }

    return Image.network(
      ref,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return fallback;
      },
      loadingBuilder: (context, child, progress) {
        return progress == null ? child : fallback;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => editCard(),
        icon: const Icon(Icons.add),
        label: const Text('Add card'),
      ),
      body: Column(
        children: [
          if (feedback != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(feedback!),
            ),

          if (busy) const LinearProgressIndicator(),

          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : error != null
                    ? Center(
                        child: Text(error!),
                      )
                    : cards.isEmpty
                        ? const Center(
                            child: Text(
                              'This folder has no cards.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: cards.length,
                            itemBuilder: (context, index) {
                              final card = cards[index];

                              return Card(
                                child: ListTile(
                                  leading: artwork(card),
                                  title: Text(
                                    '${card.title} (ID ${card.id})',
                                  ),
                                  subtitle: Text(
                                    '${card.suit}'
                                    '${card.notes.isEmpty ? '' : ' • ${card.notes}'}',
                                  ),
                                  onTap: busy
                                      ? null
                                      : () => editCard(card),
                                  trailing: IconButton(
                                    tooltip: 'Delete card',
                                    onPressed: busy
                                        ? null
                                        : () => deleteCard(card),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ADD / EDIT CARD FORM

class CardEditor extends StatefulWidget {
  const CardEditor({
    super.key,
    this.original,
    required this.folderId,
  });

  final CardRecord? original;
  final int folderId;

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _imageController;

  late String _suit;

  static const List<String> suits = [
    'Hearts',
    'Diamonds',
    'Clubs',
    'Spades',
  ];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.original?.title ?? '',
    );

    _notesController = TextEditingController(
      text: widget.original?.notes ?? '',
    );

    _imageController = TextEditingController(
      text: widget.original?.imageRef ?? '',
    );

    _suit = widget.original?.suit ?? 'Hearts';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final imageRef = _imageController.text.trim();

    final card = CardRecord(
      id: widget.original?.id ?? 0,
      title: _titleController.text.trim(),
      suit: _suit,
      folderId: widget.folderId,
      notes: _notesController.text.trim(),
      imageRef: imageRef.isEmpty ? null : imageRef,
    );

    Navigator.pop(context, card);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.original == null
            ? 'Add card'
            : 'Edit card ID ${widget.original!.id}',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title cannot be blank';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _suit,
                decoration: const InputDecoration(
                  labelText: 'Suit',
                  border: OutlineInputBorder(),
                ),
                items: suits.map((suit) {
                  return DropdownMenuItem<String>(
                    value: suit,
                    child: Text(suit),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _suit = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final input = value?.trim() ?? '';

                  if (input.isEmpty) return null;

                  final uri = Uri.tryParse(input);

                  if (uri == null ||
                      !uri.hasAuthority ||
                      (uri.scheme != 'http' &&
                          uri.scheme != 'https')) {
                    return 'Enter a valid URL or leave blank';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
