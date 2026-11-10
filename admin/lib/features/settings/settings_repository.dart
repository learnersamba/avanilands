import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

const defaultLegalName = 'Tirupa Technologies Pvt. Ltd.';
const defaultTagline = 'Find Your Space. Build Your Future.';
const defaultDescriptor = 'Real Estate & Property Platform';

/// The single `site_settings` row.
class SiteSettings {
  const SiteSettings({
    required this.companyName,
    this.legalName = defaultLegalName,
    this.tagline = defaultTagline,
    this.descriptor = defaultDescriptor,
    this.registeredAddress,
    this.gstNumber,
    this.reraNumber,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.officeHours,
    this.socialLinks = const {},
    this.salesNotifyEmails = const [],
    this.seoTitle,
    this.seoDescription,
    this.updatedAt,
  });

  factory SiteSettings.fromJson(Map<String, dynamic> json) => SiteSettings(
    companyName: json['company_name'] as String,
    legalName: json['legal_name'] as String? ?? defaultLegalName,
    tagline: json['tagline'] as String? ?? defaultTagline,
    descriptor: json['descriptor'] as String? ?? defaultDescriptor,
    registeredAddress: json['registered_address'] as String?,
    gstNumber: json['gst_number'] as String?,
    reraNumber: json['rera_number'] as String?,
    phone: json['phone'] as String?,
    whatsapp: json['whatsapp'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    officeHours: json['office_hours'] as String?,
    socialLinks: ((json['social_links'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key as String, value as String),
    ),
    salesNotifyEmails: ((json['sales_notify_emails'] as List?) ?? const [])
        .cast<String>(),
    seoTitle: json['seo_title'] as String?,
    seoDescription: json['seo_description'] as String?,
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
  );

  final String companyName;
  final String legalName;
  final String tagline;
  final String descriptor;
  final String? registeredAddress;
  final String? gstNumber;
  final String? reraNumber;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? officeHours;
  final Map<String, String> socialLinks;
  final List<String> salesNotifyEmails;
  final String? seoTitle;
  final String? seoDescription;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'company_name': companyName,
    'legal_name': legalName,
    'tagline': tagline,
    'descriptor': descriptor,
    'registered_address': registeredAddress,
    'gst_number': gstNumber,
    'rera_number': reraNumber,
    'phone': phone,
    'whatsapp': whatsapp,
    'email': email,
    'address': address,
    'office_hours': officeHours,
    'social_links': socialLinks,
    'sales_notify_emails': salesNotifyEmails,
    'seo_title': seoTitle,
    'seo_description': seoDescription,
  };
}

class SettingsRepository {
  SettingsRepository(this._client);

  final SupabaseClient _client;

  Future<SiteSettings> fetch() async => SiteSettings.fromJson(
    await _client.from('site_settings').select().eq('id', 1).single(),
  );

  Future<SiteSettings> save(SiteSettings settings) async =>
      SiteSettings.fromJson(
        await _client
            .from('site_settings')
            .update(settings.toJson())
            .eq('id', 1)
            .select()
            .single(),
      );
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(supabaseProvider)),
);

final siteSettingsProvider = FutureProvider.autoDispose<SiteSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).fetch(),
);
