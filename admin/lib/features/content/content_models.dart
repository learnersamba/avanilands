/// Website content (Phase 14): what each editable page section looks like,
/// so one editor can show them all. Limits match the database checks.
library;

enum FieldKind { text, multiline, icon, image, toggle }

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.maxLength = 200,
    this.required = false,
    this.hint,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final int maxLength;
  final bool required;
  final String? hint;
}

class BlockSpec {
  const BlockSpec({
    required this.key,
    required this.title,
    required this.description,
    required this.previewPage,
    this.fields = const [],
    this.listKey,
    this.listLabel,
    this.itemFields = const [],
    this.stringItems = false,
    this.itemLabel = 'item',
    this.maxItems = 10,
    this.minItems = 1,
  });

  final String key;
  final String title;
  final String description;

  /// Website page that shows it (`/preview/<page>`).
  final String previewPage;
  final List<FieldSpec> fields;

  /// The block's list (items / values / sections), if it has one.
  final String? listKey;
  final String? listLabel;
  final List<FieldSpec> itemFields;

  /// A list of plain sentences instead of records.
  final bool stringItems;
  final String itemLabel;
  final int maxItems;
  final int minItems;
}

/// Icons the website knows (components/icons.tsx).
const contentIcons = {
  'shield': 'Shield (safety)',
  'stamp': 'Stamp (approvals)',
  'handshake': 'Handshake (direct)',
  'map': 'Map pin (visits)',
  'badge': 'Badge (verified)',
  'file': 'Document',
  'ruler': 'Ruler (measured)',
  'users': 'People (team)',
};

const _legalFields = [
  FieldSpec('title', 'Page title', maxLength: 80, required: true),
  FieldSpec(
    'final',
    'This is the final wording from our legal advisor',
    kind: FieldKind.toggle,
    hint: 'While off, the page says the text is a draft.',
  ),
];
const _legalItems = [
  FieldSpec('heading', 'Heading', maxLength: 120, required: true),
  FieldSpec('text', 'Text', kind: FieldKind.multiline, maxLength: 4000),
];

const homeBlocks = [
  BlockSpec(
    key: 'home.hero',
    title: 'Top of the home page',
    description: 'The first thing visitors see: a short line, the big title, a sentence and a background photo.',
    previewPage: 'home',
    fields: [
      FieldSpec('eyebrow', 'Small line above the title', maxLength: 80),
      FieldSpec('title', 'Title', maxLength: 120, required: true),
      FieldSpec(
        'subtitle',
        'Text under the title',
        kind: FieldKind.multiline,
        maxLength: 300,
      ),
      FieldSpec(
        'image_path',
        'Background photo (optional)',
        kind: FieldKind.image,
      ),
    ],
  ),
  BlockSpec(
    key: 'home.trust_points',
    title: 'Four promises under the top',
    description: 'Short reasons to trust you, each with an icon.',
    previewPage: 'home',
    listKey: 'items',
    listLabel: 'Promises',
    itemLabel: 'promise',
    maxItems: 4,
    itemFields: [
      FieldSpec('icon', 'Icon', kind: FieldKind.icon),
      FieldSpec('title', 'Title', maxLength: 40, required: true),
      FieldSpec('text', 'Text', maxLength: 80),
    ],
  ),
  BlockSpec(
    key: 'home.why_us',
    title: 'Why choose us',
    description: 'Shown on the home and About pages.',
    previewPage: 'home',
    listKey: 'items',
    listLabel: 'Reasons',
    itemLabel: 'reason',
    maxItems: 8,
    itemFields: [
      FieldSpec('icon', 'Icon', kind: FieldKind.icon),
      FieldSpec('title', 'Title', maxLength: 60, required: true),
      FieldSpec('text', 'Text', kind: FieldKind.multiline, maxLength: 300),
    ],
  ),
  BlockSpec(
    key: 'home.verification',
    title: 'What we check before listing',
    description: 'The checklist on the dark section of the home page.',
    previewPage: 'home',
    listKey: 'items',
    listLabel: 'Checks',
    itemLabel: 'check',
    stringItems: true,
    maxItems: 10,
  ),
  BlockSpec(
    key: 'home.steps',
    title: 'How buying works',
    description: 'The numbered steps from first call to registration.',
    previewPage: 'home',
    listKey: 'items',
    listLabel: 'Steps',
    itemLabel: 'step',
    maxItems: 6,
    itemFields: [
      FieldSpec('title', 'Title', maxLength: 40, required: true),
      FieldSpec('text', 'Text', maxLength: 200),
    ],
  ),
];

