import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import 'block_editor.dart';
import 'content_image_field.dart';
import 'content_models.dart';
import 'content_repository.dart';

const contentTabs = {
  'home': 'Home page',
  'about': 'About',
  'faqs': 'FAQs',
  'testimonials': 'Testimonials',
  'banners': 'Banners',
  'legal': 'Legal pages',
};

/// Website content (super admins): the words and pictures on the website.
class ContentPage extends ConsumerWidget {
  const ContentPage({super.key, required this.tab});

  final String tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = contentTabs.containsKey(tab) ? tab : 'home';
    return PageBody(
      maxWidth: 1000,
      children: [
        const PageHeader(
          title: 'Website content',
          subtitle: 'Edit the words and pictures on the website. Page texts are saved as drafts; preview, then publish.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in contentTabs.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == current,
                onSelected: (_) => context.go('/content?tab=${entry.key}'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        switch (current) {
          'faqs' => const _FaqsTab(),
          'testimonials' => const _TestimonialsTab(),
          'banners' => const _BannersTab(),
          'about' => const _BlocksTab(specs: aboutBlocks),
          'legal' => const _BlocksTab(specs: legalBlocks),
          _ => const _BlocksTab(specs: homeBlocks),
        },
      ],
    );
  }
}

class _BlocksTab extends ConsumerWidget {
  const _BlocksTab({required this.specs});

