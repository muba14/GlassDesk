import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import 'notes_store.dart';

/// Yapışkan not + yapılacaklar listesi. Üstteki sekmelerle geçiş yapılır.
class NotesWidget extends StatefulWidget {
  const NotesWidget({
    super.key,
    required this.store,
    this.initialTab = 0,
    this.headerWrapper,
  });

  final NotesStore store;
  final int initialTab;

  /// Başlık satırını sarmak için (ör. pencereyi sürükleme alanı).
  final Widget Function(Widget header)? headerWrapper;

  @override
  State<NotesWidget> createState() => _NotesWidgetState();
}

class _NotesWidgetState extends State<NotesWidget> {
  late int _tab = widget.initialTab;
  late final _noteController = TextEditingController(text: widget.store.note);
  final _todoController = TextEditingController();
  final _todoFocus = FocusNode();
  Timer? _saveDebounce;

  NotesStore get _store => widget.store;

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _store.note = _noteController.text;
    _store.save();
    _noteController.dispose();
    _todoController.dispose();
    _todoFocus.dispose();
    super.dispose();
  }

  void _onNoteChanged(String text) {
    _store.note = text;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _store.save);
  }

  void _addTodo() {
    setState(() => _store.add(_todoController.text));
    _todoController.clear();
    _todoFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        _TabChip(
          label: 'Not',
          icon: Icons.edit_note_rounded,
          selected: _tab == 0,
          onTap: () => setState(() => _tab = 0),
        ),
        const SizedBox(width: 6),
        _TabChip(
          label: 'Yapılacaklar ${_store.doneCount}/${_store.todos.length}',
          icon: Icons.checklist_rounded,
          selected: _tab == 1,
          onTap: () => setState(() => _tab = 1),
        ),
        const Expanded(child: SizedBox(height: 28)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.headerWrapper?.call(header) ?? header,
        const SizedBox(height: 10),
        Expanded(child: _tab == 0 ? _buildNote() : _buildTodos()),
      ],
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE27A).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFFE27A).withValues(alpha: 0.25),
        ),
      ),
      child: TextField(
        controller: _noteController,
        onChanged: _onNoteChanged,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontSize: 14, height: 1.45),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Aklındakini buraya yaz…',
          hintStyle: TextStyle(color: GlassColors.soft(0.35)),
        ),
      ),
    );
  }

  Widget _buildTodos() {
    final todos = _store.todos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _todoController,
                focusNode: _todoFocus,
                onSubmitted: (_) => _addTodo(),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Yeni görev ekle…',
                  hintStyle: TextStyle(color: GlassColors.soft(0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: GlassColors.accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _addTodo,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.add_rounded,
                      size: 20, color: Color(0xFF15132A)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: todos.isEmpty
              ? Center(
                  child: Text(
                    'Henüz görev yok',
                    style: TextStyle(fontSize: 13, color: GlassColors.soft(0.45)),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: todos.length,
                  itemBuilder: (context, i) => _TodoTile(
                    item: todos[i],
                    onToggle: () => setState(() => _store.toggle(i)),
                    onDelete: () => setState(() => _store.remove(i)),
                  ),
                ),
        ),
        if (_store.doneCount > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(_store.clearDone),
              icon: const Icon(Icons.cleaning_services_rounded, size: 14),
              label: const Text('Tamamlananları temizle',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: GlassColors.soft(0.7),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
      ],
    );
  }
}

class _TodoTile extends StatefulWidget {
  const _TodoTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<_TodoTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final done = widget.item.done;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: done
                      ? const LinearGradient(
                          colors: [GlassColors.accent, GlassColors.accent2],
                        )
                      : null,
                  border: done
                      ? null
                      : Border.all(color: GlassColors.soft(0.5), width: 1.5),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Color(0xFF15132A))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: done ? GlassColors.soft(0.4) : Colors.white,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: GlassColors.soft(0.4),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hover ? 1 : 0,
                child: InkResponse(
                  onTap: widget.onDelete,
                  radius: 14,
                  child: Icon(Icons.close_rounded,
                      size: 16, color: GlassColors.soft(0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? GlassColors.accent2 : GlassColors.soft(0.6)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : GlassColors.soft(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
