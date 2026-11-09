import 'package:avanilands_admin/features/enquiries/enquiry_models.dart';
import 'package:flutter_test/flutter_test.dart';

Enquiry _enquiry({String? email, String? assignedTo, String? message}) =>
    Enquiry.fromJson({
      'id': 'e1',
      'reference': 'ENQ-000011',
      'name': 'Suresh Babu',
      'phone': '9012345678',
      'email': email,
      'preferred_contact': 'whatsapp',
      'message': message,
      'status': 'follow_up',
      'source': 'property_page',
      'assigned_to': assignedTo,
      'created_at': '2026-11-08T10:00:00Z',
      'last_contacted_at': null,
      'property': {
        'id': 'p1',
        'code': 'AL-0002',
        'title': '25 Cent Plot',
        'slug': 'plot',
        'publish_state': 'published',
        'availability': 'available',
      },
    });

void main() {
  group('filters in the address', () {
    test('round trip', () {
      final query = EnquiryQuery.fromUri(
        Uri.parse(
          '/enquiries?q=ENQ-000011&status=follow_up&range=7d&assigned=me&page=2&property=p1',
        ),
      );
      expect(query.status, EnquiryStatus.followUp);
      expect(query.range, EnquiryRange.week);
      expect(query.assignee, EnquiryAssignee.me);
      expect(query.page, 2);
      expect(EnquiryQuery.fromUri(Uri.parse(query.location)), query);
    });

    test('unknown values fall back, and changing a filter resets the page', () {
      final query = EnquiryQuery.fromUri(
        Uri.parse('/enquiries?status=spam&range=x&page=-3'),
      );
      expect(query.status, isNull);
      expect(query.range, EnquiryRange.all);
      expect(query.page, 1);
      expect(query.hasFilters, isFalse);
      expect(query.location, '/enquiries');
      expect(
        const EnquiryQuery(page: 4)
            .copyWith(status: () => EnquiryStatus.newEnquiry)
            .page,
        1,
      );
    });
  });

  test('phone search digits', () {
    expect(phoneSearchDigits('+91 90123 45678'), '9012345678');
    expect(phoneSearchDigits('09012345678'), '9012345678');
    expect(phoneSearchDigits('45678'), '45678');
    expect(phoneSearchDigits('12'), isNull);
    expect(phoneSearchDigits('Suresh'), isNull);
    expect(phoneSearchDigits('ENQ-000011'), isNull);
  });

  test('contact links', () {
    final enquiry = _enquiry(email: 'suresh@example.com');
    expect(enquiry.telLink, 'tel:+919012345678');
    expect(
      enquiry.whatsappLink,
      startsWith('https://wa.me/919012345678?text='),
    );
    expect(
      Uri.decodeComponent(enquiry.whatsappLink),
      contains('AL-0002 (ENQ-000011)'),
    );
    expect(enquiry.mailLink, startsWith('mailto:suresh@example.com?subject='));
    expect(_enquiry().mailLink, isNull);
    expect(formatIndianMobile('9012345678'), '+91 90123 45678');
  });

  test('timeline headlines', () {
    final change = EnquiryNote.fromJson({
      'id': 'n1',
      'admin_id': 'a1',
      'note': 'Called',
      'status_from': 'new',
      'status_to': 'contacted',
      'created_at': '2026-11-08T10:00:00Z',
    });
    expect(change.headline, 'Changed status from New to Contacted');
    final note = EnquiryNote.fromJson({
      'id': 'n2',
      'note': 'Site visit Saturday',
      'created_at': '2026-11-08T10:00:00Z',
    });
    expect(note.headline, 'Added a note');
  });

  group('CSV', () {
    test('quotes commas, quotes and new lines', () {
      expect(
        toCsv([
          ['a,b', 'say "hi"', 'two\nlines', null, 5],
        ]),
        '"a,b","say ""hi""","two\nlines",,5',
      );
    });

    test('formula-looking cells are kept as text', () {
      expect(
        toCsv([
          ['=HYPERLINK("x")', '+91 90123', '-1', '@SUM(A1)'],
        ]),
        '"\'=HYPERLINK(""x"")",\'+91 90123,\'-1,\'@SUM(A1)',
      );
    });

    test('one row per enquiry after the header', () {
      final rows = enquiryCsvRows(
        [_enquiry(assignedTo: 'a1', message: 'Call after 6')],
        {'a1': 'Ravi'},
      );
      expect(rows, hasLength(2));
      expect(rows.first.first, 'Reference');
      expect(
        rows.last,
        containsAll([
          'ENQ-000011',
          'AL-0002',
          'Follow up',
          'Ravi',
          'Call after 6',
          'WhatsApp',
        ]),
      );
    });
  });
}
