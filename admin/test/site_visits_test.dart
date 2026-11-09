import 'package:avanilands_admin/features/activity/activity_repository.dart';
import 'package:avanilands_admin/features/activity/activity_text.dart';
import 'package:avanilands_admin/features/site_visits/site_visit_models.dart';
import 'package:flutter_test/flutter_test.dart';

SiteVisit _visit({String status = 'confirmed', String date = '2026-11-14'}) =>
    SiteVisit.fromJson({
      'id': 'v1',
      'reference': 'SV-000004',
      'name': 'Prasad Rao',
      'phone': '9440012345',
      'email': null,
      'visitors': 1,
      'visit_date': date,
      'slot': '15:00',
      'message': null,
      'status': status,
      'assigned_to': null,
      'created_at': '2026-11-09T10:00:00Z',
      'reminder_sent_at': null,
      'property': {
        'id': 'p1',
        'code': 'AL-0003',
        'title': '2 Acre Land',
        'slug': 'land',
        'publish_state': 'published',
        'availability': 'available',
        'locality': 'Chodavaram',
        'location': {'city': 'Anakapalli'},
      },
    });

void main() {
  group('dates in India time', () {
    test('today follows India, not the computer', () {
      // 20:00 UTC on 9 Nov is 01:30 on 10 Nov in India.
      expect(indiaToday(DateTime.utc(2026, 11, 9, 20)), '2026-11-10');
      expect(indiaToday(DateTime.utc(2026, 11, 9, 10)), '2026-11-09');
    });

    test('adding days crosses months and years', () {
      expect(addDaysKey('2026-12-30', 3), '2027-01-02');
      expect(addDaysKey('2026-11-09', -10), '2026-10-30');
    });

    test('readable days and times', () {
      expect(formatVisitDay('2026-11-14'), 'Sat, 14 Nov 2026');
      expect(formatVisitDay('2026-11-14', year: false), 'Sat, 14 Nov');
      expect(formatVisitSlot('10:00'), '10:00 am');
      expect(formatVisitSlot('12:30'), '12:30 pm');
      expect(formatVisitSlot('00:15'), '12:15 am');
    });

    test('typed times are cleaned', () {
      expect(normalizeSlot('9:30'), '09:30');
      expect(normalizeSlot(' 16.45 '), '16:45');
      expect(normalizeSlot('25:00'), isNull);
      expect(normalizeSlot('3pm'), isNull);
    });

    test('month grid starts on Monday', () {
      // November 2026 starts on a Sunday.
      final weeks = monthGrid(2026, 11);
      expect(weeks.first.take(6).every((day) => day == null), isTrue);
      expect(weeks.first.last, '2026-11-01');
      expect(weeks.last.whereType<String>().last, '2026-11-30');
      expect(weeks.every((week) => week.length == 7), isTrue);
    });
  });

  group('filters in the address', () {
    test('round trip', () {
      final query = SiteVisitQuery.fromUri(
        Uri.parse(
          '/site-visits?status=requested&when=past&mine=1&page=2&property=p1',
        ),
      );
      expect(query.status, SiteVisitStatus.requested);
      expect(query.when, SiteVisitWhen.past);
      expect(query.mine, isTrue);
      expect(SiteVisitQuery.fromUri(Uri.parse(query.location)), query);
    });

    test('defaults to upcoming; a bad date is ignored', () {
      final query = SiteVisitQuery.fromUri(Uri.parse('/site-visits?date=nope'));
      expect(query.when, SiteVisitWhen.upcoming);
      expect(query.date, isNull);
      expect(query.location, '/site-visits');
    });
  });

  test('a visit can be marked done only once its day has come', () {
    final visit = _visit(date: '2026-11-14');
    expect(visit.canFinish('2026-11-13'), isFalse);
    expect(visit.canFinish('2026-11-14'), isTrue);
    expect(_visit(status: 'requested').canFinish('2026-12-01'), isFalse);
    expect(visit.when, 'Sat, 14 Nov 2026, 3:00 pm');
    expect(visit.property.place, 'Chodavaram, Anakapalli');
    expect(
      Uri.decodeComponent(visit.whatsappLink),
      contains('AL-0003 on Sat, 14 Nov at 3:00 pm (SV-000004)'),
    );
  });

  test('timeline headlines', () {
    SiteVisitNote note(Map<String, dynamic> json) => SiteVisitNote.fromJson({
      'id': 'n',
      'created_at': '2026-11-09T10:00:00Z',
      ...json,
    });
    expect(
      note({'moved_from': '2026-11-14 15:00', 'moved_to': '2026-11-15 16:30'})
          .headline,
      'Moved from Sat, 14 Nov, 3:00 pm to Sun, 15 Nov, 4:30 pm',
    );
    expect(
      note({'status_from': 'requested', 'status_to': 'confirmed'}).headline,
      'Confirmed the visit',
    );
    expect(note({'note': 'x'}).headline, 'Added a note');
  });

  test('activity log lines', () {
    AuditEntry entry(String action, Map<String, dynamic> details) => AuditEntry(
      id: 1,
      actorId: null,
      action: action,
      entityType: 'site_visit',
      entityId: 'v1',
      details: details,
      createdAt: DateTime(2026, 11, 9),
    );
    expect(
      describeActivity(
        entry('site_visit.requested', {
          'reference': 'SV-000004',
          'visit_date': '2026-11-14',
          'slot': '15:00',
        }),
        propertyCode: 'AL-0003',
      ),
      'Site visit SV-000004 requested on AL-0003 for Sat, 14 Nov 2026, 3:00 pm',
    );
    expect(
      describeActivity(
        entry('site_visit.status_changed', {
          'reference': 'SV-000004',
          'to': 'confirmed',
        }),
      ),
      'Confirmed site visit SV-000004',
    );
    expect(
      describeActivity(
        entry('site_visit.rescheduled', {
          'reference': 'SV-000004',
          'to': '2026-11-15 16:30',
        }),
      ),
      'Moved site visit SV-000004 to Sun, 15 Nov 2026, 4:30 pm',
    );
  });
}
