import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/env.dart';
import '../../../core/number_input.dart';
import '../../../core/theme.dart';
import '../../../core/validators.dart';
import '../../../core/widgets/common.dart';
import '../../lookups/lookups_repository.dart';
import '../property_enums.dart';
import 'map_picker.dart';
import 'property_form.dart';

const _gap = SizedBox(height: 16);

/// Two fields side by side on wide screens, stacked on phones.
class _Pair extends StatelessWidget {
  const _Pair(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) _gap,
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: children[i]),
          ],
        ],
      );
    },
  );
}

String? _positive(
  String? value, {
  required String field,
  bool required = false,
}) {
  final number = parseNumber(value ?? '');
  if (number == null) return required ? '$field is required.' : null;
  return number > 0 ? null : '$field must be more than 0.';
}

/// Yes / No / Not specified.
class _TriState extends StatelessWidget {
  const _TriState({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<bool?>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: const [
      DropdownMenuItem(value: null, child: Text('Not specified')),
      DropdownMenuItem(value: true, child: Text('Yes')),
      DropdownMenuItem(value: false, child: Text('No')),
    ],
    onChanged: onChanged,
  );
}

// ---------------------------------------------------------------------------

class BasicSection extends StatelessWidget {
  const BasicSection({super.key, required this.form, required this.types});

  final PropertyFormController form;
  final List<PropertyType> types;

  @override
  Widget build(BuildContext context) {
    final choices = [
      for (final t in types)
        if (t.isActive || t.id == form.typeId) t,
    ];
    return SectionCard(
      title: 'Basic information',
      child: Column(
        children: [
          TextFormField(
            controller: form.title,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. 200 Sq Yd East Facing Plot in Anandapuram',
            ),
            maxLength: 120,
            validator: (value) => (value ?? '').trim().length < 5
                ? 'Use at least 5 characters.'
                : null,
          ),
          _gap,
          DropdownButtonFormField<int>(
            initialValue: form.typeId,
            decoration: const InputDecoration(labelText: 'Property type'),
            items: [
              for (final t in choices)
                DropdownMenuItem(value: t.id, child: Text(t.name)),
            ],
            validator: (value) => value == null ? 'Choose a type.' : null,
            onChanged: (value) => form.set(() => form.typeId = value),
          ),
          _gap,
          TextFormField(
            controller: form.description,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              helperText: 'Plain text. Describe the land, access, surroundings and documents.',
            ),
            minLines: 4,
            maxLines: 12,
            maxLength: 10000,
          ),
        ],
      ),
    );
  }
}

class LocationSection extends StatelessWidget {
  const LocationSection({
    super.key,
    required this.form,
    required this.locations,
  });

  final PropertyFormController form;
  final List<Location> locations;

