import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/browser.dart';
import '../../core/config/env.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import 'content_image_field.dart';
import 'content_models.dart';
import 'content_repository.dart';

/// Opens the website's private preview of [page] (drafts shown).
Future<void> openContentPreview(
  BuildContext context,
  WidgetRef ref,
  String page,
) async {
  try {
    final token = await ref.read(contentRepositoryProvider).previewToken();
    openLink('${Env.websiteUrl}/preview/$page?token=$token');
  } catch (error) {
    if (context.mounted) {
      showMessage(context, friendlyError(error), error: true);
    }
  }
}

/// One page section: its fields and list, with Save draft / Preview /
/// Publish / Discard. Drafts never show on the website until published.
class BlockEditor extends ConsumerStatefulWidget {
  const BlockEditor({super.key, required this.spec, required this.block});

  final BlockSpec spec;
  final ContentBlock block;

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  late Map<String, dynamic> _value = deepCopy(widget.block.current);
  // Bumped whenever fields must be rebuilt from _value (move, remove, reload).
  int _version = 0;
  bool _dirty = false;
  bool _busy = false;

  BlockSpec get spec => widget.spec;

  @override
  void didUpdateWidget(covariant BlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && oldWidget.block != widget.block) {
      _value = deepCopy(widget.block.current);
      _version++;
    }
  }

  void _changed(VoidCallback change, {bool rebuild = false}) {
    setState(() {
      change();
      _dirty = true;
      if (rebuild) _version++;
    });
  }

  List<dynamic> get _items =>
      ((_value[spec.listKey] as List?) ?? const []).toList();

  Future<bool> _save() async {
    final problem = checkBlock(spec, _value);
    if (problem != null) {
      showMessage(context, problem, error: true);
      return false;
    }
    await ref.read(contentRepositoryProvider).saveDraft(spec.key, _value);
    setState(() => _dirty = false);
    ref.invalidate(contentBlocksProvider);
    return true;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showMessage(context, done);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final textTheme = Theme.of(context).textTheme;
    final (label, color) = _dirty
        ? ('Not saved yet', BrandColors.danger)
        : block.hasDraft
        ? ('Unpublished changes', BrandColors.reserved)
        : ('Published ${formatDate(block.publishedAt)}', BrandColors.available);

    return SectionCard(
      title: spec.title,
      trailing: Pill(label: label, color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(spec.description, style: textTheme.bodySmall),
          const SizedBox(height: 16),
          for (final field in spec.fields) ...[
            _field(field, _value, (v) => _changed(() => _value[field.key] = v)),
            const SizedBox(height: 12),
          ],
          if (spec.listKey != null) _list(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy || !_dirty
                    ? null
                    : () => _run(() async => await _save(), 'Draft saved.'),
                child: const Text('Save draft'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (_dirty && !await _save()) return;
                        if (context.mounted) {
                          await openContentPreview(
                            context,
                            ref,
                            spec.previewPage,
                          );
                        }
                      },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview'),
              ),
              FilledButton(
                onPressed: _busy || (!_dirty && !block.hasDraft)
                    ? null
                    : () async {
                        final ok = await confirmAction(
                          context,
                          title: 'Publish "${spec.title}"?',
                          message:
                              'Visitors see the new text within a few seconds.',
                          confirmLabel: 'Publish',
                        );
                        if (!ok) return;
                        await _run(() async {
                          if (_dirty && !await _save()) return;
                          await ref
                              .read(contentRepositoryProvider)
                              .publish(spec.key);
                          ref.invalidate(contentBlocksProvider);
                        }, 'Published.');
                      },
                child: const Text('Publish'),
              ),
              if (_dirty || block.hasDraft)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await confirmAction(
                            context,
                            title: 'Discard the changes?',
                            message: 'The published text stays as it is.',
                            confirmLabel: 'Discard',
                            destructive: true,
                          );
                          if (!ok) return;
                          await _run(() async {
                            await ref
                                .read(contentRepositoryProvider)
                                .discard(spec.key);
                            setState(() {
                              _dirty = false;
                              _value = deepCopy(block.published);
                              _version++;
                            });
                            ref.invalidate(contentBlocksProvider);
                          }, 'Changes discarded.');
                        },
                  child: const Text('Discard changes'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final items = _items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          spec.listLabel ?? 'Items',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            decoration: BoxDecoration(
              border: Border.all(color: BrandColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: spec.stringItems
                      ? TextFormField(
                          key: ValueKey('${spec.key}-$i-$_version'),
                          initialValue: items[i] as String,
                          maxLength: 200,
                          decoration: InputDecoration(
                            labelText: '${_cap(spec.itemLabel)} ${i + 1}',
                          ),
                          onChanged: (v) => _changed(() {
                            final list = _items..[i] = v;
                            _value[spec.listKey!] = list;
                          }),
                        )
                      : Column(
                          children: [
                            for (final field in spec.itemFields) ...[
                              _field(
                                field,
                                (items[i] as Map).cast<String, dynamic>(),
                                (v) => _changed(() {
                                  final list = _items;
                                  list[i] = {
                                    ...(list[i] as Map).cast<String, dynamic>(),
                                    field.key: v,
                                  };
                                  _value[spec.listKey!] = list;
                                }),
                                keySuffix: '$i',
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                ),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: i == 0
                          ? null
                          : () => _changed(
                              () => _value[spec.listKey!] = moveItem(
                                items,
                                i,
                                i - 1,
                              ),
                              rebuild: true,
                            ),
                      icon: const Icon(Icons.arrow_upward, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed: i == items.length - 1
                          ? null
                          : () => _changed(
                              () => _value[spec.listKey!] = moveItem(
                                items,
                                i,
                                i + 1,
                              ),
                              rebuild: true,
                            ),
                      icon: const Icon(Icons.arrow_downward, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Remove ${spec.itemLabel}',
                      onPressed: items.length <= spec.minItems
                          ? null
                          : () => _changed(
                              () =>
                                  _value[spec.listKey!] = [...items]
                                    ..removeAt(i),
                              rebuild: true,
                            ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (items.length < spec.maxItems)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _changed(
                () => _value[spec.listKey!] = [...items, newItem(spec)],
                rebuild: true,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text('Add ${spec.itemLabel}'),
            ),
          ),
      ],
    );
  }

  Widget _field(
    FieldSpec field,
    Map<String, dynamic> source,
    ValueChanged<Object?> onChanged, {
    String keySuffix = '',
  }) {
    final key = ValueKey('${spec.key}-${field.key}-$keySuffix-$_version');
    switch (field.kind) {
      case FieldKind.image:
        return ContentImageField(
          key: key,
          label: field.label,
          path: source[field.key] as String?,
          folder: spec.key.replaceAll('.', '-'),
          onChanged: onChanged,
        );
      case FieldKind.toggle:
        return SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.hint == null ? null : Text(field.hint!),
          value: source[field.key] == true,
          onChanged: onChanged,
        );
      case FieldKind.icon:
        final current = source[field.key] as String?;
        return DropdownButtonFormField<String>(
          key: key,
          initialValue: contentIcons.containsKey(current) ? current : 'badge',
          decoration: InputDecoration(labelText: field.label),
          items: [
            for (final entry in contentIcons.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        );
      case FieldKind.text:
      case FieldKind.multiline:
        final multiline = field.kind == FieldKind.multiline;
        return TextFormField(
          key: key,
          initialValue: (source[field.key] as String?) ?? '',
          maxLength: field.maxLength,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 10 : 1,
          decoration: InputDecoration(
            labelText: field.required ? '${field.label} *' : field.label,
            alignLabelWithHint: multiline,
            helperText: multiline
                ? 'Leave a blank line between paragraphs.'
                : null,
          ),
          onChanged: onChanged,
        );
    }
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
