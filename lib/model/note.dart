class Note {
  final String id;
  String title;
  String content; // For now: plain text or rich text JSON in string
  List<String> tags;
  bool isBookmarked;
  bool isArchived;
  bool isPinned;
  DateTime createdTime;
  String? summary;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    this.isBookmarked = false,
    this.isArchived = false,
    this.isPinned = false,
    DateTime? createdTime,
    this.summary,
  }) : createdTime = createdTime ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'tags': tags,
      'isBookmarked': isBookmarked,
      'isArchived': isArchived,
      'isPinned': isPinned,
      'createdTime': createdTime.millisecondsSinceEpoch,
      'summary': summary,
    };
  }

  static Note fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      title: (map['title'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      isBookmarked: (map['isBookmarked'] ?? false) as bool,
      isArchived: (map['isArchived'] ?? false) as bool,
      isPinned: (map['isPinned'] ?? false) as bool,
      createdTime: DateTime.fromMillisecondsSinceEpoch((map['createdTime'] ?? DateTime.now().millisecondsSinceEpoch) as int),
      summary: (map['summary'] as String?),
    );
  }
}
