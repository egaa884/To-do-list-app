class Task {
  final int? id;
  final String title;
  final String desc;
  final String category;
  final DateTime dateTime;
  final bool isCompleted;
  final bool isStarred;
  final int priority; // 0: Low, 1: Medium, 2: High

  Task({
    this.id,
    required this.title,
    required this.desc,
    required this.category,
    required this.dateTime,
    this.isCompleted = false,
    this.isStarred = false,
    this.priority = 1, // Default Medium
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'desc': desc,
      'category': category,
      'dateTime': dateTime.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'isStarred': isStarred ? 1 : 0,
      'priority': priority,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      desc: map['desc'],
      category: map['category'],
      dateTime: DateTime.parse(map['dateTime']),
      isCompleted: map['isCompleted'] == 1,
      isStarred: map['isStarred'] == 1,
      priority: map['priority'] ?? 1,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? desc,
    String? category,
    DateTime? dateTime,
    bool? isCompleted,
    bool? isStarred,
    int? priority,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      desc: desc ?? this.desc,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      isStarred: isStarred ?? this.isStarred,
      priority: priority ?? this.priority,
    );
  }
}
