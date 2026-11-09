import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../core/browser_files.dart';
import '../../core/errors.dart';
import '../../core/storage_upload.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../media/media_repository.dart';
import '../media/media_rules.dart';
import 'lookups_repository.dart';

/// Locations, property types and amenities: the lists used by the property
/// form and the website filters.
class LookupsPage extends StatelessWidget {
  const LookupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: PageBody(
        maxWidth: 900,
        children: [
          PageHeader(
            title: 'Locations & lists',
            subtitle: 'Drag to change the order shown on the website. Inactive items are hidden from visitors.',
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Locations'),
              Tab(text: 'Property types'),
              Tab(text: 'Amenities'),
            ],
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 640,
            child: TabBarView(
              children: [_LocationsTab(), _TypesTab(), _AmenitiesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs a change, refreshes [provider], and reports the result.
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  ProviderOrFamily provider,
  Future<void> Function() action, {
  String? done,
}) async {
  try {
    await action();
    if (context.mounted && done != null) showMessage(context, done);
  } catch (error) {
    if (context.mounted) {
      showMessage(context, friendlyError(error), error: true);
    }
  } finally {
    ref.invalidate(provider);
  }
}

/// A card with a drag-to-reorder list.
class _ReorderCard<T> extends StatefulWidget {
  const _ReorderCard({
    required this.items,
    required this.itemKey,
    required this.tile,
    required this.onReorder,
    this.action,
    required this.emptyMessage,
  });

  final List<T> items;
  final Object Function(T item) itemKey;
  final Widget Function(T item) tile;
  final Future<void> Function(List<T> ordered) onReorder;
  final Widget? action;
  final String emptyMessage;

  @override
  State<_ReorderCard<T>> createState() => _ReorderCardState<T>();
}

class _ReorderCardState<T> extends State<_ReorderCard<T>> {
  late List<T> _items = widget.items;

  @override
  void didUpdateWidget(covariant _ReorderCard<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _items = widget.items;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.action != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: widget.action,
              ),
            ),
          if (_items.isEmpty)
            EmptyState(message: widget.emptyMessage)
          else
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                onReorderItem: (oldIndex, newIndex) {
                  final items = [..._items];
                  items.insert(newIndex, items.removeAt(oldIndex));
                  setState(() => _items = items);
                  widget.onReorder(items);
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Container(
                    key: ValueKey(widget.itemKey(item)),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: BrandColors.line),
                      ),
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            child: Icon(
                              Icons.drag_indicator,
                              color: BrandColors.sold,
                            ),
                          ),
                        ),
                        Expanded(child: widget.tile(item)),
                      ],
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

// ---------------------------------------------------------------------------
// Locations
// ---------------------------------------------------------------------------

class _LocationsTab extends ConsumerWidget {
  const _LocationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(lookupsRepositoryProvider);
    return AsyncValueView(
      value: ref.watch(locationsProvider),
      onRetry: () => ref.invalidate(locationsProvider),
      data: (locations) => _ReorderCard<Location>(
        items: locations,
        itemKey: (location) => location.id,
        emptyMessage:
            'No locations yet. Add the cities and towns where you sell land.',
        action: FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _LocationDialog(),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add location'),
        ),
        onReorder: (ordered) => _run(
          context,
          ref,
          locationsProvider,
          () => repository.reorder(
            'locations',
            [for (final l in ordered) l.id],
            {for (final l in locations) l.id: l.sortOrder},
          ),
        ),
        tile: (location) => ListTile(
          contentPadding: const EdgeInsets.only(right: 8),
          leading: _LocationCover(path: location.coverImagePath),
          title: Row(
            children: [
              Flexible(
                child: Text(location.city, overflow: TextOverflow.ellipsis),
              ),
              if (location.isPopular) ...[
                const SizedBox(width: 8),
                const Pill(label: 'Popular', color: BrandColors.sand),
              ],
              if (!location.isActive) ...[
                const SizedBox(width: 8),
                const Pill(label: 'Hidden', color: BrandColors.sold),
              ],
            ],
          ),
          subtitle: Text(
            '${location.district} district, ${location.state} · /${location.slug}',
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (action) async {
              switch (action) {
                case 'edit':
                  await showDialog<void>(
                    context: context,
                    builder: (_) => _LocationDialog(location: location),
                  );
                case 'cover':
                  await _setCover(context, ref, location);
                case 'remove_cover':
                  await _run(context, ref, locationsProvider, () async {
                    await repository.setLocationCover(location.id, null);
                    await ref.read(storageUploaderProvider).remove(
                      siteAssetsBucket,
                      [location.coverImagePath!],
                    );
                  }, done: 'Cover photo removed.');
                case 'popular':
                  await _run(
                    context,
                    ref,
                    locationsProvider,
                    () => repository.setLocationFlags(
                      location.id,
                      isPopular: !location.isPopular,
                    ),
                  );
                case 'active':
                  await _run(
                    context,
                    ref,
                    locationsProvider,
                    () => repository.setLocationFlags(
                      location.id,
                      isActive: !location.isActive,
                    ),
                    done: location.isActive
                        ? '${location.city} is hidden from the website.'
                        : '${location.city} is shown again.',
                  );
                case 'delete':
                  final ok = await confirmAction(
                    context,
                    title: 'Delete ${location.city}?',
                    message: 'Only possible when no property uses it. Otherwise hide it instead.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (ok && context.mounted) {
                    await _run(
                      context,
                      ref,
                      locationsProvider,
                      () => repository.deleteLocation(location.id),
                      done: '${location.city} deleted.',
                    );
                  }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'cover',
                child: Text(
                  location.coverImagePath == null
                      ? 'Add cover photo'
                      : 'Change cover photo',
                ),
              ),
              if (location.coverImagePath != null)
                const PopupMenuItem(
                  value: 'remove_cover',
                  child: Text('Remove cover photo'),
                ),
              PopupMenuItem(
                value: 'popular',
                child: Text(
                  location.isPopular
                      ? 'Remove from popular'
                      : 'Mark as popular',
                ),
              ),
              PopupMenuItem(
                value: 'active',
                child: Text(
                  location.isActive ? 'Hide from website' : 'Show on website',
                ),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks, shrinks (1600 px) and uploads a location's cover photo, then
/// removes the previous one.
Future<void> _setCover(
  BuildContext context,
  WidgetRef ref,
  Location location,
) async {
  final files = await pickFiles(accept: MediaKind.photo.accept);
  if (files.isEmpty || !context.mounted) return;
  final file = files.first;
  final problem = checkFile(
    MediaKind.photo,
    name: file.name,
    type: file.type,
    size: file.size,
  );
  if (problem != null) {
    showMessage(context, problem, error: true);
    return;
  }
  showMessage(context, 'Uploading cover photo…');
  final uploader = ref.read(storageUploaderProvider);
  await _run(context, ref, locationsProvider, () async {
    final photo = await shrinkPhotoTo(file, 1600);
    final path = 'locations/${location.id}/${randomId()}.${photo.extension}';
    await uploader.upload(
      bucket: siteAssetsBucket,
      path: path,
      body: photo.blob,
      contentType: photo.contentType,
    );
    try {
      await ref
          .read(lookupsRepositoryProvider)
          .setLocationCover(location.id, path);
    } catch (_) {
      await uploader.remove(siteAssetsBucket, [path]);
      rethrow;
    }
    if (location.coverImagePath != null) {
      await uploader.remove(siteAssetsBucket, [location.coverImagePath!]);
    }
  }, done: 'Cover photo saved for ${location.city}.');
}

class _LocationCover extends ConsumerWidget {
  const _LocationCover({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const size = 48.0;
    final placeholder = Container(
      width: size,
      height: size,
      color: BrandColors.line,
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: BrandColors.sold,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: path == null
          ? placeholder
          : Image.network(
              ref
                  .read(mediaRepositoryProvider)
                  .publicUrl(siteAssetsBucket, path!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class _LocationDialog extends ConsumerStatefulWidget {
  const _LocationDialog({this.location});

  final Location? location;

  @override
  ConsumerState<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends ConsumerState<_LocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _state = TextEditingController(
    text: widget.location?.state ?? 'Andhra Pradesh',
  );
  late final _district = TextEditingController(text: widget.location?.district);
  late final _city = TextEditingController(text: widget.location?.city);
  late final _slug = TextEditingController(text: widget.location?.slug);
  late final _description = TextEditingController(
    text: widget.location?.description,
  );
  late bool _popular = widget.location?.isPopular ?? false;
  late bool _active = widget.location?.isActive ?? true;
  late bool _slugTouched = widget.location != null;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_state, _district, _city, _slug, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(lookupsRepositoryProvider)
          .saveLocation(
            id: widget.location?.id,
            state: _state.text,
            district: _district.text,
            city: _city.text,
            slug: _slug.text,
            description: _description.text,
            isPopular: _popular,
            isActive: _active,
          );
      ref.invalidate(locationsProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? name(String? value, String field) =>
        Validators.required(value, field: field) ??
        ((value!.trim().length < 2)
            ? 'Too short.'
            : Validators.maxLength(value, 60));
    return AlertDialog(
      title: Text(
        widget.location == null
            ? 'Add location'
            : 'Edit ${widget.location!.city}',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: BrandColors.danger),
                    ),
                  ),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City or town'),
                  validator: (v) => name(v, 'City'),
                  onChanged: (value) {
                    if (!_slugTouched) _slug.text = slugify(value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _district,
                  decoration: const InputDecoration(labelText: 'District'),
                  validator: (v) => name(v, 'District'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _state,
                  decoration: const InputDecoration(labelText: 'State'),
                  validator: (v) => name(v, 'State'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slug,
                  decoration: const InputDecoration(
                    labelText: 'Web address',
                    prefixText: '/plots-for-sale/',
                    helperText: 'Lowercase letters, numbers and dashes.',
                  ),
                  onChanged: (_) => _slugTouched = true,
                  validator: (value) =>
                      RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(value ?? '')
                      ? null
                      : 'Use e.g. "visakhapatnam".',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Short description (optional)',
                  ),
                  maxLines: 3,
                  maxLength: 2000,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Popular location'),
                  subtitle: const Text('Shown on the home page'),
                  value: _popular,
                  onChanged: (value) => setState(() => _popular = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on website'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Property types
// ---------------------------------------------------------------------------

class _TypesTab extends ConsumerWidget {
  const _TypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(lookupsRepositoryProvider);
    return AsyncValueView(
      value: ref.watch(propertyTypesProvider),
      onRetry: () => ref.invalidate(propertyTypesProvider),
      data: (types) => _ReorderCard<PropertyType>(
        items: types,
        itemKey: (type) => type.id,
        emptyMessage: 'No property types.',
        onReorder: (ordered) => _run(
          context,
          ref,
          propertyTypesProvider,
          () => repository.reorder(
            'property_types',
            [for (final t in ordered) t.id],
            {for (final t in types) t.id: t.sortOrder},
          ),
        ),
        tile: (type) => ListTile(
          contentPadding: const EdgeInsets.only(right: 8),
          title: Text(type.name),
          subtitle: Text('Landing pages: /${type.seoSlug}-for-sale/…'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _TypeDialog(type: type),
                ),
              ),
              Tooltip(
                message: type.isActive
                    ? 'Shown on the website'
                    : 'Hidden from the website',
                child: Switch(
                  value: type.isActive,
                  onChanged: (active) => _run(
                    context,
                    ref,
                    propertyTypesProvider,
                    () => repository.setTypeActive(type.id, active: active),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeDialog extends ConsumerStatefulWidget {
  const _TypeDialog({required this.type});

  final PropertyType type;

  @override
  ConsumerState<_TypeDialog> createState() => _TypeDialogState();
}

class _TypeDialogState extends ConsumerState<_TypeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.type.name);
  late final _seoSlug = TextEditingController(text: widget.type.seoSlug);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _seoSlug.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(lookupsRepositoryProvider)
          .saveType(widget.type.id, name: _name.text, seoSlug: _seoSlug.text);
      ref.invalidate(propertyTypesProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      setState(() => _error = friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename property type'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: BrandColors.danger),
                ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    Validators.required(v, field: 'Name') ??
                    Validators.maxLength(v, 60),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _seoSlug,
                decoration: const InputDecoration(
                  labelText: 'Web address word',
                  suffixText: '-for-sale',
                  helperText: 'Changing it changes the landing page links.',
                ),
                validator: (value) =>
                    RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(value ?? '')
                    ? null
                    : 'Use e.g. "plots".',
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
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Amenities
// ---------------------------------------------------------------------------

class _AmenitiesTab extends ConsumerWidget {
  const _AmenitiesTab();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    Amenity? amenity,
  }) async {
    final controller = TextEditingController(text: amenity?.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(amenity == null ? 'Add amenity' : 'Rename amenity'),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Solar street lights',
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().length < 2 || !context.mounted) return;
    await _run(
      context,
      ref,
      amenitiesProvider,
      () => ref
          .read(lookupsRepositoryProvider)
          .saveAmenity(id: amenity?.id, name: name),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(lookupsRepositoryProvider);
    return AsyncValueView(
      value: ref.watch(amenitiesProvider),
      onRetry: () => ref.invalidate(amenitiesProvider),
      data: (amenities) => _ReorderCard<Amenity>(
        items: amenities,
        itemKey: (amenity) => amenity.id,
        emptyMessage: 'No amenities yet.',
        action: FilledButton.icon(
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add amenity'),
        ),
        onReorder: (ordered) => _run(
          context,
          ref,
          amenitiesProvider,
          () => repository.reorder(
            'amenities',
            [for (final a in ordered) a.id],
            {for (final a in amenities) a.id: a.sortOrder},
          ),
        ),
        tile: (amenity) => ListTile(
          contentPadding: const EdgeInsets.only(right: 8),
          title: Text(amenity.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(context, ref, amenity: amenity),
              ),
              IconButton(
                tooltip: 'Delete (only if no property uses it)',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Delete "${amenity.name}"?',
                    message: 'Only possible when no property uses it. Otherwise switch it off instead.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (ok && context.mounted) {
                    await _run(
                      context,
                      ref,
                      amenitiesProvider,
                      () => repository.deleteAmenity(amenity.id),
                    );
                  }
                },
              ),
              Tooltip(
                message: amenity.isActive
                    ? 'Offered in the property form'
                    : 'Switched off',
                child: Switch(
                  value: amenity.isActive,
                  onChanged: (active) => _run(
                    context,
                    ref,
                    amenitiesProvider,
                    () =>
                        repository.setAmenityActive(amenity.id, active: active),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
