import 'package:flutter_test/flutter_test.dart';
import 'package:collaborative_todo/features/todos/domain/todo.dart';

void main() {
  test('status values round-trip through the API representation', () {
    for (final status in TodoStatus.values) {
      expect(TodoStatus.fromJson(status.wireValue), status);
    }
  });

  test('todo reads persisted fields and converts timestamps to local time', () {
    final todo = Todo.fromJson({
      'id': 'task-1',
      'title': 'Shared task',
      'description': '',
      'status': 'in_progress',
      'createdBy': 'Alex',
      'updatedBy': 'Sam',
      'createdAt': '2026-01-02T03:04:05.000Z',
      'updatedAt': '2026-01-03T03:04:05.000Z',
    });

    expect(todo.status, TodoStatus.inProgress);
    expect(todo.createdBy, 'Alex');
    expect(todo.updatedBy, 'Sam');
    expect(todo.createdAt.isUtc, isFalse);
  });
}
