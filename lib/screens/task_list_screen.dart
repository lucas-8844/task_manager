import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/database_service.dart';

enum TaskFilter { all, completed, pending }

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _titleController = TextEditingController();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  List<Task> _tasks = [];
  List<Category> _categories = [];

  // formulário
  String _newPriority = 'medium';
  DateTime? _newDueDate;
  Category? _selectedCategory;

  // filtros
  TaskFilter _filter = TaskFilter.all;
  Category? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final tasks = await DatabaseService.instance.readAll();
    final cats  = await DatabaseService.instance.readAllCategories();
    setState(() {
      _tasks = tasks;
      _categories = cats;
      // Seleciona primeira categoria por padrão no form (opcional)
      _selectedCategory ??= _categories.isNotEmpty ? _categories.first : null;
    });
  }

  // ----------------- CRUD -----------------

  Future<void> _addTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final task = Task(
      title: title,
      priority: _newPriority,
      dueDate: _newDueDate,
      categoryId: _selectedCategory?.id,
    );
    await DatabaseService.instance.create(task);

    // atualiza local sem ler do DB (mais rápido)
    setState(() {
      _tasks.insert(0, task);
      _titleController.clear();
      _newPriority = 'medium';
      _newDueDate = null;
      // mantém categoria escolhida
    });
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    setState(() {
      final i = _tasks.indexWhere((t) => t.id == task.id);
      if (i != -1) _tasks[i] = updated;
    });
  }

  Future<void> _deleteTask(String id) async {
    await DatabaseService.instance.delete(id);
    setState(() {
      _tasks.removeWhere((t) => t.id == id);
    });
  }

  // ----------------- Helpers -----------------

  List<Task> get _filteredTasks {
    Iterable<Task> list = _tasks;
    switch (_filter) {
      case TaskFilter.completed:
        list = list.where((t) => t.completed);
        break;
      case TaskFilter.pending:
        list = list.where((t) => !t.completed);
        break;
      case TaskFilter.all:
      default:
        break;
    }
    if (_filterCategory != null) {
      list = list.where((t) => t.categoryId == _filterCategory!.id);
    }

    // mesma ordenação do DB por segurança
    final sorted = list.toList()
      ..sort((a, b) {
        // dueDate nulls por último
        final ad = a.dueDate;
        final bd = b.dueDate;
        if (ad == null && bd == null) {
          return b.createdAt.compareTo(a.createdAt); // createdAt desc
        } else if (ad == null) {
          return 1;
        } else if (bd == null) {
          return -1;
        }
        final cmp = ad.compareTo(bd);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted;
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

  Color _categoryColor(Category? c) =>
      c == null ? Colors.grey : Color(c.colorHex);

  bool _isOverdue(Task t) =>
      t.dueDate != null &&
      !t.completed &&
      t.dueDate!.isBefore(DateTime.now());

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Selecionar data de vencimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (picked != null) {
      setState(() => _newDueDate = picked);
    }
  }

  // ----------------- UI -----------------

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
          // --------- Formulário de criação ---------
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
                // Prioridade
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
                // Categoria
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<Category>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Categoria',
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: _categoryColor(c),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(c.name),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _selectedCategory = val;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                // Due date
                OutlinedButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _newDueDate == null
                        ? 'Vencimento'
                        : _dateFmt.format(_newDueDate!),
                  ),
                ),
                const SizedBox(width: 8),
                // Adicionar
                ElevatedButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
          ),

          // --------- Filtros ---------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Status
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

                // separador
                const SizedBox(width: 16),

                // Filtro por categoria
                DropdownButton<Category?>(
                  value: _filterCategory,
                  hint: const Text('Filtrar por categoria'),
                  items: [
                    const DropdownMenuItem<Category?>(
                      value: null,
                      child: Text('Todas as categorias'),
                    ),
                    ..._categories.map(
                      (c) => DropdownMenuItem<Category?>(
                        value: c,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _categoryColor(c),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(c.name),
                          ],
                        ),
                      ),
                    )
                  ],
                  onChanged: (val) => setState(() => _filterCategory = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // --------- Lista ---------
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                final cat = _categories
                    .firstWhere((c) => c.id == task.categoryId, orElse: () => Category(name: 'Sem categoria', colorHex: 0xFF9E9E9E));
                final overdue = _isOverdue(task);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.completed,
                      onChanged: (_) => _toggleTask(task),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.completed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (overdue) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
                        ],
                      ],
                    ),
                    subtitle: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // prioridade
                        Chip(
                          label: Text('Prioridade: ${_priorityLabel(task.priority)}'),
                          backgroundColor: _priorityColor(task.priority).withOpacity(0.12),
                          side: BorderSide(color: _priorityColor(task.priority)),
                          labelStyle: TextStyle(color: _priorityColor(task.priority)),
                          visualDensity: VisualDensity.compact,
                        ),
                        // categoria
                        Chip(
                          avatar: CircleAvatar(backgroundColor: _categoryColor(cat), radius: 6),
                          label: Text(cat.name),
                          visualDensity: VisualDensity.compact,
                        ),
                        // due date
                        if (task.dueDate != null)
                          Chip(
                            label: Text('Vence: ${_dateFmt.format(task.dueDate!)}'),
                            backgroundColor: overdue ? Colors.red.withOpacity(0.12) : null,
                            side: overdue ? const BorderSide(color: Colors.redAccent) : null,
                            labelStyle: TextStyle(color: overdue ? Colors.redAccent : null),
                            visualDensity: VisualDensity.compact,
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
