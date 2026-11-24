enum TodoStatus {
  pending,
  inProgress,
  completed;

  String get label => switch (this) {
    TodoStatus.pending => 'Pending',
    TodoStatus.inProgress => 'In Progress',
    TodoStatus.completed => 'Completed',
  };

  String get wireValue => switch (this) {
    TodoStatus.pending => 'pending',
    TodoStatus.inProgress => 'in_progress',
    TodoStatus.completed => 'completed',
  };

  static TodoStatus fromJson(Object? value) => switch (value) {
    'pending' => TodoStatus.pending,
    'in_progress' => TodoStatus.inProgress,
    'completed' => TodoStatus.completed,
    _ => throw FormatException('Unknown todo status: $value'),
  };
}

class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final TodoStatus status;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    status: TodoStatus.fromJson(json['status']),
    createdBy: json['createdBy'] as String,
    updatedBy: json['updatedBy'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
  );
}
