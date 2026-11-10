import 'package:avanilands_admin/core/validators.dart';
import 'package:avanilands_admin/features/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand and company details round-trip with the database row', () {
    final settings = SiteSettings.fromJson({
      'company_name': 'Avanilands',
      'legal_name': 'Tirupa Technologies Pvt. Ltd.',
      'tagline': 'Find Your Space. Build Your Future.',
      'descriptor': 'Real Estate & Property Platform',
      'registered_address': '1-2-3, Beach Road, Visakhapatnam',
      'gst_number': '37ABCDE1234F1Z5',
      'rera_number': 'P01100001234',
    });
    expect(settings.legalName, 'Tirupa Technologies Pvt. Ltd.');
    expect(settings.gstNumber, '37ABCDE1234F1Z5');
    final json = settings.toJson();
    expect(json['legal_name'], 'Tirupa Technologies Pvt. Ltd.');
    expect(json['tagline'], 'Find Your Space. Build Your Future.');
    expect(json['descriptor'], 'Real Estate & Property Platform');
    expect(json['registered_address'], '1-2-3, Beach Road, Visakhapatnam');
    expect(json['rera_number'], 'P01100001234');
  });

  test('older rows without the new columns get the brand defaults', () {
    final settings = SiteSettings.fromJson({'company_name': 'Avanilands'});
    expect(settings.tagline, defaultTagline);
    expect(settings.descriptor, defaultDescriptor);
    expect(settings.legalName, defaultLegalName);
    expect(settings.gstNumber, isNull);
    expect(settings.toJson()['gst_number'], isNull);
  });

  test('a GST number is 15 letters and digits, or empty', () {
    expect(Validators.gstNumber(null), isNull);
    expect(Validators.gstNumber('  '), isNull);
    expect(Validators.gstNumber('37ABCDE1234F1Z5'), isNull);
    expect(Validators.gstNumber('37abcde1234f1z5'), isNull);
    expect(Validators.gstNumber('37ABCDE1234F1Z'), isNotNull);
    expect(Validators.gstNumber('37ABCDE1234F1Z5!'), isNotNull);
  });
}
