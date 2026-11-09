import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'content_models.dart';

class ContentRepository {
  ContentRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, ContentBlock>> blocks() async {
    final rows = await _client.from('content_blocks').select();
    return {
      for (final row in rows) row['key'] as String: ContentBlock.fromJson(row),
    };
  }

  Future<void> saveDraft(String key, Map<String, dynamic> value) => _client
      .from('content_blocks')
      .update({'draft': value})
      .eq('key', key)
      .select('key')
      .single();

  Future<void> publish(String key) =>
      _client.rpc<void>('publish_content', params: {'p_key': key});

  Future<void> discard(String key) =>
      _client.rpc<void>('discard_content_draft', params: {'p_key': key});

  /// A one-hour token for the website's private preview pages.
  Future<String> previewToken() async =>
      await _client.rpc<String>('create_content_preview');

  Future<void> reorder(String table, List<String> ids) => _client.rpc<void>(
    'reorder_content',
    params: {'p_table': table, 'p_ids': ids},
  );

  // FAQs ----------------------------------------------------------------------

  Future<List<Faq>> faqs() async {
    final rows = await _client
        .from('faqs')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return rows.map(Faq.fromJson).toList();
  }

  Future<void> saveFaq(String? id, Map<String, dynamic> data) => id == null
      ? _client.from('faqs').insert(data).select('id').single()
      : _client.from('faqs').update(data).eq('id', id).select('id').single();

  Future<void> deleteFaq(String id) =>
      _client.from('faqs').delete().eq('id', id).select('id').single();

  // Testimonials ----------------------------------------------------------------

  Future<List<Testimonial>> testimonials() async {
    final rows = await _client
        .from('testimonials')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return rows.map(Testimonial.fromJson).toList();
  }

  Future<void> saveTestimonial(String? id, Map<String, dynamic> data) =>
      id == null
      ? _client.from('testimonials').insert(data).select('id').single()
      : _client
            .from('testimonials')
            .update(data)
            .eq('id', id)
            .select('id')
            .single();

  Future<void> deleteTestimonial(String id) =>
      _client.from('testimonials').delete().eq('id', id).select('id').single();

  // Banners -------------------------------------------------------------------

  Future<List<BannerItem>> banners() async {
    final rows = await _client
        .from('banners')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return rows.map(BannerItem.fromJson).toList();
  }

  Future<void> saveBanner(String? id, Map<String, dynamic> data) => id == null
      ? _client.from('banners').insert(data).select('id').single()
      : _client.from('banners').update(data).eq('id', id).select('id').single();

  Future<void> deleteBanner(String id) =>
      _client.from('banners').delete().eq('id', id).select('id').single();
}

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(ref.watch(supabaseProvider)),
);

final contentBlocksProvider =
    FutureProvider.autoDispose<Map<String, ContentBlock>>(
      (ref) => ref.watch(contentRepositoryProvider).blocks(),
    );

final faqsProvider = FutureProvider.autoDispose<List<Faq>>(
  (ref) => ref.watch(contentRepositoryProvider).faqs(),
);

final testimonialsProvider = FutureProvider.autoDispose<List<Testimonial>>(
  (ref) => ref.watch(contentRepositoryProvider).testimonials(),
);

final bannersProvider = FutureProvider.autoDispose<List<BannerItem>>(
  (ref) => ref.watch(contentRepositoryProvider).banners(),
);