  LatLng? get _pin {
    final lat = parseNumber(form.latitude.text);
    final lng = parseNumber(form.longitude.text);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  String? _coordinate(String? value, double limit, String other) {
    final number = parseNumber(value ?? '');
    final otherSet = other.trim().isNotEmpty;
    if (number == null) {
      return otherSet ? 'Enter both latitude and longitude.' : null;
    }
    if (number.abs() > limit) return 'Must be between -$limit and $limit.';
    return otherSet ? null : 'Enter both latitude and longitude.';
  }

  @override
  Widget build(BuildContext context) {
    final choices = [
      for (final l in locations)
        if (l.isActive || l.id == form.locationId) l,
    ];
    final coordinateFormat = [
      FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,3}(\.\d{0,6})?')),
    ];
    return SectionCard(
      title: 'Location',
      child: Column(
        children: [
          _Pair([
            DropdownButtonFormField<String>(
              initialValue: form.locationId,
              decoration: const InputDecoration(labelText: 'City / town'),
              isExpanded: true,
              items: [
                for (final l in choices)
                  DropdownMenuItem(value: l.id, child: Text(l.label)),
              ],
              validator: (value) => value == null ? 'Choose a location.' : null,
              onChanged: (value) => form.set(() => form.locationId = value),
            ),
            TextFormField(
              controller: form.locality,
              decoration: const InputDecoration(
                labelText: 'Area / village',
                hintText: 'e.g. Anandapuram',
              ),
              validator: (value) => Validators.maxLength(value, 120),
            ),
          ]),
          _gap,
          _Pair([
            TextFormField(
              controller: form.address,
              decoration: const InputDecoration(
                labelText: 'Full address or survey number',
              ),
              validator: (value) => Validators.maxLength(value, 300),
            ),
            TextFormField(
              controller: form.pincode,
              decoration: const InputDecoration(labelText: 'PIN code'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (value) =>
                  (value == null ||
                      value.isEmpty ||
                      RegExp(r'^[1-9][0-9]{5}$').hasMatch(value))
                  ? null
                  : 'Six digits, e.g. 530017.',
            ),
          ]),
          _gap,
          _Pair([
            TextFormField(
              controller: form.latitude,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: '17.686800',
              ),
              inputFormatters: coordinateFormat,
              validator: (value) => _coordinate(value, 90, form.longitude.text),
              onChanged: (_) => form.set(() {}),
            ),
            TextFormField(
              controller: form.longitude,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: '83.218500',
              ),
              inputFormatters: coordinateFormat,
              validator: (value) => _coordinate(value, 180, form.latitude.text),
              onChanged: (_) => form.set(() {}),
            ),
          ]),
          _gap,
          MapPicker(
            value: _pin,
            onChanged: (point) => form.set(() {
              form.latitude.text = point?.latitude.toStringAsFixed(6) ?? '';
              form.longitude.text = point?.longitude.toStringAsFixed(6) ?? '';
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show the exact location to visitors'),
            subtitle: Text(
              form.showExactLocation
                  ? 'Visitors see the exact pin and full address.'
                  : 'Visitors see only an area of about 1 km, without the address.',
            ),
            value: form.showExactLocation,
            onChanged: (value) =>
                form.set(() => form.showExactLocation = value),
          ),
        ],
      ),
    );
  }
}

class SizePriceSection extends StatelessWidget {
  const SizePriceSection({
    super.key,
    required this.form,
    required this.complete,
  });

  final PropertyFormController form;

  /// Published / hidden / archived properties must have area and price.
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final decimals = [DecimalFormatter()];
    final rupees = [IndianNumberFormatter()];
    return SectionCard(
      title: 'Size and price',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pair([
            ListenableBuilder(
              listenable: form.areaValue,
              builder: (context, _) {
                final value = parseNumber(form.areaValue.text);
                return TextFormField(
                  controller: form.areaValue,
                  decoration: InputDecoration(
                    labelText: 'Area',
                    helperText: value == null || form.areaUnit == AreaUnit.sqFt
                        ? null
                        : '= ${formatInputNumber(form.areaUnit.toSqft(value).roundToDouble(), rupees: true)} sq ft',
                  ),
                  inputFormatters: decimals,
                  validator: (v) =>
                      _positive(v, field: 'Area', required: complete),
                );
              },
            ),
            DropdownButtonFormField<AreaUnit>(
              initialValue: form.areaUnit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: [
                for (final unit in AreaUnit.values)
                  DropdownMenuItem(value: unit, child: Text(unit.label)),
              ],
              onChanged: (value) =>
                  form.set(() => form.areaUnit = value ?? AreaUnit.sqYd),
            ),
          ]),
          _gap,
          _Pair([
            TextFormField(
              controller: form.lengthFt,
              decoration: const InputDecoration(labelText: 'Length (ft)'),
              inputFormatters: [DecimalFormatter(decimals: 2)],
              validator: (v) => _positive(v, field: 'Length'),
            ),
            TextFormField(
              controller: form.widthFt,
              decoration: const InputDecoration(labelText: 'Width (ft)'),
              inputFormatters: [DecimalFormatter(decimals: 2)],
              validator: (v) => _positive(v, field: 'Width'),
            ),
            TextFormField(
              controller: form.dimensionsText,
              decoration: const InputDecoration(
                labelText: 'Dimensions note',
                hintText: 'e.g. Irregular, corner',
              ),
              validator: (v) => Validators.maxLength(v, 120),
            ),
          ]),
          const SizedBox(height: 24),
          SegmentedButton<PriceType>(
            segments: [
              for (final t in PriceType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {form.priceType},
            onSelectionChanged: (value) =>
                form.set(() => form.priceType = value.first),
          ),
          _gap,
          if (form.priceType == PriceType.total) ...[
            _Pair([
              ListenableBuilder(
                listenable: form.price,
                builder: (context, _) {
                  final value = parseNumber(form.price.text);
                  return TextFormField(
                    controller: form.price,
                    decoration: InputDecoration(
                      labelText: 'Total price',
                      prefixText: '₹ ',
                      helperText: value == null ? null : shortRupees(value),
                    ),
                    inputFormatters: rupees,
                    validator: (v) =>
                        _positive(v, field: 'Price', required: complete),
                  );
                },
              ),
              TextFormField(
                controller: form.pricePerUnit,
                decoration: const InputDecoration(
                  labelText: 'Price per unit (optional)',
                  prefixText: '₹ ',
                ),
                inputFormatters: rupees,
                validator: (v) => _positive(v, field: 'Price per unit'),
              ),
              DropdownButtonFormField<AreaUnit>(
                initialValue: form.pricePerUnitUnit ?? form.areaUnit,
                decoration: const InputDecoration(labelText: 'per'),
                items: [
                  for (final unit in AreaUnit.values)
                    DropdownMenuItem(value: unit, child: Text(unit.label)),
                ],
                onChanged: (value) =>
                    form.set(() => form.pricePerUnitUnit = value),
              ),
            ]),
          ] else
            const Text(
              'Visitors see "Price on request" and are asked to enquire.',
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Negotiable'),
            value: form.isNegotiable,
            onChanged: (value) => form.set(() => form.isNegotiable = value),
          ),
        ],
      ),
    );
  }
}

