import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'features/todos/data/todo_repository.dart';
import 'features/todos/presentation/todo_controller.dart';
import 'features/todos/presentation/todo_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final controller = TodoController(TodoRepository());
        unawaited(controller.initialize());
        return controller;
      },
      child: const CollaborativeTodoApp(),
    ),
  );
}

class CollaborativeTodoApp extends StatelessWidget {
  const CollaborativeTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shared Todo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B62),
          surface: const Color(0xFFF7F8F5),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
      ),
      home: const TodoPage(),
    );
  }
}
