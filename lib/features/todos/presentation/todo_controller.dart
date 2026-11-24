import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/todo_repository.dart';
import '../domain/todo.dart';

class TodoController extends ChangeNotifier {
  TodoController(this._repository);

  final TodoRepository _repository;
  final List<Todo> _todos = [];
  final Set<String> _deletedIds = {};
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isLoading = true;
  String _displayName = 'Guest';
  String? _error;

  List<Todo> get todos => List.unmodifiable(_todos);
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String get displayName => _displayName;
  String? get error => _error;

  int countFor(TodoStatus status) =>
      _todos.where((todo) => todo.status == status).length;

  Future<void> initialize() async {
    await refresh();
    await _connect();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _notify();
    try {
      _replaceTodos(await _repository.getTodos());
      _error = null;
    } on Object catch (error) {
      _error = 'Unable to load tasks: $error';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void setDisplayName(String value) {
    final name = value.trim();
    if (name.isEmpty) return;
    _displayName = name;
    _notify();
  }

  Future<void> createTodo(String title, String description) async {
    await _perform(() async {
      final todo = await _repository.createTodo(
        title: title,
        description: description,
        actor: _displayName,
      );
      _upsert(todo);
    });
  }

  Future<void> updateTodo(
    Todo todo, {
    required String title,
    required String description,
    required TodoStatus status,
  }) async {
    await _perform(() async {
      _upsert(
        await _repository.updateTodo(
          todo: todo,
          title: title,
          description: description,
          status: status,
          actor: _displayName,
        ),
      );
    });
  }

  Future<void> updateStatus(Todo todo, TodoStatus status) async {
    await _perform(() async {
      _upsert(
        await _repository.updateStatus(
          todo: todo,
          status: status,
          actor: _displayName,
        ),
      );
    });
  }

  Future<void> deleteTodo(Todo todo) async {
    await _perform(() async {
      await _repository.deleteTodo(todo: todo, actor: _displayName);
      _deletedIds.add(todo.id);
      _todos.removeWhere((item) => item.id == todo.id);
      _notify();
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
      _error = null;
    } on Object catch (error) {
      _error = 'Task update failed: $error';
    }
    _notify();
  }

  Future<void> _connect() async {
    if (_isDisposed || _isConnecting || _isConnected) return;
    _isConnecting = true;
    try {
      await _repository.connect(
        onEvent: _handleEvent,
        onConnectionChanged: (connected) {
          _isConnected = connected;
          _notify();
          if (!connected) _scheduleReconnect();
        },
        onError: (error) {
          _error = 'Live updates unavailable: $error';
          _notify();
        },
      );
      _error = null;
    } on Object catch (error) {
      _isConnected = false;
      _error = 'Unable to connect for live updates: $error';
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
      _notify();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      await refresh();
      await _connect();
    });
  }

  void _handleEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'snapshot':
        final items = event['tasks'];
        if (items is List) {
          _deletedIds.clear();
          _replaceTodos(
            items
                .map((item) => Todo.fromJson(item as Map<String, dynamic>))
                .toList(),
          );
        }
      case 'task_created':
      case 'task_updated':
        final task = event['task'];
        if (task is Map<String, dynamic>) {
          _upsert(Todo.fromJson(task));
        }
      case 'task_deleted':
        final id = event['id'];
        if (id is String) {
          _deletedIds.add(id);
          _todos.removeWhere((todo) => todo.id == id);
          _notify();
        }
      default:
        _error = 'Received an unknown live update.';
        _notify();
    }
  }

  void _replaceTodos(List<Todo> todos) {
    _todos
      ..clear()
      ..addAll(todos);
    _notify();
  }

  void _upsert(Todo todo) {
    if (_deletedIds.contains(todo.id)) return;
    final index = _todos.indexWhere((item) => item.id == todo.id);
    if (index == -1) {
      _todos.add(todo);
    } else {
      if (_todos[index].updatedAt.isAfter(todo.updatedAt)) return;
      _todos[index] = todo;
    }
    _todos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    unawaited(_repository.disconnect());
    super.dispose();
  }
}