class DetailsSection extends StatelessWidget {
  const DetailsSection({super.key, required this.form});

  final PropertyFormController form;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Property details',
      child: Column(
        children: [
          _Pair([
            DropdownButtonFormField<Facing?>(
              initialValue: form.facing,
              decoration: const InputDecoration(labelText: 'Facing'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Not specified'),
                ),
                for (final f in Facing.values)
                  DropdownMenuItem(value: f, child: Text(f.label)),
              ],
              onChanged: (value) => form.set(() => form.facing = value),
            ),
            TextFormField(
              controller: form.roadWidthFt,
              decoration: const InputDecoration(labelText: 'Road width (ft)'),
              inputFormatters: [DecimalFormatter(decimals: 2)],
              validator: (v) => _positive(v, field: 'Road width'),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Corner plot'),
            value: form.isCorner,
            onChanged: (value) => form.set(() => form.isCorner = value),
          ),
          _Pair([
            _TriState(
              label: 'Water available',
              value: form.waterAvailable,
              onChanged: (value) => form.set(() => form.waterAvailable = value),
            ),
            TextFormField(
              controller: form.waterSource,
              decoration: const InputDecoration(
                labelText: 'Water source',
                hintText: 'Borewell, municipal…',
              ),
              validator: (v) => Validators.maxLength(v, 80),
            ),
            _TriState(
              label: 'Electricity available',
              value: form.electricityAvailable,
              onChanged: (value) =>
                  form.set(() => form.electricityAvailable = value),
            ),
          ]),
          _gap,
          _Pair([
            DropdownButtonFormField<ApprovalType>(
              initialValue: form.approvalType,
              decoration: const InputDecoration(labelText: 'Approval'),
              items: [
                for (final a in ApprovalType.values)
                  DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: (value) => form.set(
                () => form.approvalType = value ?? ApprovalType.notApplicable,
              ),
            ),
            TextFormField(
              controller: form.approvalNumber,
              decoration: const InputDecoration(labelText: 'Approval number'),
              validator: (v) => Validators.maxLength(v, 80),
            ),
            TextFormField(
              controller: form.reraNumber,
              decoration: const InputDecoration(labelText: 'RERA number'),
              validator: (v) => Validators.maxLength(v, 80),
            ),
          ]),
          _gap,
          TextFormField(
            controller: form.legalNotes,
            decoration: const InputDecoration(
              labelText: 'Legal summary (shown to visitors)',
              hintText:
                  'e.g. Clear title. Registered sale deed and EC available.',
              alignLabelWithHint: true,
            ),
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
          ),
          _gap,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BrandColors.reserved.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: BrandColors.reserved.withValues(alpha: 0.4),
              ),
            ),
            child: TextFormField(
              controller: form.internalNotes,
              decoration: const InputDecoration(
                labelText:
                    'Internal notes — admins only, never shown on the website',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.lock_outline),
              ),
              minLines: 2,
              maxLines: 6,
              maxLength: 5000,
            ),
          ),
        ],
      ),
    );
  }
}

class HighlightsSection extends StatelessWidget {
  const HighlightsSection({
    super.key,
    required this.form,
    required this.amenities,
  });

