import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// The single `site_settings` row.
class SiteSettings {
  const SiteSettings({
    required this.companyName,
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
