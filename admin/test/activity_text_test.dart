import 'package:avanilands_admin/features/activity/activity_repository.dart';
import 'package:avanilands_admin/features/activity/activity_text.dart';
import 'package:flutter_test/flutter_test.dart';

AuditEntry _entry(
  String action,
  Map<String, dynamic> details, {
  String type = 'property',
}) => AuditEntry(
  id: 1,
  actorId: null,
  action: action,
  entityType: type,
  entityId: 'p1',
  details: details,
  createdAt: DateTime(2026, 11, 8),
);

void main() {
  test('price change in Indian format', () {
    final text = describeActivity(
      _entry('property.price_changed', {
        'code': 'AL-0001',
        'old_price': 3600000,
        'new_price': '4200000.00',
        'old_price_type': 'total',
        'new_price_type': 'total',
      }),
    );
    expect(text, 'Changed the price of AL-0001 from ₹36,00,000 to ₹42,00,000');
  });

  test('price on request', () {
    final text = describeActivity(
      _entry('property.price_changed', {
        'code': 'AL-0005',
        'old_price': 100,
        'new_price': null,
        'old_price_type': 'total',
        'new_price_type': 'on_request',
      }),
    );
    expect(text, endsWith('to price on request'));
  });

  test('status changes', () {
    expect(
      describeActivity(_entry('property.marked_sold', {'code': 'AL-0008'})),
      'Marked AL-0008 as sold',
    );
    expect(
      describeActivity(_entry('property.unpublished', {'code': 'AL-0002'})),
      'Unpublished AL-0002',
    );
  });

  test('field list is shortened', () {
    final text = describeActivity(
      _entry('property.updated', {
        'code': 'AL-0003',
        'changes': {
          'title': {},
          'facing': {},
          'road_width_ft': {},
          'locality': {},
          'pincode': {},
        },
      }),
    );
    expect(text, 'Updated AL-0003: title, facing, road width ft and 2 more');
  });

  test('media uses the property code passed in', () {
    final cover = _entry('image.updated', {
      'property_id': 'p1',
      'changes': {
        'is_cover': {'old': false, 'new': true},
      },
    }, type: 'image');
    expect(
      describeActivity(cover, propertyCode: 'AL-0004'),
      'Changed the cover photo on AL-0004',
    );
    expect(describeActivity(cover), 'Changed the cover photo');
  });

  test('documents made public', () {
    final entry = _entry('document.updated', {
      'changes': {
        'is_public': {'old': false, 'new': true},
      },
    }, type: 'document');
    expect(
      describeActivity(entry, propertyCode: 'AL-0001'),
      'Made a document public on AL-0001',
    );
  });

  test('enquiries and admins', () {
    expect(
      describeActivity(
        _entry('enquiry.status_changed', {
          'reference': 'ENQ-000001',
          'to': 'follow_up',
        }, type: 'enquiry'),
      ),
      'Moved enquiry ENQ-000001 to Follow up',
    );
    expect(
      describeActivity(
        _entry('admin.added', {
          'email': 'a@b.test',
          'role': 'super_admin',
        }, type: 'admin'),
      ),
      'Added a@b.test as Super admin',
    );
  });

  test('unknown actions still read sensibly', () {
    expect(
      describeActivity(
        _entry('location.created', {'name': 'Vizag'}, type: 'location'),
      ),
      'Added location · Vizag',
    );
    expect(describeActivity(_entry('something.odd', {})), 'Something odd');
  });
}
