import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:act1adobas/secrets.dart';
import '../model/note.dart';

class StudyAssistantScreen extends StatefulWidget {
  const StudyAssistantScreen({super.key});

  @override
  State<StudyAssistantScreen> createState() => _StudyAssistantScreenState();
}

class _StudyAssistantScreenState extends State<StudyAssistantScreen> {
  final List<_Msg> _messages = [];
  final TextEditingController _input = TextEditingController();
  bool _useNotes = true;
  bool _sending = false;
  bool _loadingHistory = true;
  bool _loadingSessions = true;
  String? _selectedSubject; // new: chosen subject
  List<String> _allSubjects = []; // new: cache all possible subjects
  String? _currentSessionId;
  List<_ChatSession> _sessions = [];

  CollectionReference<Map<String, dynamic>>? get _notesCol {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('notes');
  }

  // Legacy history collection kept for reference (migrated to sessions)

  // New sessions collection: users/{uid}/assistant_sessions
  CollectionReference<Map<String, dynamic>>? get _sessionsCol {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('assistant_sessions');
  }

  // Messages for the current session: users/{uid}/assistant_sessions/{sessionId}/messages
  CollectionReference<Map<String, dynamic>>? get _messagesCol {
    final sid = _currentSessionId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || sid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('assistant_sessions')
        .doc(sid)
        .collection('messages');
  }

  @override
  void initState() {
    super.initState();
    _loadSubjects(); // load subject/tags list
    _loadSessions();
  }

  // Load chat sessions; ensure at least one exists; then load its history
  Future<void> _loadSessions() async {
    final col = _sessionsCol;
    if (col == null) {
      setState(() {
        _loadingSessions = false;
        _loadingHistory = false;
      });
      return;
    }
    final snap = await col.orderBy('updatedTs', descending: true).get();
    final sess = snap.docs.map((d) {
      final data = d.data();
      return _ChatSession(
        id: d.id,
        title: (data['title'] ?? 'New chat') as String,
        createdTs: (data['createdTs'] as Timestamp?)?.toDate(),
        updatedTs: (data['updatedTs'] as Timestamp?)?.toDate(),
      );
    }).toList();
    setState(() {
      _sessions = sess;
      _loadingSessions = false;
    });
    if (_sessions.isEmpty) {
      await _createNewChat(initialTitle: 'New chat');
      return;
    }
    // pick the most recent session if none selected
    _currentSessionId ??= _sessions.first.id;
    await _loadHistory();
  }

  Future<void> _createNewChat({String? initialTitle}) async {
    final col = _sessionsCol;
    if (col == null) return;
    final ref = await col.add({
      'title': initialTitle ?? 'New chat',
      'createdTs': FieldValue.serverTimestamp(),
      'updatedTs': FieldValue.serverTimestamp(),
    });
    setState(() {
      _currentSessionId = ref.id;
      _messages.clear();
      _sessions.insert(
        0,
        _ChatSession(id: ref.id, title: initialTitle ?? 'New chat', createdTs: DateTime.now(), updatedTs: DateTime.now()),
      );
    });
    await _loadHistory();
  }