  final PropertyFormController form;
  final List<Amenity> amenities;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final choices = [
      for (final a in amenities)
        if (a.isActive || form.amenityIds.contains(a.id)) a,
    ];
    return SectionCard(
      title: 'Highlights, amenities and nearby places',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Key selling points (up to 8). The first one appears on the property card.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < form.highlights.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: form.highlights[i],
                      decoration: InputDecoration(
                        labelText: 'Highlight ${i + 1}',
                        counterText: '',
                      ),
                      maxLength: 80,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Write something or remove it.'
                          : null,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move up',
                    onPressed: i == 0 ? null : () => form.moveHighlight(i, -1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => form.removeHighlight(i),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: form.highlights.length >= 8 ? null : form.addHighlight,
              icon: const Icon(Icons.add),
              label: const Text('Add highlight'),
            ),
          ),
          const Divider(height: 32),
          Text('Amenities', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amenity in choices)
                FilterChip(
                  label: Text(amenity.name),
                  selected: form.amenityIds.contains(amenity.id),
                  onSelected: (selected) => form.set(() {
                    selected
                        ? form.amenityIds.add(amenity.id)
                        : form.amenityIds.remove(amenity.id);
                  }),
                ),
            ],
          ),
          const Divider(height: 32),
          Text('Nearby places', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < form.nearby.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: form.nearby[i].name,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. GITAM University',
                      ),
                      validator: (v) {
                        final length = (v ?? '').trim().length;
                        return length < 2
                            ? 'Too short.'
                            : (length > 80 ? 'Too long.' : null);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<NearbyCategory>(
                      initialValue: form.nearby[i].category,
                      decoration: const InputDecoration(labelText: 'Type'),
                      isExpanded: true,
                      items: [
                        for (final c in NearbyCategory.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: (value) => form.set(
                        () => form.nearby[i].category =
                            value ?? NearbyCategory.other,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: form.nearby[i].distance,
                      decoration: const InputDecoration(
                        labelText: 'Distance',
                        suffixText: 'km',
                      ),
                      inputFormatters: [DecimalFormatter(decimals: 2)],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move up',
                    onPressed: i == 0 ? null : () => form.moveNearby(i, -1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => form.removeNearby(i),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: form.addNearby,
              icon: const Icon(Icons.add),
              label: const Text('Add nearby place'),
            ),
          ),
        ],
      ),
    );
  }
}

class SeoSection extends StatelessWidget {
  const SeoSection({
    super.key,
    required this.form,
    required this.everPublished,
  });

  final PropertyFormController form;
  final bool everPublished;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Web address and search engines',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: form.slug,
            decoration: InputDecoration(
              labelText: 'Web address',
              prefixText: '/land/',
              helperText: everPublished
                  ? 'Changing it keeps the old link working (it redirects).'
                  : 'Leave empty to create it from the title and city when you publish.',
            ),
            validator: (value) =>
                (value == null ||
                    value.isEmpty ||
                    RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(value))
                ? (value != null && value.length > 100
                      ? 'Keep it under 100 characters.'
                      : null)
                : 'Lowercase letters, numbers and dashes only.',
          ),
          _gap,
          TextFormField(
            controller: form.seoTitle,
            decoration: const InputDecoration(
              labelText: 'Search title (optional)',
              helperText: 'Defaults to the title.',
            ),
            maxLength: 70,
          ),
          _gap,
          TextFormField(
            controller: form.seoDescription,
            decoration: const InputDecoration(
              labelText: 'Search description (optional)',
              helperText: 'Defaults to the start of the description.',
            ),
            maxLength: 170,
            maxLines: 3,
          ),
          _gap,
          Text('Preview in Google', style: textTheme.bodySmall),
          const SizedBox(height: 6),
          ListenableBuilder(
            listenable: Listenable.merge([
              form.title,
              form.seoTitle,
              form.seoDescription,
              form.description,
              form.slug,
            ]),
            builder: (context, _) {
              final title = form.seoTitle.text.trim().isNotEmpty
                  ? form.seoTitle.text.trim()
                  : form.title.text.trim();
              final description = form.seoDescription.text.trim().isNotEmpty
                  ? form.seoDescription.text.trim()
                  : form.description.text.trim();
              final slug = form.slug.text.trim().isEmpty
                  ? '…'
                  : form.slug.text.trim();
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: BrandColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Uri.parse(Env.websiteUrl).host} › land › $slug',
                      style: textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      title.isEmpty ? 'Title' : title,
                      style: textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1A0DAB),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      description.isEmpty ? 'Description' : description,
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
