import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../core/browser_files.dart';
import '../../core/errors.dart';
import '../../core/storage_upload.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import 'media_repository.dart';
import 'media_rules.dart';
import 'upload_progress.dart';

/// Documents of one property, stored in a private bucket. Private by
/// default (decision 19); a public document can be downloaded by visitors
/// from the property page (through a short-lived link, Phase 7).
class DocumentsManager extends ConsumerStatefulWidget {
  const DocumentsManager({
    super.key,
    required this.propertyId,
    required this.onChanged,
  });

  final String propertyId;
  final VoidCallback onChanged;

  @override
  ConsumerState<DocumentsManager> createState() => _DocumentsManagerState();
}

class _DocumentsManagerState extends ConsumerState<DocumentsManager> {
  UploadItem? _upload;
  bool _busy = false;

  MediaRepository get _repository => ref.read(mediaRepositoryProvider);
  StorageUploader get _uploader => ref.read(storageUploaderProvider);

  void _changed() {
    ref.invalidate(propertyDocumentsProvider(widget.propertyId));
    widget.onChanged();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && done != null) showMessage(context, done);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      _changed();
    }
  }

  Future<web.File?> _pick() async {
    final files = await pickFiles(accept: MediaKind.document.accept);
    if (files.isEmpty || !mounted) return null;
    final file = files.first;
    final problem = checkFile(
      MediaKind.document,
      name: file.name,
      type: file.type,
      size: file.size,
    );
    if (problem != null) {
      showMessage(context, problem, error: true);
      return null;
    }
    return file;
  }

  /// Uploads [file] with a progress row; returns the storage path, or null on failure.
  Future<String?> _send(web.File file) async {
    final item = UploadItem(name: file.name)..status = UploadStatus.uploading;
    setState(() => _upload = item);
    final type = file.type.isEmpty ? 'application/pdf' : file.type;
    final path =
        '${widget.propertyId}/${randomId()}.${extensionFor(file.name, type)}';
    try {
      await _uploader.upload(
        bucket: documentsBucket,
        path: path,
        body: file,
        contentType: type,
        cacheControl: 'private, max-age=0',
        onProgress: (fraction) {
          if (mounted) setState(() => item.progress = fraction);
        },
      );
      if (mounted) setState(() => _upload = null);
      return path;
    } catch (error) {
      if (mounted) {
        setState(() {
          item
            ..status = UploadStatus.failed
            ..error = friendlyError(error);
        });
      }
      return null;
    }
  }

  Future<void> _add() async {
    final file = await _pick();
    if (file == null || !mounted) return;
    final details = await showDialog<_DocumentDetails>(
      context: context,
      builder: (_) => _DetailsDialog(
        initial: _DocumentDetails(
          title: titleFromFileName(file.name),
          type: DocumentType.other,
          isPublic: false,
        ),
        askPublic: true,
      ),
    );
    if (details == null) return;
    final path = await _send(file);
    if (path == null) return;
    await _run(() async {
      try {
        await _repository.insertDocument({
          'property_id': widget.propertyId,
          'doc_type': details.type.value,
          'title': details.title,
          'storage_path': path,
          'mime_type': file.type.isEmpty ? 'application/pdf' : file.type,
          'size_bytes': file.size,
          'is_public': details.isPublic,
          'sort_order':
              (ref
                      .read(propertyDocumentsProvider(widget.propertyId))
                      .value
                      ?.length ??
                  0) +
              1,
        });
      } catch (_) {
        await _uploader.remove(documentsBucket, [path]);
        rethrow;
      }
    }, done: 'Document added (${details.isPublic ? 'public' : 'private'}).');
  }

  Future<void> _setPublic(PropertyDocument document, bool public) async {
    if (public) {
      final ok = await confirmAction(
        context,
        title: 'Make "${document.title}" public?',
        message:
            'Anyone viewing this property on the website will be able to download it. '
            'Never make title deeds or ID documents public.',
        confirmLabel: 'Make public',
      );
      if (!ok) return;
    }
    await _run(
      () => _repository.updateDocument(document.id, {'is_public': public}),
      done: public
          ? 'Visitors can now download it.'
          : 'The document is private again.',
    );
  }

  Future<void> _onAction(
    List<PropertyDocument> documents,
    int index,
    String action,
  ) async {
    final document = documents[index];
    switch (action) {
      case 'open':
        await _run(
          () async => openInNewTab(
            await _repository.documentLink(document.storagePath),
          ),
        );
      case 'edit':
        final details = await showDialog<_DocumentDetails>(
          context: context,
          builder: (_) => _DetailsDialog(
            initial: _DocumentDetails(
              title: document.title,
              type: document.type,
              isPublic: document.isPublic,
            ),
            askPublic: false,
          ),
        );
        if (details != null) {
          await _run(
            () => _repository.updateDocument(document.id, {
              'title': details.title,
              'doc_type': details.type.value,
            }),
            done: 'Saved.',
          );
        }
      case 'replace':
        final file = await _pick();
        if (file == null) return;
        final path = await _send(file);
        if (path == null) return;
        await _run(() async {
          try {
            await _repository.replaceDocumentFile(document, {
              'storage_path': path,
              'mime_type': file.type.isEmpty ? 'application/pdf' : file.type,
              'size_bytes': file.size,
            });
          } catch (_) {
            await _uploader.remove(documentsBucket, [path]);
            rethrow;
          }
        }, done: 'File replaced.');
      case 'up' || 'down':
        final ordered = [...documents];
        ordered.insert(
          action == 'up' ? index - 1 : index + 1,
          ordered.removeAt(index),
        );
        await _run(
          () => _repository.saveOrder(
            'property_documents',
            [for (final d in ordered) d.id],
            {for (final d in documents) d.id: d.sortOrder},
          ),
        );
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'Delete "${document.title}"?',
          message: 'The file is deleted for good.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok) {
          await _run(
            () => _repository.deleteDocument(document),
            done: 'Document deleted.',
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(propertyDocumentsProvider(widget.propertyId));
    return SectionCard(
      title: 'Documents',
      trailing: OutlinedButton.icon(
        onPressed: _busy || _upload?.status == UploadStatus.uploading
            ? null
            : _add,
        icon: const Icon(Icons.upload_file, size: 18),
        label: const Text('Upload document'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PDF, JPEG or PNG up to 20 MB. Documents are private unless you switch them to public.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_upload != null)
            UploadQueueView(
              items: [_upload!],
              onRetry: (_) => setState(() => _upload = null),
              onDismiss: (_) => setState(() => _upload = null),
            ),
          AsyncValueView(
            value: async,
            onRetry: () =>
                ref.invalidate(propertyDocumentsProvider(widget.propertyId)),
            data: (documents) => documents.isEmpty
                ? const EmptyState(
                    icon: Icons.description_outlined,
                    message: 'No documents.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < documents.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            documents[i].mimeType == 'application/pdf'
                                ? Icons.picture_as_pdf_outlined
                                : Icons.image_outlined,
                            color: BrandColors.forest,
                          ),
                          title: Text(documents[i].title),
                          subtitle: Text(
                            '${documents[i].type.label} · ${formatBytes(documents[i].sizeBytes)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Pill(
                                label: documents[i].isPublic
                                    ? 'Public'
                                    : 'Private',
                                color: documents[i].isPublic
                                    ? BrandColors.reserved
                                    : BrandColors.sold,
                              ),
                              Tooltip(
                                message: documents[i].isPublic
                                    ? 'Make private'
                                    : 'Make public',
                                child: Switch(
                                  value: documents[i].isPublic,
                                  onChanged: _busy
                                      ? null
                                      : (value) =>
                                            _setPublic(documents[i], value),
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Document actions',
                                enabled: !_busy,
                                onSelected: (action) =>
                                    _onAction(documents, i, action),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'open',
                                    child: Text('Open'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit title and type'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'replace',
                                    child: Text('Replace file'),
                                  ),
                                  if (i > 0)
                                    const PopupMenuItem(
                                      value: 'up',
                                      child: Text('Move up'),
                                    ),
                                  if (i < documents.length - 1)
                                    const PopupMenuItem(
                                      value: 'down',
                                      child: Text('Move down'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DocumentDetails {
  const _DocumentDetails({
    required this.title,
    required this.type,
    required this.isPublic,
  });

  final String title;
  final DocumentType type;
  final bool isPublic;
}

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({required this.initial, required this.askPublic});

  final _DocumentDetails initial;
  final bool askPublic;

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial.title);
  late DocumentType _type = widget.initial.type;
  late bool _public = widget.initial.isPublic;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.askPublic ? 'Document details' : 'Edit document'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Title shown to admins (and visitors if public)',
                ),
                validator: (value) =>
                    (value ?? '').trim().length < 2 ? 'Enter a title.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DocumentType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final t in DocumentType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? DocumentType.other),
              ),
              if (widget.askPublic)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public'),
                  subtitle: const Text(
                    'Visitors can download it from the property page.',
                  ),
                  value: _public,
                  onChanged: (value) => setState(() => _public = value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _DocumentDetails(
                title: _title.text.trim(),
                type: _type,
                isPublic: _public,
              ),
            );
          },
          child: Text(widget.askPublic ? 'Upload' : 'Save'),
        ),
      ],
    );
  }
}
