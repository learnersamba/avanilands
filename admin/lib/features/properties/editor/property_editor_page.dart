import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/browser.dart';
import '../../../core/errors.dart';
import '../../../core/formatting.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../../activity/activity_tile.dart';
import '../../admins/admins_repository.dart';
import '../../bookings/booking_models.dart';
import '../../bookings/bookings_page.dart';
import '../../bookings/bookings_repository.dart';
import '../../enquiries/enquiries_page.dart';
import '../../enquiries/enquiries_repository.dart';
import '../../enquiries/enquiry_models.dart';
import '../../site_visits/site_visit_models.dart';
import '../../site_visits/site_visits_page.dart';
import '../../site_visits/site_visits_repository.dart';
import '../../lookups/lookups_repository.dart';
import '../../media/documents_manager.dart';
import '../../media/photos_manager.dart';
import '../../media/videos_manager.dart';
import '../properties_repository.dart';
import '../property_actions.dart';
import '../property_enums.dart';
import '../property_models.dart';
import 'editor_sections.dart';
import 'property_form.dart';

/// Create (`id == null`) or edit a property.
class PropertyEditorPage extends ConsumerWidget {
  const PropertyEditorPage({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) return const _Editor(detail: null);
    final detail = ref.watch(propertyDetailProvider(id!));
    // Keep showing the form while it reloads after a save.
    if (detail.hasValue) {
      return _Editor(key: ValueKey(id), detail: detail.value);
    }
    if (detail.hasError) {
      return PageBody(
        children: [
          ErrorView(
            error: detail.error!,
            onRetry: () => ref.invalidate(propertyDetailProvider(id!)),
          ),
          TextButton(
            onPressed: () => context.go('/properties'),
            child: const Text('Back to properties'),
          ),
        ],
      );
    }
    return const LoadingView();
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.detail});

  final PropertyDetail? detail;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _formKey = GlobalKey<FormState>();
  final _form = PropertyFormController();
  final _sectionKeys = {
    for (final name in ['Basic', 'Location', 'Size & price', 'Photos'])
      name: GlobalKey(),
  };
  bool _saving = false;

  PropertyDetail? get _detail => widget.detail;
  bool get _isNew => _detail == null;

  @override
  void initState() {
    super.initState();
    _form.load(_detail);
  }

  @override
  void didUpdateWidget(covariant _Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fresh data after a save or a status change: show it unless the admin
    // is in the middle of editing.
    if (!identical(oldWidget.detail, widget.detail) && !_form.dirty) {
      _form.load(widget.detail);
    }
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _refresh() {
    final id = _detail?.id;
    if (id == null) return;
    ref
      ..invalidate(propertyDetailProvider(id))
      ..invalidate(propertyHistoryProvider(id));
  }

  Future<bool> _save() async {
    if (!_formKey.currentState!.validate()) {
      showMessage(
        context,
        'Some fields need attention (marked in red).',
        error: true,
      );
      return false;
    }
    setState(() => _saving = true);
    final repository = ref.read(propertiesRepositoryProvider);
    try {
      final fields = _form.collect();
      final nearby = _form.collectNearby();
      if (_isNew) {
        final id = await repository.create(fields);
        await repository.saveAmenities(id, const {}, _form.amenityIds);
        await repository.saveNearby(id, const [], nearby);
        _form.markSaved();
        if (!mounted) return true;
        showMessage(context, 'Draft saved.');
        context.go('/properties/$id');
      } else {
        final id = _detail!.id;
        await repository.update(id, fields);
        await repository.saveAmenities(
          id,
          _form.savedAmenityIds,
          _form.amenityIds,
        );
        await repository.saveNearby(id, _form.savedNearby, nearby);
        _form.markSaved();
        _refresh();
        if (mounted) showMessage(context, 'Changes saved.');
      }
      return true;
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Status changes act on the saved property, so unsaved edits go first.
  Future<void> _statusChange(Future<bool> Function() action) async {
    if (_form.dirty) {
      final save = await confirmAction(
        context,
        title: 'Save your changes first?',
        message: 'You have unsaved changes. They will be saved before the status changes.',
        confirmLabel: 'Save and continue',
      );
      if (!save || !await _save()) return;
    }
    if (await action()) _refresh();
  }

  void _jump(String section) {
    final target = _sectionKeys[section]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.02,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(propertyTypesProvider).value ?? const [];
    final locations = ref.watch(locationsProvider).value ?? const [];
    final amenities = ref.watch(amenitiesProvider).value ?? const [];
    final wide = MediaQuery.sizeOf(context).width >= 1200;

    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) {
        final detail = _detail;
        final fields = detail?.fields;
        final complete =
            fields != null && fields.publishState != PublishState.draft;
        final sections = <Widget>[
          _keyed('Basic', BasicSection(form: _form, types: types)),
          _keyed(
            'Location',
            LocationSection(form: _form, locations: locations),
          ),
          _keyed(
            'Size & price',
            SizePriceSection(form: _form, complete: complete),
          ),
          _keyed(
            'Photos',
            detail == null
                ? _PhotosLater(saving: _saving, onSave: _save)
                : PhotosManager(
                    key: _photosKey,
                    propertyId: detail.id,
                    onChanged: _refresh,
                  ),
          ),
          const _Divider(
            title: 'More details',
            subtitle: 'Optional. Add these now or later; buyers see them on the website.',
          ),
          DetailsSection(form: _form),
          LegalSection(form: _form),
          HighlightsSection(form: _form, amenities: amenities),
          NearbySection(form: _form),
          if (detail != null) _media(detail.id),
          NotesSection(form: _form),
          SeoSection(form: _form, everPublished: fields?.publishedAt != null),
          if (detail != null) ...[
            const _Divider(
              title: 'Activity',
              subtitle: 'Enquiries, visits and bookings for this property.',
            ),
            _EnquiriesSection(propertyId: detail.id),
            _SiteVisitsSection(propertyId: detail.id),
            _BookingsSection(propertyId: detail.id),
            _HistorySection(propertyId: detail.id, code: detail.code),
          ],
        ];
        final panel = _SidePanel(
          form: _form,
          detail: detail,
          saving: _saving,
          onSave: _save,
          onStatus: _statusChange,
          onJump: _jump,
        );

        return Stack(
          children: [
            Form(
              key: _formKey,
              child: PageBody(
                maxWidth: 1400,
                children: [
                  _Header(
                    detail: detail,
                    form: _form,
                    saving: _saving,
                    onSave: _save,
                  ),
                  const SizedBox(height: 8),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            key: ValueKey(_form.loads),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _spaced(sections),
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(width: 340, child: panel),
                      ],
                    )
                  else ...[
                    panel,
                    const SizedBox(height: 24),
                    Column(
                      key: ValueKey(_form.loads),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _spaced(sections),
                    ),
                  ],
                  // Room for the floating save bar.
                  const SizedBox(height: 96),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: IgnorePointer(
                ignoring: !_form.dirty,
                child: AnimatedSlide(
                  offset: _form.dirty ? Offset.zero : const Offset(0, 2),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Center(
                    child: _SaveBar(
                      isNew: detail == null,
                      saving: _saving,
                      onSave: _save,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Media managers keep their upload queues while the form reloads, so they
  // hold on to their state with global keys.
  final _photosKey = GlobalKey();
  final _videosKey = GlobalKey();
  final _documentsKey = GlobalKey();

  Widget _media(String propertyId) => OptionalPanel(
    icon: Icons.video_library_outlined,
    title: 'Videos and documents',
    subtitle: 'YouTube walkthroughs, layout plans and approval copies.',
    child: Theme(
      // The managers draw their own cards; flatten them inside the panel.
      data: Theme.of(context).copyWith(
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: BrandColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VideosManager(
            key: _videosKey,
            propertyId: propertyId,
            onChanged: _refresh,
          ),
          const SizedBox(height: 16),
          DocumentsManager(
            key: _documentsKey,
            propertyId: propertyId,
            onChanged: _refresh,
          ),
        ],
      ),
    ),
  );

  Widget _keyed(String name, Widget child) =>
      KeyedSubtree(key: _sectionKeys[name], child: child);

  static List<Widget> _spaced(List<Widget> children) => [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) const SizedBox(height: 20),
      children[i],
    ],
  ];
}

class _Header extends StatelessWidget {
  const _Header({
    required this.detail,
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final PropertyDetail? detail;
  final PropertyFormController form;
  final bool saving;
  final Future<bool> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final fields = detail?.fields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/properties'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Properties'),
        ),
        PageHeader(
          title: detail == null
              ? 'New property'
              : '${detail!.code} · ${fields!.title}',
          subtitle: detail == null
              ? 'Saved as a draft. Nothing is shown on the website until you publish.'
              : 'Last saved ${fields!.updatedAt == null ? '—' : formatDateTime(fields.updatedAt!)}',
          actions: [
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(
                saving
                    ? 'Saving…'
                    : (detail == null ? 'Save draft' : 'Save changes'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SidePanel extends ConsumerWidget {
  const _SidePanel({
    required this.form,
    required this.detail,
    required this.saving,
    required this.onSave,
    required this.onStatus,
    required this.onJump,
  });

  final PropertyFormController form;
  final PropertyDetail? detail;
  final bool saving;
  final Future<bool> Function() onSave;
  final Future<void> Function(Future<bool> Function() action) onStatus;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = this.detail;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail != null) ...[
          SectionCard(
            title: 'Status',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PropertyStatusPills(
                  state: detail.fields.publishState,
                  availability: detail.fields.availability,
                ),
                const SizedBox(height: 16),
                for (final target in publishTargets(
                  detail.fields.publishState,
                )) ...[
                  OutlinedButton(
                    // Publishing is refused by the database until the
                    // checklist below is complete, so don't offer it yet.
                    onPressed:
                        saving ||
                            (target == PublishState.published &&
                                publishBlockers(
                                  detail.fields,
                                  hasCover: detail.hasCover,
                                ).isNotEmpty)
                        ? null
                        : () => onStatus(
                            () => changePublishState(
                              context,
                              ref,
                              id: detail.id,
                              code: detail.code,
                              from: detail.fields.publishState,
                              to: target,
                            ),
                          ),
                    child: Text(
                      publishActionLabel(detail.fields.publishState, target),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (detail.fields.publishState != PublishState.archived) ...[
                  const SizedBox(height: 8),
                  Text('Availability', style: textTheme.bodySmall),
                  const SizedBox(height: 6),
                  SegmentedButton<Availability>(
                    showSelectedIcon: false,
                    segments: [
                      for (final a in Availability.values)
                        ButtonSegment(value: a, label: Text(a.label)),
                    ],
                    selected: {detail.fields.availability},
                    onSelectionChanged: saving
                        ? null
                        : (value) => onStatus(
                            () => changeAvailability(
                              context,
                              ref,
                              id: detail.id,
                              code: detail.code,
                              from: detail.fields.availability,
                              to: value.first,
                            ),
                          ),
                  ),
                ],
                if (detail.fields.publishState == PublishState.published &&
                    detail.fields.slug != null) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => openOnWebsite(detail.fields.slug!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View on website'),
                  ),
                ],
                if (detail.fields.publishState == PublishState.draft) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.danger,
                    ),
                    onPressed: () async {
                      if (await deleteDraft(
                        context,
                        ref,
                        id: detail.id,
                        code: detail.code,
                      )) {
                        form.markSaved();
                        if (context.mounted) context.go('/properties');
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete draft'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        ListenableBuilder(
          listenable: form.checklistInputs,
          builder: (context, _) => _Checklist(
            fields: form.collect(),
            hasCover: detail?.hasCover ?? false,
            onJump: onJump,
          ),
        ),
        const SizedBox(height: 24),
        SectionCard(
          title: 'Featured',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show on the home page'),
                subtitle: const Text('In the "Featured" row.'),
                value: form.isFeatured,
                onChanged: (value) => form.set(() => form.isFeatured = value),
              ),
              Text('Saved with the other changes.', style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// What publishing needs, as a progress card. Tapping an item jumps to it.
class _Checklist extends StatelessWidget {
  const _Checklist({
    required this.fields,
    required this.hasCover,
    required this.onJump,
  });

  final PropertyFields fields;
  final bool hasCover;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Title', fields.title.trim().length >= 5, 'Basic'),
      ('Property type', fields.propertyTypeId != null, 'Basic'),
      ('City / town', fields.locationId != null, 'Location'),
      ('Area', (fields.areaValue ?? 0) > 0, 'Size & price'),
      (
        'Price',
        fields.priceType == PriceType.onRequest || (fields.price ?? 0) > 0,
        'Size & price',
      ),
      ('Cover photo', hasCover, 'Photos'),
    ];
    final done = items.where((item) => item.$2).length;
    final ready = done == items.length;
    return SectionCard(
      title: ready ? 'Ready to publish' : 'Ready to publish?',
      trailing: Text(
        '$done of ${items.length}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: ready ? BrandColors.available : BrandColors.muted,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: done / items.length),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: BrandColors.cream,
                color: ready ? BrandColors.available : BrandColors.sand,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final (label, isDone, section) in items)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onJump(section),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: isDone ? BrandColors.available : BrandColors.line,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isDone ? BrandColors.muted : BrandColors.text,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: BrandColors.muted,
                        ),
                      ),
                    ),
                    if (!isDone)
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: BrandColors.muted,
                      ),
                  ],
                ),
              ),
            ),
          if (ready) ...[
            const SizedBox(height: 8),
            const Text(
              'Everything needed is filled in.',
              style: TextStyle(fontSize: 12, color: BrandColors.available),
            ),
          ],
        ],
      ),
    );
  }
}

/// Splits the required steps from the optional extras.
class _Divider extends StatelessWidget {
  const _Divider({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, left: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: BrandColors.muted)),
      ],
    ),
  );
}

/// Step 4 before the first save: photos need a property to belong to.
class _PhotosLater extends StatelessWidget {
  const _PhotosLater({required this.saving, required this.onSave});

  final bool saving;
  final Future<bool> Function() onSave;

  @override
  Widget build(BuildContext context) => EditorStep(
    number: 4,
    title: 'Photos',
    subtitle: 'At least one photo. The first one is the cover.',
    done: () => false,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: BrandColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            size: 36,
            color: BrandColors.forest,
          ),
          const SizedBox(height: 10),
          const Text(
            'Save the draft first, then add photos here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save draft and add photos'),
          ),
        ],
      ),
    ),
  );
}

