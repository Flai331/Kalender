import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/todo.dart';
import '../services/local_service.dart';
import 'todo_card.dart';
import 'todo_edit_screen.dart';
import 'todo_status_dialog.dart';
import '../widgets/feedback_button.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late Stream<List<Todo>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = LocalService.unscheduledTodos();
  }

  void _refreshStream() {
    setState(() {
      _stream = LocalService.unscheduledTodos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Todos',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.drag_indicator,
                  size: 14, color: AppColors.textSecondary),
              label: const Text('In Woche ziehen',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
          ),
          const FeedbackIconButton(),
        ],
      ),
      body: StreamBuilder<List<Todo>>(
        stream: _stream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final todos = snap.data ?? [];

          if (todos.isEmpty) {
            return _EmptyState(
              onAdd: () => _openEdit(context),
            );
          }

          return Column(
            children: [
              // Info-Banner
              Container(
                color: AppColors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Todos per Drag & Drop in die Wochenansicht ziehen',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12),
                      ),
                    ),
                    Text('${todos.length}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
              // Liste
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: todos.length,
                  itemBuilder: (ctx, i) {
                    final todo = todos[i];
                    return TodoCard(
                      todo: todo,
                      onTap: () async {
                        final result = await TodoStatusDialog.show(
                            context: context, todo: todo);
                        if (result == 'delete') {
                          await LocalService.deleteTodo(todo.id);
                          _refreshStream();
                        } else if (result == 'edit') {
                          if (!context.mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TodoEditScreen(todo: todo)),
                          );
                          _refreshStream();
                        }
                      },
                      onDelete: () async {
                        await LocalService.deleteTodo(todo.id);
                        _refreshStream();
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'todos_fab',
        onPressed: () => _openEdit(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TodoEditScreen()),
    );
    _refreshStream();
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 64, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          const Text('Keine offenen Todos',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Erstelle ein Todo und ziehe es in die Wochenansicht',
              style:
                  TextStyle(color: AppColors.textDisabled, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Todo erstellen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
