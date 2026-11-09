import 'package:avanilands_admin/features/activity/activity_repository.dart';
import 'package:avanilands_admin/features/activity/activity_text.dart';
import 'package:avanilands_admin/features/content/content_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every page text in the database has an editor', () {
    final keys = [
      ...homeBlocks,
      ...aboutBlocks,
      ...legalBlocks,
    ].map((b) => b.key).toSet();
    expect(keys, {
      'home.hero',
      'home.trust_points',
      'home.why_us',
      'home.verification',
      'home.steps',
      'about',
      'legal.terms',
      'legal.privacy',
      'legal.disclaimer',
    });
  });

  group('checks before saving', () {
    final hero = homeBlocks.firstWhere((b) => b.key == 'home.hero');
    final steps = homeBlocks.firstWhere((b) => b.key == 'home.steps');
    final checks = homeBlocks.firstWhere((b) => b.key == 'home.verification');

    test('required and too-long text', () {
      expect(checkBlock(hero, {'title': ''}), 'Title is needed.');
      expect(checkBlock(hero, {'title': 'x' * 121}), contains('too long'));
      expect(checkBlock(hero, {'title': 'Land near Vizag'}), isNull);
    });

    test('lists', () {
      expect(checkBlock(steps, {'items': []}), 'Add at least 1 step.');
      expect(
        checkBlock(steps, {
          'items': [
            {'title': '', 'text': 'x'},
          ],
        }),
        'Title of the first step is needed.',
      );
      expect(
        checkBlock(steps, {
          'items': List.generate(7, (_) => {'title': 'a', 'text': ''}),
        }),
        'At most 6 steps.',
      );
      expect(
        checkBlock(checks, {
          'items': ['ok', ' '],
        }),
        'Second check is empty.',
      );
    });

    test('new items and moving', () {
      expect(newItem(checks), '');
      expect(newItem(homeBlocks.firstWhere((b) => b.key == 'home.why_us')), {
        'icon': 'badge',
        'title': '',
        'text': '',
      });
      expect(moveItem([1, 2, 3], 2, 0), [3, 1, 2]);
      expect(moveItem([1, 2, 3], 0, 2), [2, 3, 1]);
    });

    test('editing a copy never changes the original', () {
      final original = {
        'items': [
          {'title': 'A'},
        ],
      };
      final copy = deepCopy(original);
      ((copy['items'] as List)[0] as Map)['title'] = 'B';
      expect(((original['items'] as List)[0] as Map)['title'], 'A');
    });
  });

  test('banner schedule', () {
    final now = DateTime(2026, 11, 9, 12);
    BannerItem banner({DateTime? from, DateTime? until, bool on = true}) =>
        BannerItem(
          id: 'b',
          title: 'Offer',
          startsAt: from,
          endsAt: until,
          isActive: on,
        );
    expect(banner().stateAt(now), BannerState.showing);
    expect(
      banner(from: DateTime(2026, 11, 10)).stateAt(now),
      BannerState.scheduled,
    );
    expect(
      banner(until: DateTime(2026, 11, 8)).stateAt(now),
      BannerState.ended,
    );
    expect(banner(on: false).stateAt(now), BannerState.off);
  });

  test('banner links stay on safe addresses', () {
    expect(checkBannerLink(''), isNull);
    expect(checkBannerLink('/land-for-sale/vizianagaram'), isNull);
    expect(checkBannerLink('https://example.com/offer'), isNull);
    expect(checkBannerLink('javascript:alert(1)'), isNotNull);
    expect(checkBannerLink('//evil.example'), isNotNull);
    expect(checkBannerLink('http://example.com'), isNotNull);
  });

  test('activity log lines', () {
    AuditEntry entry(String action, Map<String, dynamic> d, String id) =>
        AuditEntry(
          id: 1,
          actorId: null,
          action: action,
          entityType: action.split('.').first,
          entityId: id,
          details: d,
          createdAt: DateTime(2026, 11, 9),
        );
    expect(
      describeActivity(
        entry('content.published', {'name': 'home.hero'}, 'home.hero'),
      ),
      'Published website content: top of the home page',
    );
    expect(
      describeActivity(
        entry('testimonial.created', {'name': 'Kumar Swamy'}, 't1'),
      ),
      'Added the testimonial from Kumar Swamy',
    );
  });
}