  final List<BlockSpec> specs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(contentBlocksProvider),
      onRetry: () => ref.invalidate(contentBlocksProvider),
      data: (blocks) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final spec in specs)
            if (blocks[spec.key] != null) ...[
              BlockEditor(spec: spec, block: blocks[spec.key]!),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

/// Shared shape of the three lists: drag to reorder, edit, publish switch.
class _ReorderableList<T> extends ConsumerWidget {
  const _ReorderableList({
    required this.items,
    required this.idOf,
    required this.table,
    required this.provider,
    required this.tile,
  });

  final List<T> items;
  final String Function(T) idOf;
  final String table;
  final ProviderOrFamily provider;
  final Widget Function(T item) tile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorderItem: (from, to) async {
          final ids = items.map(idOf).toList();
          final moved = moveItem(ids, from, to);
          try {
            await ref.read(contentRepositoryProvider).reorder(table, moved);
          } catch (error) {
            if (context.mounted) {
              showMessage(context, friendlyError(error), error: true);
            }
          }
          ref.invalidate(provider);
        },
        children: [
          for (var i = 0; i < items.length; i++)
            Container(
              key: ValueKey(idOf(items[i])),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: BrandColors.line)),
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Tooltip(
                        message: 'Drag to change the order',
                        child: Icon(Icons.drag_indicator),
                      ),
                    ),
                  ),
                  Expanded(child: tile(items[i])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
  ProviderOrFamily provider,
  String done,
) async {
  try {
    await action();
    ref.invalidate(provider);
    if (context.mounted) showMessage(context, done);
  } catch (error) {
    if (context.mounted) {
      showMessage(context, friendlyError(error), error: true);
    }
  }
}

// FAQs ------------------------------------------------------------------------

class _FaqsTab extends ConsumerWidget {
  const _FaqsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Drag to change the order. Tick "home page" for the five shown on the home page.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => openContentPreview(context, ref, 'faq'),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Preview'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _editFaq(context, ref, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add question'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncValueView(
          value: ref.watch(faqsProvider),
          onRetry: () => ref.invalidate(faqsProvider),
          data: (faqs) => faqs.isEmpty
              ? const EmptyState(message: 'No questions yet.')
              : _ReorderableList<Faq>(
                  items: faqs,
                  idOf: (f) => f.id,
                  table: 'faqs',
                  provider: faqsProvider,
                  tile: (faq) => ListTile(
                    title: Text(faq.question),
                    subtitle: Text(
                      faq.answer,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _editFaq(context, ref, faq),
                    trailing: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (faq.isPlaceholder)
                          const Pill(
                            label: 'Needs an answer',
                            color: BrandColors.danger,
                          ),
                        if (faq.showOnHome)
                          const Pill(
                            label: 'Home page',
                            color: BrandColors.forest,
                          ),
                        Pill(
                          label: faq.isPublished ? 'Published' : 'Hidden',
                          color: faq.isPublished
                              ? BrandColors.available
                              : BrandColors.sold,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

Future<void> _editFaq(BuildContext context, WidgetRef ref, Faq? faq) async {
  final question = TextEditingController(text: faq?.question);
  final answer = TextEditingController(text: faq?.answer);
  var home = faq?.showOnHome ?? false;
  var published = faq?.isPublished ?? true;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(faq == null ? 'Add a question' : 'Edit question'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: question,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              TextField(
                controller: answer,
                maxLength: 2000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  alignLabelWithHint: true,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show on the home page'),
                value: home,
                onChanged: (v) => setState(() => home = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                value: published,
                onChanged: (v) => setState(() => published = v),
              ),
            ],
          ),
        ),
        actions: [
          if (faq != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
              onPressed: () => Navigator.pop(context, 'delete'),
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || result == null) return;
  final repo = ref.read(contentRepositoryProvider);
  if (result == 'delete') {
    if (!await confirmAction(
      context,
      title: 'Delete this question?',
      message: faq!.question,
      confirmLabel: 'Delete',
      destructive: true,
    )) {
      return;
    }
    if (context.mounted) {
      await _save(
        context,
        ref,
        () => repo.deleteFaq(faq.id),
        faqsProvider,
        'Question deleted.',
      );
    }
    return;
  }
  if (question.text.trim().length < 5 || answer.text.trim().length < 2) {
    showMessage(context, 'Write the question and its answer.', error: true);
    return;
  }
  await _save(
    context,
    ref,
    () => repo.saveFaq(faq?.id, {
      'question': question.text.trim(),
      'answer': answer.text.trim(),
      'show_on_home': home,
      'is_published': published,
      if (faq == null) 'sort_order': 1000,
    }),
    faqsProvider,
    'Question saved. The website updates in a few seconds.',
  );
}

// Testimonials ----------------------------------------------------------------

class _TestimonialsTab extends ConsumerWidget {
  const _TestimonialsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BrandColors.paper,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Only real customers, in their own words, who agreed to be shown. '
            'Made-up or edited reviews are against India\'s Consumer Protection rules.',
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _editTestimonial(context, ref, null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add testimonial'),
          ),
        ),
        const SizedBox(height: 12),
        AsyncValueView(
          value: ref.watch(testimonialsProvider),
          onRetry: () => ref.invalidate(testimonialsProvider),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  message: 'No testimonials yet. The section stays hidden on the website until one is published.',
                )
              : _ReorderableList<Testimonial>(
                  items: items,
                  idOf: (t) => t.id,
                  table: 'testimonials',
                  provider: testimonialsProvider,
                  tile: (t) => ListTile(
                    title: Text(
                      '${t.name}${t.place == null ? '' : ' · ${t.place}'}',
                    ),
                    subtitle: Text(
                      '“${t.quote}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _editTestimonial(context, ref, t),
                    trailing: Pill(
                      label: t.isPublished
                          ? 'Published'
                          : (t.hasConsent ? 'Hidden' : 'No consent yet'),
                      color: t.isPublished
                          ? BrandColors.available
                          : BrandColors.sold,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

Future<void> _editTestimonial(
  BuildContext context,
  WidgetRef ref,
  Testimonial? t,
) async {
  final name = TextEditingController(text: t?.name);
  final place = TextEditingController(text: t?.place);
  final quote = TextEditingController(text: t?.quote);
  final consentNote = TextEditingController(text: t?.consentNote);
  var rating = t?.rating;
  var photo = t?.photoPath;
  var consent = t?.hasConsent ?? false;
  var published = t?.isPublished ?? false;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(t == null ? 'Add a testimonial' : 'Edit testimonial'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Customer name'),
                ),
                TextField(
                  controller: place,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Town (optional)',
                  ),
                ),
                TextField(
                  controller: quote,
                  maxLength: 600,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'What they said (their words)',
                    alignLabelWithHint: true,
                  ),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: rating,
                  decoration: const InputDecoration(
                    labelText: 'Stars (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No stars'),
                    ),
                    for (var i = 5; i >= 1; i--)
                      DropdownMenuItem(value: i, child: Text('$i ★')),
                  ],
                  onChanged: (v) => setState(() => rating = v),
                ),
                const SizedBox(height: 12),
                ContentImageField(
                  label: 'Photo (optional, with their permission)',
                  path: photo,
                  folder: 'testimonials',
                  width: 120,
                  onChanged: (v) => setState(() => photo = v),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'The customer agreed to this being shown on the website',
                  ),
                  value: consent,
                  onChanged: (v) => setState(() {
                    consent = v ?? false;
                    if (!consent) published = false;
                  }),
                ),
                TextField(
                  controller: consentNote,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'How they agreed (e.g. WhatsApp, 9 Nov)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  subtitle: consent
                      ? null
                      : const Text('Tick the consent box first.'),
                  value: published,
                  onChanged: consent
                      ? (v) => setState(() => published = v)
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (t != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
              onPressed: () => Navigator.pop(context, 'delete'),
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || result == null) return;
  final repo = ref.read(contentRepositoryProvider);
  if (result == 'delete') {
    if (!await confirmAction(
      context,
      title: 'Delete this testimonial?',
      message: t!.name,
      confirmLabel: 'Delete',
      destructive: true,
    )) {
      return;
    }
    if (context.mounted) {
      await _save(
        context,
        ref,
        () => repo.deleteTestimonial(t.id),
        testimonialsProvider,
        'Testimonial deleted.',
      );
    }
    return;
  }
  if (name.text.trim().length < 2 || quote.text.trim().length < 10) {
    showMessage(
      context,
      'Add the customer\'s name and what they said (at least 10 characters).',
      error: true,
    );
    return;
  }
  await _save(
    context,
    ref,
    () => repo.saveTestimonial(t?.id, {
      'name': name.text.trim(),
      'place': place.text.trim().isEmpty ? null : place.text.trim(),
      'quote': quote.text.trim(),
      'rating': rating,
      'photo_path': photo,
      'has_consent': consent,
      'consent_note': consentNote.text.trim().isEmpty
          ? null
          : consentNote.text.trim(),
      'is_published': published && consent,
      if (t == null) 'sort_order': 1000,
    }),
    testimonialsProvider,
    'Testimonial saved.',
  );
}

// Banners ---------------------------------------------------------------------

class _BannersTab extends ConsumerWidget {
  const _BannersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Short announcements on the home page (up to 3 at a time), each with optional dates.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => openContentPreview(context, ref, 'home'),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Preview'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _editBanner(context, ref, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add banner'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncValueView(
          value: ref.watch(bannersProvider),
          onRetry: () => ref.invalidate(bannersProvider),
          data: (items) => items.isEmpty
              ? const EmptyState(message: 'No banners.')
              : _ReorderableList<BannerItem>(
                  items: items,
                  idOf: (b) => b.id,
                  table: 'banners',
                  provider: bannersProvider,
                  tile: (b) {
                    final state = b.stateAt(now);
                    final (label, color) = switch (state) {
                      BannerState.showing => (
                        'Showing now',
                        BrandColors.available,
                      ),
                      BannerState.scheduled => (
                        'From ${formatDateTime(b.startsAt!)}',
                        BrandColors.reserved,
                      ),
                      BannerState.ended => ('Ended', BrandColors.sold),
                      BannerState.off => ('Off', BrandColors.sold),
                    };
                    return ListTile(
                      title: Text(b.title),
                      subtitle: Text(
                        [b.text, b.linkUrl].whereType<String>().join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _editBanner(context, ref, b),
                      trailing: Pill(label: label, color: color),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Future<void> _editBanner(
  BuildContext context,
  WidgetRef ref,
  BannerItem? b,
) async {
  final title = TextEditingController(text: b?.title);
  final text = TextEditingController(text: b?.text);
  final link = TextEditingController(text: b?.linkUrl);
  final linkLabel = TextEditingController(text: b?.linkLabel);
  var image = b?.imagePath;
  var startsAt = b?.startsAt;
  var endsAt = b?.endsAt;
  var active = b?.isActive ?? true;
  String? error;

  Future<DateTime?> pickDay(BuildContext context, DateTime? current) =>
      showDatePicker(
        context: context,
        initialDate: current ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(b == null ? 'Add a banner' : 'Edit banner'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: title,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: text,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Text (optional)',
                  ),
                ),
                TextField(
                  controller: link,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Link (optional)',
                    hintText: '/land-for-sale/vizianagaram or https://…',
                  ),
                ),
                TextField(
                  controller: linkLabel,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Link text (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                ContentImageField(
                  label: 'Photo (optional)',
                  path: image,
                  folder: 'banners',
                  width: 160,
                  onChanged: (v) => setState(() => image = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final day = await pickDay(context, startsAt);
                        if (day != null) {
                          setState(
                            () => startsAt = DateTime(
                              day.year,
                              day.month,
                              day.day,
                            ),
                          );
                        }
                      },
                      child: Text(
                        startsAt == null
                            ? 'Show from: now'
                            : 'Show from ${formatDate(startsAt!)}',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final day = await pickDay(context, endsAt);
                        // Until the end of that day.
                        if (day != null) {
                          setState(
                            () => endsAt = DateTime(
                              day.year,
                              day.month,
                              day.day,
                              23,
                              59,
                            ),
                          );
                        }
                      },
                      child: Text(
                        endsAt == null
                            ? 'Until: no end'
                            : 'Until ${formatDate(endsAt!)}',
                      ),
                    ),
                    if (startsAt != null || endsAt != null)
                      TextButton(
                        onPressed: () => setState(() {
                          startsAt = null;
                          endsAt = null;
                        }),
                        child: const Text('Clear dates'),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('On'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: BrandColors.danger),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (b != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
              onPressed: () => Navigator.pop(context, 'delete'),
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final problem = title.text.trim().length < 2
                  ? 'Add a title.'
                  : checkBannerLink(link.text) ??
                        (startsAt != null &&
                                endsAt != null &&
                                !endsAt!.isAfter(startsAt!)
                            ? 'The end date must be after the start.'
                            : null);
              if (problem != null) return setState(() => error = problem);
              Navigator.pop(context, 'save');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || result == null) return;
  final repo = ref.read(contentRepositoryProvider);
  if (result == 'delete') {
    if (!await confirmAction(
      context,
      title: 'Delete this banner?',
      message: b!.title,
      confirmLabel: 'Delete',
      destructive: true,
    )) {
      return;
    }
    if (context.mounted) {
      await _save(
        context,
        ref,
        () => repo.deleteBanner(b.id),
        bannersProvider,
        'Banner deleted.',
      );
    }
    return;
  }
  String? orNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();
  await _save(
    context,
    ref,
    () => repo.saveBanner(b?.id, {
      'title': title.text.trim(),
      'text': orNull(text),
      'link_url': orNull(link),
      'link_label': orNull(linkLabel),
      'image_path': image,
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'is_active': active,
      if (b == null) 'sort_order': 1000,
    }),
    bannersProvider,
    'Banner saved. The website follows its dates within about a minute.',
  );
}
