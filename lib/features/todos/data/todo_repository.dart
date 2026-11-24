import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/todo.dart';

const _defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

class TodoRepository {
  TodoRepository({http.Client? client, String apiBaseUrl = _defaultApiBaseUrl})
    : _client = client ?? http.Client(),
      _apiBaseUrl = Uri.parse(apiBaseUrl);

  final http.Client _client;
  final Uri _apiBaseUrl;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;

  Uri get _tasksUri => _apiBaseUrl.resolve('/api/tasks');

  Future<List<Todo>> getTodos() async {
    final response = await _client.get(_tasksUri);
    final body = _decodeResponse(response);
    if (body is! List) {
      throw const FormatException('The server returned an invalid task list.');
    }
    return body
        .map((item) => Todo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Todo> createTodo({
    required String title,
    required String description,
    required String actor,
  }) async {
    final response = await _client.post(
      _tasksUri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'createdBy': actor,
      }),
    );
    return Todo.fromJson(_decodeResponse(response) as Map<String, dynamic>);
  }

  Future<Todo> updateTodo({
    required Todo todo,
    required String title,
    required String description,
    required TodoStatus status,
    required String actor,
  }) async {
    final response = await _client.put(
      _tasksUri.resolve('/api/tasks/${todo.id}'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'status': status.wireValue,
        'updatedBy': actor,
      }),
    );
    return Todo.fromJson(_decodeResponse(response) as Map<String, dynamic>);
  }

  Future<Todo> updateStatus({
    required Todo todo,
    required TodoStatus status,
    required String actor,
  }) => updateTodo(
    todo: todo,
    title: todo.title,
    description: todo.description,
    status: status,
    actor: actor,
  );

  Future<void> deleteTodo({required Todo todo, required String actor}) async {
    final response = await _client.delete(
      _tasksUri.resolve('/api/tasks/${todo.id}'),
      headers: {'x-actor': actor},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeResponse(response);
    }
  }

  Future<void> connect({
    required ValueChanged<Map<String, dynamic>> onEvent,
    required ValueChanged<bool> onConnectionChanged,
    required ValueChanged<Object> onError,
  }) async {
    await disconnect();
    final socketUri = _apiBaseUrl.replace(
      scheme: _apiBaseUrl.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws',
    );
    final channel = WebSocketChannel.connect(socketUri);
    _channel = channel;
    await channel.ready;
    onConnectionChanged(true);
    _socketSubscription = channel.stream.listen(
      (message) {
        try {
          final decoded = jsonDecode(message as String);
          if (decoded is Map<String, dynamic>) {
            onEvent(decoded);
          } else {
            onError(const FormatException('Invalid WebSocket event.'));
          }
        } on Object catch (error) {
          onError(error);
        }
      },
      onError: (Object error) {
        onConnectionChanged(false);
        onError(error);
      },
      onDone: () => onConnectionChanged(false),
    );
  }

  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Object? _decodeResponse(http.Response response) {
    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error'] as String? ?? 'Request failed'
          : 'Request failed';
      throw TodoApiException(response.statusCode, message);
    }
    return decoded;
  }
}

class TodoApiException implements Exception {
  const TodoApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
