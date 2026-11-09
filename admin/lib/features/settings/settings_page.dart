import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../site_visits/visit_settings_card.dart';
import 'settings_repository.dart';

/// Company contact details, sales alert emails and default SEO text.
/// Super admins only (router guard + database rule).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageBody(
      maxWidth: 860,
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle: 'Contact details shown on the website, and where enquiry alerts go.',
        ),
        AsyncValueView(
          value: ref.watch(siteSettingsProvider),
          onRetry: () => ref.invalidate(siteSettingsProvider),
          data: (settings) => _SettingsForm(settings: settings),
        ),
        const SizedBox(height: 32),
        const VisitSettingsCard(),
      ],
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});

  final SiteSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  static const _socialKeys = ['facebook', 'instagram', 'youtube'];

  final _formKey = GlobalKey<FormState>();
  late final _company = TextEditingController(
    text: widget.settings.companyName,
  );
  late final _phone = TextEditingController(text: widget.settings.phone);
  late final _whatsapp = TextEditingController(text: widget.settings.whatsapp);
  late final _email = TextEditingController(text: widget.settings.email);
  late final _address = TextEditingController(text: widget.settings.address);
  late final _hours = TextEditingController(text: widget.settings.officeHours);
  late final _alerts = TextEditingController(
    text: widget.settings.salesNotifyEmails.join(', '),
  );
  late final _seoTitle = TextEditingController(text: widget.settings.seoTitle);
  late final _seoDescription = TextEditingController(
    text: widget.settings.seoDescription,
  );
  late final _social = {
    for (final key in _socialKeys)
      key: TextEditingController(text: widget.settings.socialLinks[key]),
  };
  bool _busy = false;
  DateTime? _savedAt;

  @override
  void initState() {
    super.initState();
    _savedAt = widget.settings.updatedAt;
  }

  @override
  void dispose() {
    for (final controller in [
      _company,
      _phone,
      _whatsapp,
      _email,
      _address,
      _hours,
      _alerts,
      _seoTitle,
      _seoDescription,
      ..._social.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  List<String> get _alertEmails => _alerts.text
      .split(RegExp(r'[,\s]+'))
      .map((email) => email.trim())
      .where((email) => email.isNotEmpty)
      .toList();

  String? _validateAlerts(String? _) {
    final emails = _alertEmails;
    if (emails.length > 5) return 'Up to 5 addresses.';
    for (final email in emails) {
      if (Validators.email(email) != null) {
        return '"$email" is not a valid email.';
      }
    }
    return null;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    return (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty)
        ? null
        : 'Use a full https:// link.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .save(
            SiteSettings(
              companyName: _company.text.trim(),
              phone: _text(_phone),
              whatsapp: _text(_whatsapp),
              email: _text(_email)?.toLowerCase(),
              address: _text(_address),
              officeHours: _text(_hours),
              socialLinks: {
                for (final entry in _social.entries)
                  if (_text(entry.value) != null)
                    entry.key: _text(entry.value)!,
              },
              salesNotifyEmails: _alertEmails
                  .map((email) => email.toLowerCase())
                  .toList(),
              seoTitle: _text(_seoTitle),
              seoDescription: _text(_seoDescription),
            ),
          );
      if (!mounted) return;
      setState(() => _savedAt = saved.updatedAt);
      showMessage(context, 'Settings saved.');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Company and contact',
            child: Column(
              children: [
                TextFormField(
                  controller: _company,
                  decoration: const InputDecoration(labelText: 'Company name'),
                  validator: (value) =>
                      Validators.required(value, field: 'Company name') ??
                      Validators.maxLength(value, 80),
                ),
                gap,
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Sales phone',
                    hintText: '+91 90000 00000',
                  ),
                  validator: (value) => Validators.maxLength(value, 20),
                ),
                gap,
                TextFormField(
                  controller: _whatsapp,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp number',
                    hintText: '919000000000',
                    helperText: 'Digits only, with the country code. Used for the WhatsApp buttons.',
                  ),
                  keyboardType: TextInputType.number,
                  validator: Validators.whatsapp,
                ),
                gap,
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Public email'),
                  validator: Validators.optionalEmail,
                ),
                gap,
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Office address',
                  ),
                  maxLines: 2,
                  validator: (value) => Validators.maxLength(value, 300),
                ),
                gap,
                TextFormField(
                  controller: _hours,
                  decoration: const InputDecoration(
                    labelText: 'Office hours',
                    hintText: 'Mon–Sat, 9:30 am – 6:30 pm',
                  ),
                  validator: (value) => Validators.maxLength(value, 120),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Enquiry alerts',
            child: TextFormField(
              controller: _alerts,
              decoration: const InputDecoration(
                labelText: 'Send new-enquiry emails to',
                helperText: 'Up to 5 addresses, separated by commas. Not shown on the website.',
              ),
              validator: _validateAlerts,
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Social links',
            child: Column(
              children: [
                for (final key in _socialKeys) ...[
                  TextFormField(
                    controller: _social[key],
                    decoration: InputDecoration(
                      labelText: humanize(key),
                      hintText: 'https://',
                    ),
                    validator: _validateUrl,
                  ),
                  if (key != _socialKeys.last) gap,
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Search engines (default)',
            child: Column(
              children: [
                TextFormField(
                  controller: _seoTitle,
                  decoration: const InputDecoration(labelText: 'Website title'),
                  maxLength: 70,
                ),
                gap,
                TextFormField(
                  controller: _seoDescription,
                  decoration: const InputDecoration(
                    labelText: 'Website description',
                  ),
                  maxLength: 170,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save settings'),
              ),
              const SizedBox(width: 16),
              if (_savedAt != null)
                Flexible(
                  child: Text(
                    'Last saved ${formatDateTime(_savedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
