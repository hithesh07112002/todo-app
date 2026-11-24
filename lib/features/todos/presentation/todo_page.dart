import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../domain/todo.dart';
import 'todo_controller.dart';
import 'todo_report.dart';

class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoController>(
      builder: (context, controller, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Shared tasks'),
          actions: [
            IconButton(
              tooltip: 'Set your display name',
              onPressed: () => _editDisplayName(context, controller),
              icon: const Icon(Icons.person_outline),
            ),
            IconButton(
              tooltip: 'Print or export report',
              onPressed: controller.todos.isEmpty
                  ? null
                  : () => _printReport(context, controller.todos),
              icon: const Icon(Icons.print_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editTodo(context),
          icon: const Icon(Icons.add),
          label: const Text('Add task'),
        ),
        body: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _ConnectionCard(controller: controller),
              if (controller.error case final error?)
                _ErrorBanner(message: error),
              _StatusSummary(controller: controller),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    '${controller.todos.length} total',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (controller.isLoading && controller.todos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.todos.isEmpty)
                const _EmptyTasks()
              else
                ...controller.todos.map(
                  (todo) => _TodoCard(
                    todo: todo,
                    onEdit: () => _editTodo(context, todo: todo),
                    onDelete: () => _confirmDelete(context, controller, todo),
                    onStatusChanged: (status) =>
                        controller.updateStatus(todo, status),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editDisplayName(
    BuildContext context,
    TodoController controller,
  ) async {
    final input = TextEditingController(text: controller.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your display name'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    input.dispose();
    if (name != null) controller.setDisplayName(name);
  }

  Future<void> _printReport(BuildContext context, List<Todo> todos) async {
    try {
      await TodoReport.printReport(todos);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate report: $error')),
      );
    }
  }

  Future<void> _editTodo(BuildContext context, {Todo? todo}) async {
    final input = await showDialog<_TodoInput>(
      context: context,
      builder: (context) => _TodoEditor(todo: todo),
    );
    if (input == null || !context.mounted) return;
    final controller = context.read<TodoController>();
    if (todo == null) {
      await controller.createTodo(input.title, input.description);
    } else {
      await controller.updateTodo(
        todo,
        title: input.title,
        description: input.description,
        status: input.status,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TodoController controller,
    Todo todo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${todo.title}” will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteTodo(todo);
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.controller});

  final TodoController controller;

  @override
  Widget build(BuildContext context) {
    final color = controller.isConnected
        ? const Color(0xFF167A50)
        : const Color(0xFF9A5A10);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              controller.isConnected ? Icons.wifi : Icons.wifi_off,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.isConnected
                    ? 'Live sync connected'
                    : 'Connecting to the shared list…',
              ),
            ),
            Text(
              controller.displayName,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
  );
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.controller});

  final TodoController controller;

  @override
  Widget build(BuildContext context) {
    final counts = TodoStatus.values.map(controller.countFor).toList();
    final total = counts.fold<int>(0, (sum, count) => sum + count);
    final colors = [
      const Color(0xFFE6A23C),
      const Color(0xFF4886D7),
      const Color(0xFF40A878),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 28,
                          sections: total == 0
                              ? [
                                  PieChartSectionData(
                                    value: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    radius: 24,
                                    showTitle: false,
                                  ),
                                ]
                              : List.generate(
                                  TodoStatus.values.length,
                                  (index) => PieChartSectionData(
                                    value: counts[index].toDouble(),
                                    color: colors[index],
                                    radius: 24,
                                    showTitle: false,
                                  ),
                                ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '$total',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: List.generate(
                      TodoStatus.values.length,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 5,
                              backgroundColor: colors[index],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(TodoStatus.values[index].label),
                            ),
                            Text(
                              '${counts[index]}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.todo,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final Todo todo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<TodoStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (todo.status) {
      TodoStatus.pending => const Color(0xFFB36B0D),
      TodoStatus.inProgress => const Color(0xFF2868B2),
      TodoStatus.completed => const Color(0xFF24784B),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    todo.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuButton<TodoStatus>(
                  tooltip: 'Change status',
                  initialValue: todo.status,
                  onSelected: onStatusChanged,
                  itemBuilder: (context) => TodoStatus.values
                      .map(
                        (status) => PopupMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                  child: Chip(
                    label: Text(todo.status.label),
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: statusColor.withValues(alpha: 0.25),
                    ),
                    backgroundColor: statusColor.withValues(alpha: 0.08),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (todo.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(todo.description),
            ],
            const SizedBox(height: 10),
            Text(
              'Created by ${todo.createdBy} · Updated by ${todo.updatedBy}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 3),
            Text(
              'Updated ${DateFormat.yMMMd().add_jm().format(todo.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(Icons.checklist, size: 52),
        SizedBox(height: 12),
        Text('No tasks yet. Add one to get started.'),
      ],
    ),
  );
}

class _TodoInput {
  const _TodoInput(this.title, this.description, this.status);

  final String title;
  final String description;
  final TodoStatus status;
}

class _TodoEditor extends StatefulWidget {
  const _TodoEditor({this.todo});

  final Todo? todo;

  @override
  State<_TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<_TodoEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late TodoStatus _status;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.todo?.title ?? '');
    _description = TextEditingController(text: widget.todo?.description ?? '');
    _status = widget.todo?.status ?? TodoStatus.pending;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.todo == null ? 'Add task' : 'Edit task'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: 'Title',
              errorText: _validationError,
            ),
          ),
          TextField(
            controller: _description,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          if (widget.todo != null)
            DropdownButtonFormField<TodoStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: TodoStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: (status) {
                if (status != null) setState(() => _status = status);
              },
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final title = _title.text.trim();
          if (title.isEmpty) {
            setState(() => _validationError = 'Enter a task title');
            return;
          }
          Navigator.pop(
            context,
            _TodoInput(title, _description.text.trim(), _status),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}