  Future<void> _deleteSession(String sessionId) async {
    final sessCol = _sessionsCol;
    if (sessCol == null) return;
    // delete messages subcollection
    final msgCol = sessCol.doc(sessionId).collection('messages');
    final msgSnap = await msgCol.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in msgSnap.docs) {
      batch.delete(d.reference);
    }
    batch.delete(sessCol.doc(sessionId));
    await batch.commit();
    setState(() {
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_currentSessionId == sessionId) {
        _currentSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
        _messages.clear();
      }
    });
    if (_currentSessionId != null) {
      await _loadHistory();
    } else {
      // No sessions left; create a new one
      await _createNewChat(initialTitle: 'New chat');
    }
  }

  Future<void> _touchSession({String? maybeTitle}) async {
    final col = _sessionsCol;
    final sid = _currentSessionId;
    if (col == null || sid == null) return;
    final data = <String, dynamic>{'updatedTs': FieldValue.serverTimestamp()};
    if (maybeTitle != null && maybeTitle.trim().isNotEmpty) {
      data['title'] = maybeTitle.trim();
    }
    await col.doc(sid).set(data, SetOptions(merge: true));
  }

  // Load all subjects (tags and titles)
  Future<void> _loadSubjects() async {
    final col = _notesCol;
    if (col == null) return;
    final snap = await col.get();
    final notes = snap.docs.map((d) => Note.fromMap(d.id, d.data())).toList();
    final sbj = <String>{};
    for (final n in notes) {
      if (n.title.isNotEmpty) sbj.add(n.title.trim());
      for (final t in n.tags) {
        if (t.trim().isNotEmpty) sbj.add(t.trim());
      }
    }
    setState(() => _allSubjects = sbj.toList()..sort());
  }

  // Fetch all notes matching selected subject/tag (not just top 5)
  Future<List<Note>> _fetchNotesForSubject(String subject) async {
    final col = _notesCol;
    if (col == null) return [];
    final snap = await col.get();
    final all = snap.docs.map((d) => Note.fromMap(d.id, d.data())).toList();
    final q = subject.toLowerCase();
    return all.where((n) => n.title.toLowerCase().contains(q) || n.tags.any((t) => t.toLowerCase().contains(q))).toList();
  }

  Future<void> _loadHistory() async {
    final col = _messagesCol;
    if (col == null) {
      setState(() => _loadingHistory = false);
      return;
    }
    final snap = await col.orderBy('ts', descending: false).limitToLast(100).get();
    final msgs = snap.docs.map((d) => _Msg(role: d['role'] as String, text: (d['text'] ?? '') as String)).toList();
    setState(() {
      _messages.clear();
      _messages.addAll(msgs);
      _loadingHistory = false;
    });
  }

  Future<void> _appendHistory(String role, String text) async {
    final col = _messagesCol;
    if (col == null) return;
    await col.add({'role': role, 'text': text, 'ts': FieldValue.serverTimestamp()});
    await _touchSession();
  }

  Future<List<Note>> _fetchRelevantNotes(String query) async {
    final col = _notesCol;
    if (col == null) return [];
    final snap = await col.get();
    final all = snap.docs.map((d) => Note.fromMap(d.id, d.data())).toList();
    final q = query.toLowerCase();
    all.sort((a, b) {
      final ascore = _score(a, q);
      final bscore = _score(b, q);
      return bscore.compareTo(ascore);
    });
    return all.take(5).toList();
  }

  int _score(Note n, String q) {
    int s = 0;
    if (n.title.toLowerCase().contains(q)) s += 3;
    if (n.content.toLowerCase().contains(q)) s += 2;
    for (final t in n.tags) {
      if (t.toLowerCase().contains(q)) s += 1;
    }
    if (n.isBookmarked) s += 1;
    return s;
  }


  // Which subject is the easiest to study among all my notes?
  Future<String> _recommendEasiestSubject() async {
    final col = _notesCol;
    if (col == null) return 'No notes found.';
    final snap = await col.get();
    final notes = snap.docs.map((d) => Note.fromMap(d.id, d.data())).toList();
    if (notes.isEmpty) return 'No notes found.';
    // Group by subject/title or tags
    final subjMap = <String, List<Note>>{};
    for (final n in notes) {
      final subjects = <String>{n.title.trim(), ...n.tags.map((t) => t.trim())}..removeWhere((t) => t.isEmpty);
      for (final s in subjects) {
        subjMap.putIfAbsent(s, () => []).add(n);
      }
    }
    if (subjMap.isEmpty) return 'No subjects found.';
    // Select the easiest (lowest avg note content length)
    final ranked = subjMap.entries.toList()
      ..sort((a, b) {
        double alen = a.value.map((n) => n.content.length).fold(0, (x, y) => x + y) / a.value.length;
        double blen = b.value.map((n) => n.content.length).fold(0, (x, y) => x + y) / b.value.length;
        return alen.compareTo(blen);
      });
    final easiest = ranked.first;
    final avgLen = easiest.value.map((n) => n.content.length).fold(0, (x, y) => x + y) ~/ easiest.value.length;
    return 'The subject that seems easiest to study right now is: "${easiest.key}" (average note length: $avgLen chars).\nRemember, shorter notes often mean ideas are summarized and likely less overwhelming. Start there for a quick win and build momentum!';
  }

  // In _send, intercept if asking about 'easiest subject'
  Future<void> _send() async {
    if (_sending) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    // ensure we have a current chat
    if (_currentSessionId == null) {
      await _createNewChat(initialTitle: text.split(RegExp(r'\s+')).take(6).join(' '));
    }
    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _sending = true;
      _input.clear();
    });
    await _appendHistory('user', text);
    // if session has default title, name it from first user message
    final firstTitle = text.split(RegExp(r'\s+')).take(6).join(' ');
    await _touchSession(maybeTitle: firstTitle);
    // Intercept for 'easiest subject to study'
    final checkText = text.toLowerCase();
    final isEasyQuery = checkText.contains('easiest subject') || checkText.contains('easy to study subject') || checkText.contains('which subject is easy');
    if (isEasyQuery) {
      final apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: AppSecrets.geminiApiKey);
      if (apiKey.isEmpty) {
        final reply = await _recommendEasiestSubject();
        setState(() {
          _messages.add(_Msg(role: 'assistant', text: reply));
          _sending = false;
        });
        await _appendHistory('assistant', reply);
        return;
      } else {
        // AI mode: fetch ALL notes grouped by subject, summarize, and ask Gemini to recommend the easiest
        final col = _notesCol;
        if (col == null) {
          setState(() {
            _messages.add(_Msg(role: 'assistant', text: 'No notes found.'));
            _sending = false;
          });
          await _appendHistory('assistant', 'No notes found.');
          return;
        }
        final snap = await col.get();
        final notes = snap.docs.map((d) => Note.fromMap(d.id, d.data())).toList();
        if (notes.isEmpty) {
          setState(() {
            _messages.add(_Msg(role: 'assistant', text: 'No notes found.'));
            _sending = false;
          });
          await _appendHistory('assistant', 'No notes found.');
          return;
        }
        // Group as in _recommendEasiestSubject
        final subjects = <String, List<Note>>{};
        for (final n in notes) {
          final keys = <String>{n.title.trim(), ...n.tags.map((t) => t.trim())}..removeWhere((t) => t.isEmpty);
          for (final k in keys) {
            subjects.putIfAbsent(k, () => []).add(n);
          }
        }
        // Prepare subject summaries
        final sb = StringBuffer();
        sb.writeln('Subjects and summaries:');
        for (final entry in subjects.entries) {
          final avgLen = entry.value.map((n) => n.content.length).fold(0, (x, y) => x + y) ~/ entry.value.length;
          final snippet = entry.value.first.content.split(RegExp(r'\s+')).take(10).join(' ');
          sb.writeln('- ${entry.key} (avg note length: $avgLen): $snippet...');
        }
        final prompt = 'You are an intelligent assistant helping a student prioritize study. Here are the user\'s note subjects, each with a sample and average note length. Which SINGLE subject is likely the easiest to study quickly? Only output the most appropriate subject and briefly explain your choice.';
        final userPrompt = sb.toString();
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
        final stream = model.generateContentStream([
          Content.system(prompt),
          Content.text(userPrompt),
        ]);
        String accum = '';
        await for (final chunk in stream) {
          final part = chunk.text;
          if (part != null && part.isNotEmpty) {
            accum += part;
            setState(() {
              if (_messages.isNotEmpty && _messages.last.role == 'assistant' && _messages.last.isStreaming) {
                _messages[_messages.length - 1] = _messages.last.copyWith(text: accum);
              } else {
                _messages.add(_Msg(role: 'assistant', text: accum, isStreaming: true));
              }
            });
          }
        }
        setState(() {
          if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
            _messages[_messages.length - 1] = _messages.last.copyWith(isStreaming: false);
          }
        });
        await _appendHistory('assistant', accum);
        setState(() => _sending = false);
        return;
      }
    }

    final apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: AppSecrets.geminiApiKey);
    if (apiKey.isEmpty) {
      final notes = _useNotes ? await _fetchRelevantNotes(text) : <Note>[];
      final reply = notes.isEmpty 
          ? 'I could not find notes related to "$text". Try toggling "Use notes" off or add more notes.'
          : _generateStudyPracticeFromNotes(text, notes);
      setState(() {
        _messages.add(_Msg(role: 'assistant', text: reply));
        _sending = false;
      });
      await _appendHistory('assistant', reply);
      return;
    }

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      String contextNotes = '';
      if (_useNotes) {
        final notes = await _fetchRelevantNotes(text);
        for (final n in notes) {
          final body = n.content.length > 800 ? n.content.substring(0, 800) : n.content;
          contextNotes += '\n- Title: ${n.title}\n${body}\n';
        }
      }

      final systemPrompt = 'You are a friendly, insightful study coach. Using the provided notes context (if any), answer the user clearly and concisely. In addition to answering their question, ALWAYS offer actionable study tips focused on how best to study, memorize, and master the topic; include memory strategies, time management, motivation, active recall, and note-taking tips. Do NOT suggest a study order or rank difficulty. Instead, provide practical explanations, personalized techniques, and encouragement. Each answer should feel motivating, practical, and focused on the subject. Only include quiz questions if the user asks.';
      final userPrompt = contextNotes.isEmpty
          ? text
          : 'Notes Context:\n$contextNotes\n\nUser Question: $text';

      final stream = model.generateContentStream([
        Content.system(systemPrompt),
        Content.text(userPrompt),
      ]);

      String accum = '';
      await for (final chunk in stream) {
        final part = chunk.text;
        if (part != null && part.isNotEmpty) {
          accum += part;
          setState(() {
            if (_messages.isNotEmpty && _messages.last.role == 'assistant' && _messages.last.isStreaming) {
              _messages[_messages.length - 1] = _messages.last.copyWith(text: accum);
            } else {
              _messages.add(_Msg(role: 'assistant', text: accum, isStreaming: true));
            }
          });
        }
      }
      setState(() {
        if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
          _messages[_messages.length - 1] = _messages.last.copyWith(isStreaming: false);
        }
      });
      await _appendHistory('assistant', accum);
    } catch (e) {
      final notes = _useNotes ? await _fetchRelevantNotes(text) : <Note>[];
      final reply = notes.isEmpty
          ? 'I could not find notes related to "$text". Try toggling "Use notes" off or add more notes.'
          : _generateStudyPracticeFromNotes(text, notes);
      setState(() {
        _messages.add(_Msg(role: 'assistant', text: reply));
      });
      await _appendHistory('assistant', reply);
    } finally {
      setState(() => _sending = false);
    }
  }

  // Generate personalized study practice based on actual note content
  String _generateStudyPracticeFromNotes(String subject, List<Note> notes) {
    if (notes.isEmpty) {
      return 'No notes found for "$subject". Add notes about this topic first.';
    }
    // Extract key concepts from notes
    final concepts = <String>{};
    final keywords = <String, int>{};
    for (final n in notes) {
      final words = n.content.toLowerCase().split(RegExp(r'\s+'));
      for (final w in words) {
        if (w.length > 4) {
          keywords[w] = (keywords[w] ?? 0) + 1;
        }
      }
      // Extract sentences as potential concepts
      final sentences = n.content.split(RegExp(r'[.!?]\s+'));
      for (final s in sentences.take(3)) {
        if (s.trim().length > 20 && s.trim().length < 150) {
          concepts.add(s.trim());
        }
      }
    }
    final topKeywords = keywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final keyTerms = topKeywords.take(5).map((e) => e.key).join(', ');
    
    final buffer = StringBuffer();
    buffer.writeln('📚 Study Practice for "$subject":\n');
    buffer.writeln('Key concepts to focus on: $keyTerms\n');
    if (concepts.isNotEmpty) {
      buffer.writeln('Important points from your notes:');
      for (final c in concepts.take(4)) {
        buffer.writeln('• $c');
      }
      buffer.writeln('');
    }
    buffer.writeln('Practice suggestions:');
    buffer.writeln('1. Review these ${notes.length} note(s) and highlight the main ideas.');
    buffer.writeln('2. Create flashcards for: $keyTerms');
    buffer.writeln('3. Write a summary in your own words covering the key points.');
    buffer.writeln('4. Test yourself: explain each concept without looking at your notes.');
    buffer.writeln('5. Connect ideas: how do these concepts relate to each other?');
    return buffer.toString();
  }

  // Send based on subject, using all notes for that subject as context
  Future<void> _sendBySubject(String subject) async {
    if (_sending) return;
    if (_currentSessionId == null) {
      await _createNewChat(initialTitle: subject);
    }
    setState(() {
      _messages.add(_Msg(role: 'user', text: subject));
      _sending = true;
      _input.clear();
    });
    await _appendHistory('user', subject);
    final apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: AppSecrets.geminiApiKey);
    final notes = _useNotes ? await _fetchNotesForSubject(subject) : <Note>[];
    
    if (apiKey.isEmpty) {
      // Generate study practice from actual note content (no templates)
      final reply = _generateStudyPracticeFromNotes(subject, notes);
      setState(() {
        _messages.add(_Msg(role: 'assistant', text: reply));
        _sending = false;
      });
      await _appendHistory('assistant', reply);
      return;
    }
    
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      String contextNotes = '';
      if (_useNotes && notes.isNotEmpty) {
        for (final n in notes) {
          final body = n.content.length > 1000 ? n.content.substring(0, 1000) : n.content;
          contextNotes += '\n- Title: ${n.title}\nContent: ${body}\n';
        }
      }
      
      final systemPrompt = 'You are a personalized study coach. Analyze the provided note content and generate SPECIFIC study practice recommendations based ONLY on what is in the notes. Do NOT use generic templates or tips. Instead, extract key concepts, important details, and create practice exercises tailored to the actual content. Be specific and actionable.';
      final userPrompt = contextNotes.isEmpty
          ? 'Generate study practice for: $subject'
          : 'Based on these notes about "$subject", create personalized study practice:\n$contextNotes\n\nGenerate specific practice recommendations, key concepts to focus on, and exercises tailored to this content.';
      
      final stream = model.generateContentStream([
        Content.system(systemPrompt),
        Content.text(userPrompt),
      ]);
      
      String accum = '';
      await for (final chunk in stream) {
        final part = chunk.text;
        if (part != null && part.isNotEmpty) {
          accum += part;
          setState(() {
            if (_messages.isNotEmpty && _messages.last.role == 'assistant' && _messages.last.isStreaming) {
              _messages[_messages.length - 1] = _messages.last.copyWith(text: accum);
            } else {
              _messages.add(_Msg(role: 'assistant', text: accum, isStreaming: true));
            }
          });
        }
      }
      setState(() {
        if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
          _messages[_messages.length - 1] = _messages.last.copyWith(isStreaming: false);
        }
      });
      await _appendHistory('assistant', accum);
    } catch (e) {
      // Fallback: generate from actual note content (no templates)
      final reply = _generateStudyPracticeFromNotes(subject, notes);
      setState(() {
        _messages.add(_Msg(role: 'assistant', text: reply));
      });
      await _appendHistory('assistant', reply);
    } finally {
      setState(() => _sending = false);
    }
  }

  void _showSessionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text('Chats', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No chats yet'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _sessions[i];
                      final selected = s.id == _currentSessionId;
                      return ListTile(
                        title: Text(s.title.isEmpty ? 'New chat' : s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        leading: Icon(selected ? Icons.chat_bubble : Icons.chat_bubble_outline),
                        onTap: () async {
                          Navigator.pop(ctx);
                          if (_currentSessionId != s.id) {
                            setState(() {
                              _currentSessionId = s.id;
                              _messages.clear();
                              _loadingHistory = true;
                            });
                            await _loadHistory();
                          }
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete chat?'),
                                content: const Text('This will delete the chat and its messages.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              Navigator.pop(ctx);
                              await _deleteSession(s.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // UI build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Assistant'),
        actions: [
          Row(children: [
            const Text('Use notes'),
            Switch(
              value: _useNotes,
              onChanged: (v) => setState(() => _useNotes = v),
            ),
          ]),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () async {
              if (_sending) return;
              await _createNewChat(initialTitle: 'New chat');
            },
          ),
          IconButton(
            tooltip: 'Chats',
            icon: const Icon(Icons.history),
            onPressed: () => _showSessionsSheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingSessions) const LinearProgressIndicator(minHeight: 2),
          // SUBJECT PICKER UI
          if (_allSubjects.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _allSubjects.length,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemBuilder: (context, i) {
                  final subj = _allSubjects[i];
                  final selected = _selectedSubject == subj;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(subj, style: TextStyle(fontWeight: FontWeight.w600)),
                      selected: selected,
                      selectedColor: Colors.green.shade200,
                      onSelected: (v) async {
                        if (v && !_sending) {
                          setState(() {
                            _selectedSubject = subj;
                            _input.text = subj; // autofill input
                          });
                          // Send as AI context
                          await _sendBySubject(subj);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          if (_loadingHistory)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isUser = m.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF4ADE80) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Ask anything about your notes…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _Msg {
  final String role; // 'user' or 'assistant'
  final String text;
  final bool isStreaming;
  _Msg({required this.role, required this.text, this.isStreaming = false});
  _Msg copyWith({String? text, bool? isStreaming}) => _Msg(role: role, text: text ?? this.text, isStreaming: isStreaming ?? this.isStreaming);
}

class _ChatSession {
  final String id;
  final String title;
  final DateTime? createdTs;
  final DateTime? updatedTs;
  _ChatSession({required this.id, required this.title, this.createdTs, this.updatedTs});
}

