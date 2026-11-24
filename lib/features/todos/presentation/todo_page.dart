import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../domain/todo.dart';
import 'todo_controller.dart';
import 'todo_report.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _searchController = TextEditingController();
  TodoStatus? _statusFilter;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoController>(
      builder: (context, controller, _) {
        final filteredTodos = controller.todos.where((todo) {
          final matchesStatus =
              _statusFilter == null || todo.status == _statusFilter;
          final query = _query.toLowerCase();
          final matchesQuery =
              query.isEmpty ||
              todo.title.toLowerCase().contains(query) ||
              todo.description.toLowerCase().contains(query) ||
              todo.createdBy.toLowerCase().contains(query);
          return matchesStatus && matchesQuery;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 76,
            titleSpacing: 22,
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF174E43),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Collaborative Todo List',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'TEAM WORKSPACE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF72817B),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (MediaQuery.sizeOf(context).width > 650) ...[
                _LiveBadge(
                  isConnected: controller.isConnected,
                  isConnecting: controller.isConnecting,
                ),
                const SizedBox(width: 12),
              ],
              IconButton(
                tooltip: 'Print or export report',
                onPressed: controller.todos.isEmpty
                    ? null
                    : () => _printReport(context, controller.todos),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _editDisplayName(context, controller),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFFDCECE4),
                    child: Text(
                      _initials(controller.displayName),
                      style: const TextStyle(
                        color: Color(0xFF174E43),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _editTodo(context),
            backgroundColor: const Color(0xFF174E43),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New task'),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      constraints.maxWidth < 600 ? 18 : 32,
                      28,
                      constraints.maxWidth < 600 ? 18 : 32,
                      104,
                    ),
                    children: [
                      _WelcomeHeader(controller: controller),
                      if (controller.error case final error?) ...[
                        const SizedBox(height: 18),
                        _ErrorBanner(
                          message: error,
                          onRetry: controller.initialize,
                        ),
                      ],
                      const SizedBox(height: 25),
                      _StatusSummary(controller: controller),
                      const SizedBox(height: 34),
                      _BoardHeader(
                        total: controller.todos.length,
                        visible: filteredTodos.length,
                      ),
                      const SizedBox(height: 15),
                      _TaskFilters(
                        controller: controller,
                        searchController: _searchController,
                        selectedStatus: _statusFilter,
                        onQueryChanged: (query) =>
                            setState(() => _query = query),
                        onStatusChanged: (status) =>
                            setState(() => _statusFilter = status),
                      ),
                      const SizedBox(height: 16),
                      if (controller.isLoading && controller.todos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (filteredTodos.isEmpty)
                        _EmptyTasks(
                          hasFilters:
                              _query.isNotEmpty || _statusFilter != null,
                          onAdd: () => _editTodo(context),
                        )
                      else
                        ...filteredTodos.map(
                          (todo) => _TodoCard(
                            todo: todo,
                            onEdit: () => _editTodo(context, todo: todo),
                            onDelete: () =>
                                _confirmDelete(context, controller, todo),
                            onStatusChanged: (status) =>
                                controller.updateStatus(todo, status),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editDisplayName(
    BuildContext context,
    TodoController controller,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _DisplayNameEditor(initialName: controller.displayName),
    );
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

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.controller});

  final TodoController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF788781),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make progress together.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF1E3029),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'One shared space for the work that matters.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: const Color(0xFF738079)),
              ),
              if (MediaQuery.sizeOf(context).width <= 650) ...[
                const SizedBox(height: 14),
                _LiveBadge(
                  isConnected: controller.isConnected,
                  isConnecting: controller.isConnecting,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isConnected, required this.isConnecting});

  final bool isConnected;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? const Color(0xFF26815D)
        : isConnecting
        ? const Color(0xFFAA762A)
        : const Color(0xFFB54738);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected
                ? 'LIVE SYNC'
                : isConnecting
                ? 'CONNECTING'
                : 'OFFLINE',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1EF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF3D1CC)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFFB54738)),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.controller});

  final TodoController controller;

  static const _colors = [
    Color(0xFFE2A23B),
    Color(0xFF5489D0),
    Color(0xFF38A27A),
  ];

  static const _icons = [
    Icons.hourglass_bottom_rounded,
    Icons.autorenew_rounded,
    Icons.task_alt_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final counts = TodoStatus.values.map(controller.countFor).toList();
    final total = counts.fold<int>(0, (sum, count) => sum + count);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 700
            ? (constraints.maxWidth - 24) / 3
            : (constraints.maxWidth - 12) / 2;
        return Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(TodoStatus.values.length, (index) {
                final color = _colors[index];
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(17, 16, 15, 17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE8ECE9)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F2D22),
                          blurRadius: 16,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                _icons[index],
                                color: color,
                                size: 19,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${total == 0 ? 0 : (counts[index] / total * 100).round()}%',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: const Color(0xFF89948F),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${counts[index]}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E3029),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TodoStatus.values[index].label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF738079),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8ECE9)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F2D22),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 128,
                    height: 128,
                    child: Stack(
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 34,
                            sections: total == 0
                                ? [
                                    PieChartSectionData(
                                      value: 1,
                                      color: const Color(0xFFE9EEEB),
                                      radius: 25,
                                      showTitle: false,
                                    ),
                                  ]
                                : List.generate(
                                    TodoStatus.values.length,
                                    (index) => PieChartSectionData(
                                      value: counts[index].toDouble(),
                                      color: _colors[index],
                                      radius: 25,
                                      showTitle: false,
                                    ),
                                  ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$total',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'TOTAL',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xFF89948F),
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task status',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF20342C),
                              ),
                        ),
                        const SizedBox(height: 12),
                        ...TodoStatus.values.indexed.map((entry) {
                          final index = entry.$1;
                          final status = entry.$2;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: _colors[index],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    status.label,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF718079),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                Text(
                                  '${counts[index]}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF20342C),
                                      ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.total, required this.visible});

  final int total;
  final int visible;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR WORKSPACE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF788781),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Task board',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E3029),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      Text(
        visible == total ? '$total tasks' : '$visible of $total tasks',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF788781),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _TaskFilters extends StatelessWidget {
  const _TaskFilters({
    required this.controller,
    required this.searchController,
    required this.selectedStatus,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final TodoController controller;
  final TextEditingController searchController;
  final TodoStatus? selectedStatus;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<TodoStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Search tasks or people',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
                      onQueryChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFE6EBE8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFE6EBE8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFF4F8B77)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _StatusFilterChip(
              label: 'All tasks',
              count: controller.todos.length,
              selected: selectedStatus == null,
              onSelected: () => onStatusChanged(null),
            ),
            ...TodoStatus.values.map(
              (status) => _StatusFilterChip(
                label: status.label,
                count: controller.countFor(status),
                selected: selectedStatus == status,
                onSelected: () =>
                    onStatusChanged(selectedStatus == status ? null : status),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF174E43)
        : const Color(0xFF65736C);
    return ChoiceChip(
      label: Text('$label  $count'),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: foreground,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFDCECE4),
      side: BorderSide(
        color: selected ? const Color(0xFFC5DDD0) : const Color(0xFFE6EBE8),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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

  Color get _statusColor => switch (todo.status) {
    TodoStatus.pending => const Color(0xFFB77A1D),
    TodoStatus.inProgress => const Color(0xFF477EBE),
    TodoStatus.completed => const Color(0xFF28815E),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECE9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F2D22),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 64,
              margin: const EdgeInsets.only(right: 14, top: 2),
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF20342C),
                    ),
                  ),
                  if (todo.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      todo.description,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: const Color(0xFF718079)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: const Color(0xFFE8F0EC),
                        child: Text(
                          _initials(todo.createdBy),
                          style: const TextStyle(
                            color: Color(0xFF386B57),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        todo.createdBy,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFF52625A),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        '· Created ${DateFormat.yMMMd().format(todo.createdAt)} · Updated by ${todo.updatedBy} · ${DateFormat.yMMMd().add_jm().format(todo.updatedAt)}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: const Color(0xFF89948F)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          todo.status.label,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _statusColor,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Task actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit task'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete task'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF788781),
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

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.hasFilters, required this.onAdd});

  final bool hasFilters;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE8ECE9)),
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F2ED),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.checklist_rounded,
            color: Color(0xFF3B8066),
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          hasFilters ? 'No matching tasks' : 'Your board is ready',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF20342C),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          hasFilters
              ? 'Try another search or status filter.'
              : 'Add a task and start making progress together.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: const Color(0xFF788781)),
        ),
        if (!hasFilters) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create your first task'),
          ),
        ],
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

class _DisplayNameEditor extends StatefulWidget {
  const _DisplayNameEditor({required this.initialName});

  final String initialName;

  @override
  State<_DisplayNameEditor> createState() => _DisplayNameEditorState();
}

class _DisplayNameEditorState extends State<_DisplayNameEditor> {
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Your display name'),
    content: TextField(
      controller: _input,
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
        onPressed: () => Navigator.pop(context, _input.text),
        child: const Text('Save'),
      ),
    ],
  );
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
    title: Text(widget.todo == null ? 'Create a task' : 'Edit task'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: 'Task name',
              hintText: 'What needs to get done?',
              errorText: _validationError,
            ),
          ),
          TextField(
            controller: _description,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Add a few details',
            ),
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
            setState(() => _validationError = 'Enter a task name');
            return;
          }
          Navigator.pop(
            context,
            _TodoInput(title, _description.text.trim(), _status),
          );
        },
        child: Text(widget.todo == null ? 'Create task' : 'Save changes'),
      ),
    ],
  );
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
