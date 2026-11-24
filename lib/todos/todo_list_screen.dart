import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/todo.dart';
import '../services/listen_service.dart';
import '../services/local_service.dart';
import 'listen_schublade.dart';
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

  /// Die offene Liste, oder `null` fuer „Alle To-dos".
  String? _liste;

  @override
  void initState() {
    super.initState();
    _stream = LocalService.unscheduledTodos();
    // Eine umbenannte oder gefaerbte Liste muss sofort anders im Titel und
    // auf den Karten stehen.
    ListenService.revision.addListener(_listenGeaendert);
  }

  @override
  void dispose() {
    ListenService.revision.removeListener(_listenGeaendert);
    super.dispose();
  }

  void _listenGeaendert() {
    if (mounted) setState(() {});
  }

  void _refreshStream() {
    setState(() {
      _stream = LocalService.unscheduledTodos();
    });
  }

  /// Wie viele offene To-dos in welcher Liste stehen. Gezaehlt wird vor dem
  /// Filtern — sonst stuende in der Schublade ueberall dieselbe Zahl.
  Map<String, int> _anzahl(List<Todo> todos) {
    final raus = <String, int>{};
    for (final t in todos) {
      final id = ListenService.echteListe(t.listeId);
      raus[id] = (raus[id] ?? 0) + 1;
    }
    return raus;
  }

  @override
  Widget build(BuildContext context) {
    // Ein Strom fuer den ganzen Bildschirm, nicht nur fuer den Rumpf: die
    // Schublade braucht dieselben To-dos, um ihre Zahlen zu zeigen.
    return StreamBuilder<List<Todo>>(
      stream: _stream,
      builder: (ctx, snap) {
        final alle = snap.data ?? [];
        final warten = snap.connectionState == ConnectionState.waiting;
        final todos = _liste == null
            ? alle
            : alle
                .where((t) => ListenService.echteListe(t.listeId) == _liste)
                .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          drawer: ListenSchublade(
            gewaehlt: _liste,
            anzahl: _anzahl(alle),
            waehlen: (id) => setState(() => _liste = id),
          ),
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            title: Row(
              children: [
                if (_liste != null) ...[
                  Icon(Icons.circle,
                      size: 12, color: Color(ListenService.farbeOf(_liste))),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                      _liste == null
                          ? 'Todos'
                          : ListenService.nameOf(_liste),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            actions: const [FeedbackIconButton()],
          ),
          body: warten
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : todos.isEmpty
                  ? _EmptyState(
                      liste: _liste == null
                          ? null
                          : ListenService.nameOf(_liste),
                      onAdd: () => _openEdit(context),
                    )
                  : _rumpf(todos),
          floatingActionButton: FloatingActionButton(
            heroTag: 'todos_fab',
            onPressed: () => _openEdit(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _rumpf(List<Todo> todos) {
    return Column(
      children: [
        // Info-Banner
        Container(
          color: AppColors.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lange halten und in die Wochenansicht ziehen',
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: todos.length,
            itemBuilder: (ctx, i) {
              final todo = todos[i];
              return TodoCard(
                todo: todo,
                // Nur in der Gesamtschau: in einer offenen Liste steht der
                // Name schon im Titel, an jeder Karte waere er Laerm.
                zeigeListe: _liste == null,
                onTap: () async {
                  final result = await TodoStatusDialog.show(
                      context: context, todo: todo);
                  if (result == 'delete') {
                    await LocalService.deleteTodo(todo.id);
                    _refreshStream();
                  } else if (result == 'edit') {
                    if (!mounted) return;
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
  }

  Future<void> _openEdit(BuildContext context) async {
    await Navigator.push(
      context,
      // Neues landet in der offenen Liste: wer „Einkauf" aufhat, will
      // einkaufen, nicht in die Standardliste schreiben.
      MaterialPageRoute(builder: (_) => TodoEditScreen(listeId: _liste)),
    );
    _refreshStream();
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  /// Der Name der offenen Liste, oder `null` in der Gesamtschau.
  final String? liste;

  const _EmptyState({required this.onAdd, this.liste});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 64, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(
                liste == null
                    ? 'Keine offenen Todos'
                    : 'In „$liste" ist nichts offen',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Erstelle ein Todo und ziehe es in die Wochenansicht',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
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
      ),
    );
  }
}
