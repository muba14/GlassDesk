import '../../storage.dart';

class TodoItem {
  TodoItem(this.text, {this.done = false});

  String text;
  bool done;

  Map<String, dynamic> toJson() => {'t': text, 'd': done};

  static TodoItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = json['t'];
    if (text is! String) return null;
    return TodoItem(text, done: json['d'] == true);
  }
}

/// Notu ve yapılacaklar listesini `notes.json` içinde saklar.
class NotesStore {
  NotesStore({JsonFile? file, this.note = '', List<TodoItem>? todos})
      : _file = file,
        todos = todos ?? <TodoItem>[];

  factory NotesStore.load(JsonFile file) {
    final json = file.read();
    final todos = <TodoItem>[];
    final list = json['todos'];
    if (list is List) {
      for (final item in list) {
        final todo = TodoItem.fromJson(item);
        if (todo != null) todos.add(todo);
      }
    }
    return NotesStore(
      file: file,
      note: json['note'] is String ? json['note'] as String : '',
      todos: todos,
    );
  }

  final JsonFile? _file;
  String note;
  final List<TodoItem> todos;

  int get doneCount => todos.where((t) => t.done).length;

  void save() {
    _file?.write({
      'note': note,
      'todos': [for (final t in todos) t.toJson()],
    });
  }

  void add(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    todos.add(TodoItem(t));
    save();
  }

  void toggle(int index) {
    todos[index].done = !todos[index].done;
    save();
  }

  void remove(int index) {
    todos.removeAt(index);
    save();
  }

  void clearDone() {
    todos.removeWhere((t) => t.done);
    save();
  }
}
