import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../model/note.dart';

class AddNoteDialog extends StatelessWidget {
  final Note? note;
  final CollectionReference<Map<String, dynamic>>? notesCollection;
  final VoidCallback? onDelete;

  const AddNoteDialog({
    super.key,
    this.note,
    required this.notesCollection,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');
    bool isSaving = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 30,
          ),
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade50,
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        note == null ? 'New Note' : 'Edit Note',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (note != null && onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: isSaving
                              ? null
                              : () {
                                  onDelete!();
                                  if (context.mounted) Navigator.pop(context);
                                },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      filled: true,
                      fillColor: Color(0xFFF5F8F2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
                    ),
                    enabled: !isSaving,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Color(0xFFF5F8F2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
                    ),
                    minLines: 5,
                    maxLines: 12,
                    enabled: !isSaving,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2933),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: isSaving || notesCollection == null
                          ? null
                          : () async {
                              setState(() => isSaving = true);
                              final tags = note?.tags ?? <String>[];

                              try {
                                if (note == null) {
                                  final id = Random().nextInt(99999999).toString();
                                  await notesCollection!.doc(id).set(
                                    Note(
                                      id: id,
                                      title: titleController.text,
                                      content: contentController.text,
                                      tags: tags,
                                    ).toMap(),
                                  );
                                } else {
                                  final noteId = note!.id;
                                  await notesCollection!.doc(noteId).update({
                                    'title': titleController.text,
                                    'content': contentController.text,
                                  });
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                  setState(() => isSaving = false);
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(note == null ? 'Add Note' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void show(
    BuildContext context, {
    Note? note,
    required CollectionReference<Map<String, dynamic>>? notesCollection,
    VoidCallback? onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => AddNoteDialog(
        note: note,
        notesCollection: notesCollection,
        onDelete: onDelete,
      ),
    );
  }
}

