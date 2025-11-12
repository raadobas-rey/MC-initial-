import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/note.dart';
import 'app_drawer.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:act1adobas/secrets.dart';
import 'study_assistant_screen.dart';
import 'add_note.dart';
import 'settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Note> _notes = [];
  String search = '';
  String filterTag = 'All';

  String? _userName;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  CollectionReference<Map<String, dynamic>>? get _notesCol {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('notes');
  }

  Future<void> _toggleBookmark(Note note) async {
    final col = _notesCol;
    if (col == null) return;
    setState(() => note.isBookmarked = !note.isBookmarked);
    await col.doc(note.id).update({'isBookmarked': note.isBookmarked});
  }

  Future<void> _archiveNote(Note note) async {
    final col = _notesCol;
    if (col == null) return;
    setState(() => note.isArchived = true);
    await col.doc(note.id).update({'isArchived': true});
  }

  Future<void> _restoreNote(Note note) async {
    final col = _notesCol;
    if (col == null) return;
    setState(() => note.isArchived = false);
    await col.doc(note.id).update({'isArchived': false});
  }

  Future<void> _deleteNote(Note note) async {
    final col = _notesCol;
    if (col == null) return;
    await col.doc(note.id).delete();
  }

  Future<void> _summarizeNote(Note note) async {
    final apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: AppSecrets.geminiApiKey);
    // If no key, do a simple on-device fallback summary
    if (apiKey.isEmpty) {
      final fallback = _localSummarize(note.content);
      note.summary = fallback;
      await _notesCol?.doc(note.id).update({'summary': fallback});
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generated quick summary (offline fallback)')),
        );
      }
      return;
    }
    try {
      // Show a blocking loader over everything
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Truncate very long notes to avoid token limits
      final content = note.content.length > 8000
          ? note.content.substring(0, 8000)
          : note.content;

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final prompt = 'You are a writing assistant. Reorganize and summarize the following messy, unordered note into 1–2 clear sentences (no bullet points, no markdown). Fix grammar, remove duplicates, and keep the most important ideas only. Plain text output.\n\n$content';
      final resp = await model.generateContent([Content.text(prompt)]);
      final summary = resp.text?.trim();
      if (summary == null || summary.isEmpty) {
        throw Exception('Empty response');
      }
      note.summary = summary;
      await _notesCol?.doc(note.id).update({'summary': summary});
      if (mounted) {
        setState(() {}); // refresh sheet content
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Summary failed: $e')),
        );
      }
    } finally {
      // Close loader
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  String _localSummarize(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return '';
    // Split into sentences, filter out very short ones, deduplicate, then pick the most informative (by length)
    final raw = clean.split(RegExp(r'(?<=[.!?])\s+'));
    final seen = <String>{};
    final sentences = <String>[];
    for (final s in raw) {
      final t = s.trim();
      if (t.split(' ').length >= 5 && seen.add(t.toLowerCase())) {
        sentences.add(t);
      }
    }
    sentences.sort((a, b) => b.length.compareTo(a.length));
    if (sentences.isEmpty) {
      final words = clean.split(' ');
      final preview = words.take(30).join(' ');
      return preview.length > 180 ? '${preview.substring(0, 180)}…' : preview;
    }
    final best = sentences.take(2).join(' ');
    return best.length > 220 ? '${best.substring(0, 220)}…' : best;
  }

  Future<void> _togglePin(Note note) async {
    final col = _notesCol;
    if (col == null) return;
    setState(() => note.isPinned = !note.isPinned);
    await col.doc(note.id).update({'isPinned': note.isPinned});
  }

  Future<List<Map<String, String>>> _generateQuiz(Note note) async {
    final apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: AppSecrets.geminiApiKey);
    List<Map<String, String>> result = [];
    if (apiKey.isNotEmpty) {
      try {
        showDialog(context: context, barrierDismissible: false, useRootNavigator: true, builder: (_) => const Center(child: CircularProgressIndicator()));
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
        final prompt = 'From the NOTE below, write EXACTLY 5 DIFFERENT quiz Q/A pairs.\n- Each question must focus on a different concept or detail.\n- Vary types (what/why/how/example/compare) when possible.\n- Keep questions and answers short.\n- Output ONLY pairs in two lines each: first line "Q: ..." then next line "A: ..." (repeat 5 times).\n\nNOTE:\n${note.content}';
        final resp = await model.generateContent([Content.text(prompt)]);
        final text = resp.text ?? '';
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final seen = <String>{};
        for (int i = 0; i < lines.length - 1; i++) {
          final q = lines[i];
          final a = lines[i + 1];
          if (q.toLowerCase().startsWith('q') && a.toLowerCase().startsWith('a')) {
            final qq = q.replaceFirst(RegExp(r'^Q[:\s-]*'), '').trim();
            final aa = a.replaceFirst(RegExp(r'^A[:\s-]*'), '').trim();
            if (qq.isNotEmpty && aa.isNotEmpty && seen.add(qq.toLowerCase())) {
              result.add({'q': qq, 'a': aa});
            }
          }
        }
      } catch (_) {
        // fall back below
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    }

    // Backfill to ensure EXACTLY 5 unique and varied items
    final seenQs = <String>{...result.map((e) => e['q']!.toLowerCase())};
    final sentences = note.content
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 10)
        .toList();

    List<String> templates = [
      'What is',
      'Why is',
      'How does',
      'Give one example of',
      'List one benefit of',
      'When would you use',
      'Compare briefly: '
    ];

    int t = 0;
    int idx = 0;
    while (result.length < 5 && (idx < sentences.length || t < templates.length)) {
      final s = idx < sentences.length ? sentences[idx++] : sentences[(idx++) % sentences.length];
      final words = s.split(RegExp(r'\s+'));
      final snippet = words.take(4).join(' ');
      final template = templates[t % templates.length];
      t++;
      String q;
      if (template == 'Compare briefly: ') {
        // build a compare-style question using two snippets if possible
        final s2 = sentences.isNotEmpty ? sentences[(idx) % sentences.length] : s;
        final words2 = s2.split(RegExp(r'\s+'));
        final sn2 = words2.take(3).join(' ');
        q = 'Compare briefly: $snippet vs $sn2';
      } else {
        q = '$template $snippet?';
      }
      if (seenQs.add(q.toLowerCase())) {
        result.add({'q': q, 'a': s});
      }
    }

    if (result.length > 5) result = result.take(5).toList();

    await _notesCol?.doc(note.id).collection('quizzes').add({'items': result, 'ts': FieldValue.serverTimestamp()});
    return result;
  }

  void _showQuiz(List<Map<String, String>> items) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quiz'),
        content: SizedBox(
          width: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final qa = items[i];
              return ExpansionTile(
                title: Text(qa['q'] ?? ''),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                    child: Align(alignment: Alignment.centerLeft, child: Text(qa['a'] ?? '')),
                  )
                ],
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('name')) {
          setState(() {
            _userName = doc['name'] as String? ?? 'User';
          });
        } else {
          setState(() {
            _userName = 'User';
          });
        }
      } else {
        setState(() {
          _userName = null;
        });
      }
    } catch (e) {
      setState(() {
        _userName = 'User';
      });
    }
  }

  void _openTrash() {
    final archived = _notes.where((n) => n.isArchived).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trash', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (archived.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No items in trash.')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: archived.length,
                    itemBuilder: (context, i) {
                      final note = archived[i];
                      return ListTile(
                        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'Restore',
                              onPressed: () async {
                                await _restoreNote(note);
                                if (mounted) Navigator.pop(context);
                              },
                            ),
              IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              tooltip: 'Delete forever',
                              onPressed: () async {
                                await _deleteNote(note);
                                if (mounted) Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }


  List<String> get _allTags {
    final tags = <String>{'All'};
    // pinned tags do not affect list; computed from notes
    for (final note in _notes) {
      tags.addAll(note.tags);
    }
    return tags.toList();
  }

  void _showNoteDialog({Note? note}) {
    AddNoteDialog.show(
      context,
      note: note,
      notesCollection: _notesCol,
      onDelete: note != null ? () => _deleteNote(note) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    final col = _notesCol;
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        userName: _userName,
        email: email,
        onOpenProfile: () async {
          final updatedName = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
          if (updatedName != null && updatedName.isNotEmpty) {
            setState(() => _userName = updatedName);
          }
        },
        onOpenFavorites: () {
          final favs = _notes.where((n) => n.isBookmarked && !n.isArchived).toList();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FavoritesScreen(
                favorites: favs,
                onToggleFavorite: (note) async {
                  await _toggleBookmark(note);
                },
              ),
            ),
          );
        },
        onOpenTrash: _openTrash,
        onOpenSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
        onLogout: () async {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
            Row(
            children: [
                IconButton(
                  icon: const Icon(Icons.menu, size: 28, color: Colors.black87),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Text('NoteNest', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 18),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _allTags.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final tag = _allTags[i];
                  return ChoiceChip(
                    label: Text(tag == 'All' ? 'All (${_notes.length})' : tag),
                    selected: filterTag == tag,
                    backgroundColor: tag == 'All' ? Colors.green[100] : Colors.white,
                    selectedColor: Colors.green,
                    labelStyle: TextStyle(
                      color: filterTag == tag ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (_) {
                      setState(() => filterTag = tag);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.black.withOpacity(0.6)),
                hintText: "Search notes...",
                hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => search = val),
            ),
            const SizedBox(height: 18),
            if (col == null)
              Center(child: Text('Please log in to view notes.', style: TextStyle(color: Colors.black.withOpacity(0.6))))
            else
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: col.orderBy('createdTime', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.black.withOpacity(0.6)));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final items = docs
                      .map((d) => Note.fromMap(d.id, d.data()))
                      .where((n) {
                        final matchesTag = filterTag == 'All' || n.tags.contains(filterTag);
                        final searchMatch = search.isEmpty ||
                          n.title.toLowerCase().contains(search.toLowerCase()) ||
                          n.content.toLowerCase().contains(search.toLowerCase());
                        return matchesTag && !n.isArchived && searchMatch;
                      })
                      .toList();
                  // sort pinned on top
                  items.sort((a, b) {
                    if (a.isPinned == b.isPinned) {
                      return b.createdTime.compareTo(a.createdTime);
                    }
                    return a.isPinned ? -1 : 1;
                  });
                  _notes
                    ..clear()
                    ..addAll(docs.map((d) => Note.fromMap(d.id, d.data())));
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          'No notes yet. Tap the + button to create your first note!',
                          style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 16),
                        ),
                      ),
                    );
                  }
                  return Column(children: items.map(_buildNoteCard).toList());
                },
              ),
            ],
          ),
        ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _showNoteDialog(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                height: 58,
                width: 58,
                child: const Center(
                    child: Icon(Icons.add, color: Colors.white, size: 34)),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyAssistantScreen()),
                );
              },
          child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                height: 58,
                width: 58,
                child: const Center(
                    child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28)),
          ),
        ),
      ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    // Format date
    final dateStr = _formatDate(note.createdTime);
    // Get preview text (summary or content)
    final previewText = (note.summary ?? '').isNotEmpty 
        ? note.summary! 
        : note.content;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, // Light background
        borderRadius: BorderRadius.circular(16),
        border: Border(
          bottom: BorderSide(
            color: Colors.green,
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFullContent(note),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Preview text
                Text(
                  previewText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                // Date and action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            color: note.isPinned ? Colors.green : Colors.black.withOpacity(0.5),
                            size: 20,
                          ),
                          tooltip: note.isPinned ? 'Unpin' : 'Pin',
                          onPressed: () async { await _togglePin(note); },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            note.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: note.isBookmarked ? Colors.green : Colors.black.withOpacity(0.5),
                            size: 20,
                          ),
                          tooltip: note.isBookmarked ? 'Remove bookmark' : 'Bookmark',
                          onPressed: () async {
                            await _toggleBookmark(note);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Colors.black.withOpacity(0.5),
                            size: 20,
                          ),
                          tooltip: 'Edit',
                          onPressed: () => _showNoteDialog(note: note),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.black.withOpacity(0.5),
                            size: 20,
                          ),
                          tooltip: 'Move to Trash',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Move to Trash?'),
                                content: const Text('You can restore it later from Trash.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _archiveNote(note);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showFullContent(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
        children: [
          Expanded(
            child: Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _summarizeNote(note),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Summarize'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final quiz = await _generateQuiz(note);
                        if (!mounted) return;
                        _showQuiz(quiz);
                      },
                      icon: const Icon(Icons.quiz_outlined, size: 18),
                      label: const Text('Quiz'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if ((note.summary ?? '').isNotEmpty) ...[
                  const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(note.summary!, style: const TextStyle(color: Colors.black87)),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Text(
                      note.content,
                      style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          ),
        ],
      ),
          ),
        );
      },
    );
  }
}
