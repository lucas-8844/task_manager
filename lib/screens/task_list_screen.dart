import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';

enum TaskFilter { all, completed, pending }

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  final _titleController = TextEditingController();

  // Novo: prioridade escolhida no formulário
  String _newPriority = 'medium';

  // Novo: filtro atual
  TaskFilter _filter = TaskFilter.all;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Carrega as tarefas do banco
  Future<void> _loadTasks() async {
    final tasks = await DatabaseService.instance.readAll();
    setState(() => _tasks = tasks);
  }

  // Adiciona nova tarefa (com prioridade)
  Future<void> _addTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final task = Task(title: title, priority: _newPriority);
    await DatabaseService.instance.create(task);

    _titleController.clear();
    _newPriority = 'medium';
    await _loadTasks();
  }

  // Marca tarefa como concluída/não concluída
  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    await _loadTasks();
  }

  // Deleta uma tarefa
  Future<void> _deleteTask(String id) async {
    await DatabaseService.instance.delete(id);
    await _loadTasks();
  }

  // ----------- Helpers de UI/contagem/filtro -----------

  List<Task> get _filteredTasks {
    switch (_filter) {
      case TaskFilter.completed:
        return _tasks.where((t) => t.completed).toList();
      case TaskFilter.pending:
        return _tasks.where((t) => !t.completed).toList();
      case TaskFilter.all:
      default:
        return _tasks;
    }
  }

  int get _totalCount => _tasks.length;
  int get _doneCount => _tasks.where((t) => t.completed).length;
  int get _pendingCount => _totalCount - _doneCount;

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.redAccent;
      case 'low':
        return Colors.green;
      case 'medium':
      default:
        return Colors.amber.shade700;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'Alta';
      case 'low':
        return 'Baixa';
      case 'medium':
      default:
        return 'Média';
    }
  }

  String _filterLabel(TaskFilter f) {
    switch (f) {
      case TaskFilter.all:
        return 'Todas';
      case TaskFilter.completed:
        return 'Completas';
      case TaskFilter.pending:
        return 'Pendentes';
    }
  }

  // -----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Total: $_totalCount • Feitas: $_doneCount • Pendentes: $_pendingCount',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Formulário: título + dropdown de prioridade + botão adicionar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Título
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Nova tarefa...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown de prioridade
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _newPriority,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Prioridade',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Baixa')),
                      DropdownMenuItem(value: 'medium', child: Text('Média')),
                      DropdownMenuItem(value: 'high', child: Text('Alta')),
                    ],
                    onChanged: (val) => setState(() {
                      _newPriority = val ?? 'medium';
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                // Botão adicionar
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Adicionar'),
                ),
              ],
            ),
          ),

          // Filtro por status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(_filterLabel(TaskFilter.all)),
                  selected: _filter == TaskFilter.all,
                  onSelected: (_) => setState(() => _filter = TaskFilter.all),
                ),
                ChoiceChip(
                  label: Text(_filterLabel(TaskFilter.completed)),
                  selected: _filter == TaskFilter.completed,
                  onSelected: (_) =>
                      setState(() => _filter = TaskFilter.completed),
                ),
                ChoiceChip(
                  label: Text(_filterLabel(TaskFilter.pending)),
                  selected: _filter == TaskFilter.pending,
                  onSelected: (_) =>
                      setState(() => _filter = TaskFilter.pending),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Lista filtrada
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.completed,
                      onChanged: (_) => _toggleTask(task),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration:
                            task.completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _priorityColor(task.priority).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _priorityColor(task.priority),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Prioridade: ${_priorityLabel(task.priority)}',
                            style: TextStyle(
                              color: _priorityColor(task.priority),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteTask(task.id),
                      tooltip: 'Excluir',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