/// Floats at the bottom while there are unsaved changes.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isNew,
    required this.saving,
    required this.onSave,
  });

  final bool isNew;
  final bool saving;
  final Future<bool> Function() onSave;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
    decoration: BoxDecoration(
      color: BrandColors.forestDark,
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33163A2B),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        const Text(
          'You have unsaved changes',
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: BrandColors.sand,
            foregroundColor: BrandColors.forestDark,
            shape: const StadiumBorder(),
          ),
          onPressed: saving ? null : onSave,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(
            saving ? 'Saving…' : (isNew ? 'Save draft' : 'Save changes'),
          ),
        ),
      ],
    ),
  );
}

class _EnquiriesSection extends ConsumerWidget {
  const _EnquiriesSection({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Enquiries',
      trailing: TextButton(
        onPressed: () =>
            context.go(EnquiryQuery(propertyId: propertyId).location),
        child: const Text('View all'),
      ),
      child: AsyncValueView(
        value: ref.watch(propertyEnquiriesProvider(propertyId)),
        onRetry: () => ref.invalidate(propertyEnquiriesProvider(propertyId)),
        data: (enquiries) => enquiries.isEmpty
            ? const EmptyState(message: 'No enquiries for this property yet.')
            : Column(
                children: [
                  for (final enquiry in enquiries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => context.go('/enquiries/${enquiry.id}'),
                      title: Text(enquiry.name),
                      subtitle: Text(
                        '${enquiry.reference} · ${formatIndianMobile(enquiry.phone)} · '
                        '${formatRelative(enquiry.createdAt)}',
                      ),
                      trailing: EnquiryStatusPill(status: enquiry.status),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SiteVisitsSection extends ConsumerWidget {
  const _SiteVisitsSection({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Site visits',
      trailing: TextButton(
        onPressed: () => context.go(
          SiteVisitQuery(
            propertyId: propertyId,
            when: SiteVisitWhen.all,
          ).location,
        ),
        child: const Text('View all'),
      ),
      child: AsyncValueView(
        value: ref.watch(propertySiteVisitsProvider(propertyId)),
        onRetry: () => ref.invalidate(propertySiteVisitsProvider(propertyId)),
        data: (visits) => visits.isEmpty
            ? const EmptyState(message: 'No site visits for this property yet.')
            : Column(
                children: [
                  for (final visit in visits)
                    SiteVisitRow(visit: visit, dense: true),
                ],
              ),
      ),
    );
  }
}

class _BookingsSection extends ConsumerWidget {
  const _BookingsSection({required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Bookings',
      trailing: TextButton(
        onPressed: () => context.go(
          BookingQuery(propertyId: propertyId, open: false).location,
        ),
        child: const Text('View all'),
      ),
      child: AsyncValueView(
        value: ref.watch(propertyBookingsProvider(propertyId)),
        onRetry: () => ref.invalidate(propertyBookingsProvider(propertyId)),
        data: (bookings) => bookings.isEmpty
            ? const EmptyState(message: 'No bookings for this property yet.')
            : Column(
                children: [
                  for (final booking in bookings)
                    BookingRow(booking: booking, dense: true),
                ],
              ),
      ),
    );
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.propertyId, required this.code});

  final String propertyId;
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(adminNamesProvider);
    return SectionCard(
      title: 'History',
      child: AsyncValueView(
        value: ref.watch(propertyHistoryProvider(propertyId)),
        onRetry: () => ref.invalidate(propertyHistoryProvider(propertyId)),
        data: (entries) => entries.isEmpty
            ? const EmptyState(message: 'No changes yet.')
            : Column(
                children: [
                  for (final entry in entries)
                    ActivityTile(
                      entry: entry,
                      actorName: actorLabel(entry.actorId, names),
                      propertyCode: code,
                    ),
                ],
              ),
      ),
    );
  }
}