const aboutBlocks = [
  BlockSpec(
    key: 'about',
    title: 'About us',
    description: 'Your story, mission, vision and values. Leave a blank line between paragraphs.',
    previewPage: 'about',
    fields: [
      FieldSpec(
        'intro',
        'Company story',
        kind: FieldKind.multiline,
        maxLength: 4000,
        required: true,
      ),
      FieldSpec(
        'mission',
        'Mission',
        kind: FieldKind.multiline,
        maxLength: 400,
      ),
      FieldSpec('vision', 'Vision', kind: FieldKind.multiline, maxLength: 400),
      FieldSpec('image_path', 'Photo (optional)', kind: FieldKind.image),
    ],
    listKey: 'values',
    listLabel: 'Values',
    itemLabel: 'value',
    maxItems: 6,
    itemFields: [
      FieldSpec('title', 'Value', maxLength: 40, required: true),
      FieldSpec('text', 'Text', maxLength: 300),
    ],
  ),
];

const legalBlocks = [
  BlockSpec(
    key: 'legal.terms',
    title: 'Terms of use',
    description:
        'Have your legal advisor check the wording before marking it final.',
    previewPage: 'terms',
    fields: _legalFields,
    listKey: 'sections',
    listLabel: 'Sections',
    itemLabel: 'section',
    maxItems: 20,
    itemFields: _legalItems,
  ),
  BlockSpec(
    key: 'legal.privacy',
    title: 'Privacy policy',
    description:
        'Have your legal advisor check the wording before marking it final.',
    previewPage: 'privacy',
    fields: _legalFields,
    listKey: 'sections',
    listLabel: 'Sections',
    itemLabel: 'section',
    maxItems: 20,
    itemFields: _legalItems,
  ),
  BlockSpec(
    key: 'legal.disclaimer',
    title: 'Disclaimer',
    description:
        'Have your legal advisor check the wording before marking it final.',
    previewPage: 'disclaimer',
    fields: _legalFields,
    listKey: 'sections',
    listLabel: 'Sections',
    itemLabel: 'section',
    maxItems: 20,
    itemFields: _legalItems,
  ),
];

Map<String, dynamic> deepCopy(Map<String, dynamic> value) => {
  for (final entry in value.entries)
    entry.key: switch (entry.value) {
      final Map<String, dynamic> map => deepCopy(map),
      final List<dynamic> list => [
        for (final item in list)
          item is Map<String, dynamic> ? deepCopy(item) : item,
      ],
      final other => other,
    },
};

/// A problem to fix before saving, or null. Mirrors the database checks.
String? checkBlock(BlockSpec spec, Map<String, dynamic> value) {
  for (final field in spec.fields) {
    final v = value[field.key];
    if (field.required && (v is! String || v.trim().isEmpty)) {
      return '${field.label} is needed.';
    }
    if (v is String && v.length > field.maxLength) {
      return '${field.label} is too long (${field.maxLength} characters at most).';
    }
  }
  if (spec.listKey != null) {
    final items = (value[spec.listKey] as List?) ?? const [];
    if (items.length < spec.minItems) {
      return 'Add at least ${spec.minItems} ${spec.itemLabel}.';
    }
    if (items.length > spec.maxItems) {
      return 'At most ${spec.maxItems} ${spec.itemLabel}s.';
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (spec.stringItems) {
        if (item is! String || item.trim().isEmpty) {
          return '${_ordinal(i + 1)} ${spec.itemLabel} is empty.';
        }
        if (item.length > 200) {
          return '${_ordinal(i + 1)} ${spec.itemLabel} is too long.';
        }
        continue;
      }
      for (final field in spec.itemFields) {
        final v = (item as Map)[field.key];
        if (field.required && (v is! String || v.trim().isEmpty)) {
          return '${field.label} of the ${_ordinal(i + 1).toLowerCase()} ${spec.itemLabel} is needed.';
        }
        if (v is String && v.length > field.maxLength) {
          return '${field.label} of the ${_ordinal(i + 1).toLowerCase()} ${spec.itemLabel} is too long.';
        }
      }
    }
  }
  return null;
}

String _ordinal(int n) => switch (n) {
  1 => 'First',
  2 => 'Second',
  3 => 'Third',
  _ => 'Item $n:',
};

/// A new, empty item for a block's list.
Object newItem(BlockSpec spec) => spec.stringItems
    ? ''
    : {
        for (final field in spec.itemFields)
          field.key: field.kind == FieldKind.icon ? 'badge' : '',
      };

/// Moves a list item; returns a new list.
List<T> moveItem<T>(List<T> list, int from, int to) {
  final copy = [...list];
  final item = copy.removeAt(from);
  copy.insert(to.clamp(0, copy.length), item);
  return copy;
}

class ContentBlock {
  const ContentBlock({
    required this.key,
    required this.published,
    this.draft,
    required this.publishedAt,
  });

  factory ContentBlock.fromJson(Map<String, dynamic> json) => ContentBlock(
    key: json['key'] as String,
    published: (json['published'] as Map).cast<String, dynamic>(),
    draft: (json['draft'] as Map?)?.cast<String, dynamic>(),
    publishedAt: DateTime.parse(json['published_at'] as String),
  );

  final String key;
  final Map<String, dynamic> published;
  final Map<String, dynamic>? draft;
  final DateTime publishedAt;

  bool get hasDraft => draft != null;
  Map<String, dynamic> get current => draft ?? published;
}

class Faq {
  const Faq({
    required this.id,
    required this.question,
    required this.answer,
    required this.showOnHome,
    required this.isPublished,
  });

  factory Faq.fromJson(Map<String, dynamic> json) => Faq(
    id: json['id'] as String,
    question: json['question'] as String,
    answer: json['answer'] as String,
    showOnHome: json['show_on_home'] as bool,
    isPublished: json['is_published'] as bool,
  );

  final String id;
  final String question;
  final String answer;
  final bool showOnHome;
  final bool isPublished;

  bool get isPlaceholder => answer.trim().startsWith('PLACEHOLDER');
}

class Testimonial {
  const Testimonial({
    required this.id,
    required this.name,
    this.place,
    required this.quote,
    this.rating,
    this.photoPath,
    required this.hasConsent,
    this.consentNote,
    required this.isPublished,
  });

  factory Testimonial.fromJson(Map<String, dynamic> json) => Testimonial(
    id: json['id'] as String,
    name: json['name'] as String,
    place: json['place'] as String?,
    quote: json['quote'] as String,
    rating: (json['rating'] as num?)?.toInt(),
    photoPath: json['photo_path'] as String?,
    hasConsent: json['has_consent'] as bool,
    consentNote: json['consent_note'] as String?,
    isPublished: json['is_published'] as bool,
  );

  final String id;
  final String name;
  final String? place;
  final String quote;
  final int? rating;
  final String? photoPath;
  final bool hasConsent;
  final String? consentNote;
  final bool isPublished;
}

enum BannerState { showing, scheduled, ended, off }

class BannerItem {
  const BannerItem({
    required this.id,
    required this.title,
    this.text,
    this.linkUrl,
    this.linkLabel,
    this.imagePath,
    this.startsAt,
    this.endsAt,
    required this.isActive,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
    id: json['id'] as String,
    title: json['title'] as String,
    text: json['text'] as String?,
    linkUrl: json['link_url'] as String?,
    linkLabel: json['link_label'] as String?,
    imagePath: json['image_path'] as String?,
    startsAt: json['starts_at'] == null
        ? null
        : DateTime.parse(json['starts_at'] as String),
    endsAt: json['ends_at'] == null
        ? null
        : DateTime.parse(json['ends_at'] as String),
    isActive: json['is_active'] as bool,
  );

  final String id;
  final String title;
  final String? text;
  final String? linkUrl;
  final String? linkLabel;
  final String? imagePath;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;

  BannerState stateAt(DateTime now) {
    if (!isActive) return BannerState.off;
    if (endsAt != null && !endsAt!.isAfter(now)) return BannerState.ended;
    if (startsAt != null && startsAt!.isAfter(now)) {
      return BannerState.scheduled;
    }
    return BannerState.showing;
  }
}

/// A banner link must be a page on this website ("/land") or https://.
String? checkBannerLink(String value) {
  final link = value.trim();
  if (link.isEmpty) return null;
  if (RegExp(r'^(/[a-z0-9]|/$)').hasMatch(link) ||
      link.startsWith('https://')) {
    return link.length > 300 ? 'Link is too long.' : null;
  }
  return 'Use a page on this website (like /land) or a full https:// address.';
}
