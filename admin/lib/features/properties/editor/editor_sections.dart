import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/number_input.dart';
import '../../../core/theme.dart';
import '../../../core/validators.dart';
import '../../lookups/lookups_repository.dart';
import '../property_enums.dart';
import 'map_picker.dart';
import 'property_form.dart';

const _gap = SizedBox(height: 16);

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: BrandColors.line),
  boxShadow: const [
    BoxShadow(color: Color(0x0A17211D), blurRadius: 18, offset: Offset(0, 6)),
  ],
);

/// Two or three fields side by side on wide screens, stacked on phones.
class _Pair extends StatelessWidget {
  const _Pair(this.children, {this.flex});

  final List<Widget> children;
  final List<int>? flex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Expanded(flex: flex?[i] ?? 1, child: children[i]),
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

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: BrandColors.danger),
            ),
        ],
      ),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: BrandColors.text,
      ),
    ),
  );
}

/// One tap to pick, tap again to clear.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in options)
        ChoiceChip(
          label: Text(label(option)),
          selected: option == selected,
          showCheckmark: false,
          selectedColor: BrandColors.sage,
          side: BorderSide(
            color: option == selected ? BrandColors.forest : BrandColors.line,
          ),
          labelStyle: TextStyle(
            color: option == selected ? BrandColors.forest : BrandColors.text,
            fontWeight: option == selected ? FontWeight.w600 : FontWeight.w400,
          ),
          onSelected: (on) => onChanged(on ? option : null),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Required steps

/// A numbered card for one required part of the form. The number turns
/// into a tick once [done] is true.
class EditorStep extends StatelessWidget {
  const EditorStep({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.child,
    this.watch,
  });

  final int number;
  final String title;
  final String subtitle;
  final bool Function() done;
  final Widget child;

  /// What to listen to so the tick updates while typing.
  final Listenable? watch;

  @override
  Widget build(BuildContext context) {
    Widget header(bool isDone) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? BrandColors.available : BrandColors.sage,
          ),
          child: isDone
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
              : Text(
                  '$number',
                  style: const TextStyle(
                    color: BrandColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.text,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: BrandColors.muted),
              ),
            ],
          ),
        ),
        _Tag(
          label: isDone ? 'Done' : 'Required',
          color: isDone ? BrandColors.available : BrandColors.reserved,
        ),
      ],
    );

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          watch == null
              ? header(done())
              : ListenableBuilder(
                  listenable: watch!,
                  builder: (context, _) => header(done()),
                ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

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
    return EditorStep(
      number: 1,
      title: 'About the land',
      subtitle: 'A clear title and the kind of property.',
      watch: Listenable.merge([form, form.title]),
      done: () => form.title.text.trim().length >= 5 && form.typeId != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Title', required: true),
          TextFormField(
            controller: form.title,
            decoration: const InputDecoration(
              hintText: 'e.g. 200 Sq Yd East Facing Plot in Anandapuram',
            ),
            maxLength: 120,
            validator: (value) => (value ?? '').trim().length < 5
                ? 'Use at least 5 characters.'
                : null,
          ),
          const SizedBox(height: 8),
          const _Label('Property type', required: true),
          FormField<int>(
            validator: (_) => form.typeId == null ? 'Choose a type.' : null,
            builder: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Choices<int>(
                  options: [for (final t in choices) t.id],
                  selected: form.typeId,
                  label: (id) => choices.firstWhere((t) => t.id == id).name,
                  onChanged: (id) {
                    form.set(() => form.typeId = id);
                    state.didChange(id);
                  },
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.errorText!,
                      style: const TextStyle(
                        color: BrandColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _Label('Description'),
          TextFormField(
            controller: form.description,
            decoration: const InputDecoration(
              hintText: 'The land, road access, surroundings and documents.',
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

  @override
  Widget build(BuildContext context) {
    final choices = [
      for (final l in locations)
        if (l.isActive || l.id == form.locationId) l,
    ];
    final pin = _pin;
    return EditorStep(
      number: 2,
      title: 'Location',
      subtitle: 'Where the land is. Drop a pin so buyers can find it.',
      watch: form,
      done: () => form.locationId != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pair([
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Label('City / town', required: true),
                DropdownButtonFormField<String>(
                  initialValue: form.locationId,
                  decoration: const InputDecoration(
                    hintText: 'Choose a city',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  isExpanded: true,
                  items: [
                    for (final l in choices)
                      DropdownMenuItem(value: l.id, child: Text(l.label)),
                  ],
                  validator: (value) =>
                      value == null ? 'Choose a location.' : null,
                  onChanged: (value) => form.set(() => form.locationId = value),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Label('Area / village'),
                TextFormField(
                  controller: form.locality,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Anandapuram',
                  ),
                  validator: (value) => Validators.maxLength(value, 120),
                ),
              ],
            ),
          ]),
          _gap,
          _Pair(
            [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Label('Address or survey number'),
                  TextFormField(
                    controller: form.address,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Sy. No. 112/4, near bus stop',
                    ),
                    validator: (value) => Validators.maxLength(value, 300),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Label('PIN code'),
                  TextFormField(
                    controller: form.pincode,
                    decoration: const InputDecoration(hintText: '530052'),
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
                ],
              ),
            ],
            flex: const [2, 1],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: _Label('Pin on the map')),
              if (pin != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${pin.latitude.toStringAsFixed(5)}, '
                    '${pin.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: BrandColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          MapPicker(
            value: pin,
            onChanged: (point) => form.set(() {
              form.latitude.text = point?.latitude.toStringAsFixed(6) ?? '';
              form.longitude.text = point?.longitude.toStringAsFixed(6) ?? '';
            }),
          ),
          const SizedBox(height: 12),
          _SwitchRow(
            icon: Icons.visibility_outlined,
            title: 'Show the exact location to visitors',
            subtitle: form.showExactLocation
                ? 'Visitors see the exact pin and full address.'
                : 'Visitors see only an area of about 1 km, without the address.',
            value: form.showExactLocation,
            onChanged: (value) =>
                form.set(() => form.showExactLocation = value),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: BrandColors.cream,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: BrandColors.forest),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: BrandColors.muted,
                  ),
                ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
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
    final onRequest = form.priceType == PriceType.onRequest;
    return EditorStep(
      number: 3,
      title: 'Size and price',
      subtitle: 'The plot area and what you are asking for it.',
      watch: Listenable.merge([form, form.areaValue, form.price]),
      done: () {
        final area = parseNumber(form.areaValue.text) ?? 0;
        final price = parseNumber(form.price.text) ?? 0;
        return area > 0 && (form.priceType == PriceType.onRequest || price > 0);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Area', required: true),
          _Pair(
            [
              ListenableBuilder(
                listenable: form.areaValue,
                builder: (context, _) {
                  final value = parseNumber(form.areaValue.text);
                  return TextFormField(
                    controller: form.areaValue,
                    decoration: InputDecoration(
                      hintText: 'e.g. 200',
                      prefixIcon: const Icon(Icons.straighten),
                      helperText:
                          value == null || form.areaUnit == AreaUnit.sqFt
                          ? null
                          : '= ${formatInputNumber(form.areaUnit.toSqft(value).roundToDouble(), rupees: true)} sq ft',
                    ),
                    inputFormatters: [DecimalFormatter()],
                    validator: (v) =>
                        _positive(v, field: 'Area', required: complete),
                  );
                },
              ),
              DropdownButtonFormField<AreaUnit>(
                initialValue: form.areaUnit,
                items: [
                  for (final unit in AreaUnit.values)
                    DropdownMenuItem(value: unit, child: Text(unit.label)),
                ],
                onChanged: (value) =>
                    form.set(() => form.areaUnit = value ?? AreaUnit.sqYd),
              ),
            ],
            flex: const [3, 2],
          ),
          const SizedBox(height: 20),
          const _Label('Price', required: true),
          SegmentedButton<PriceType>(
            showSelectedIcon: false,
            segments: [
              for (final t in PriceType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {form.priceType},
            onSelectionChanged: (value) =>
                form.set(() => form.priceType = value.first),
          ),
          const SizedBox(height: 12),
          if (onRequest)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BrandColors.cream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: BrandColors.muted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Visitors see "Price on request" and are asked to enquire.',
                    ),
                  ),
                ],
              ),
            )
          else
            ListenableBuilder(
              listenable: Listenable.merge([form.price, form.areaValue]),
              builder: (context, _) {
                final value = parseNumber(form.price.text);
                final perUnit = form.autoPricePerUnit;
                return TextFormField(
                  controller: form.price,
                  decoration: InputDecoration(
                    hintText: 'Total price',
                    prefixText: '₹ ',
                    helperText: value == null
                        ? null
                        : [
                            shortRupees(value),
                            if (perUnit != null)
                              '₹${formatInputNumber(perUnit.roundToDouble(), rupees: true)} per ${form.areaUnit.label}',
                          ].join('  ·  '),
                  ),
                  inputFormatters: [IndianNumberFormatter()],
                  validator: (v) =>
                      _positive(v, field: 'Price', required: complete),
                );
              },
            ),
          const SizedBox(height: 12),
          _SwitchRow(
            icon: Icons.handshake_outlined,
            title: 'Price is negotiable',
            value: form.isNegotiable,
            onChanged: (value) => form.set(() => form.isNegotiable = value),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Optional extras, folded away until needed

/// A collapsible card for optional details. Opens by itself when it
/// already holds something.
class OptionalPanel extends StatefulWidget {
  const OptionalPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.filled = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  /// How many of its fields have a value; shown on the header.
  final int filled;

  @override
  State<OptionalPanel> createState() => _OptionalPanelState();
}

class _OptionalPanelState extends State<OptionalPanel> {
  late bool _open = widget.filled > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: BrandColors.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: BrandColors.forest,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: BrandColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.filled > 0)
                    _Tag(
                      label: '${widget.filled} added',
                      color: BrandColors.available,
                    )
                  else
                    const _Tag(label: 'Optional', color: BrandColors.muted),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more,
                      color: BrandColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

int _count(Iterable<Object?> values) => values.where((value) {
  if (value == null || value == false) return false;
  if (value is String) return value.trim().isNotEmpty;
  return true;
}).length;

class DetailsSection extends StatelessWidget {
  const DetailsSection({super.key, required this.form});

  final PropertyFormController form;

  @override
  Widget build(BuildContext context) {
    return OptionalPanel(
      icon: Icons.landscape_outlined,
      title: 'Plot details',
      subtitle: 'Facing, road, dimensions, water and power.',
      filled: _count([
        form.facing,
        form.roadWidthFt.text,
        form.lengthFt.text,
        form.widthFt.text,
        form.isCorner,
        form.waterAvailable,
        form.electricityAvailable,
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Facing'),
          _Choices<Facing>(
            options: Facing.values,
            selected: form.facing,
            label: (f) => f.label,
            onChanged: (value) => form.set(() => form.facing = value),
          ),
          const SizedBox(height: 20),
          _Pair([
            TextFormField(
              controller: form.lengthFt,
              decoration: const InputDecoration(
                labelText: 'Length',
                suffixText: 'ft',
              ),
              inputFormatters: [DecimalFormatter(decimals: 2)],
              validator: (v) => _positive(v, field: 'Length'),
            ),
            TextFormField(
              controller: form.widthFt,
              decoration: const InputDecoration(
                labelText: 'Width',
                suffixText: 'ft',
              ),
              inputFormatters: [DecimalFormatter(decimals: 2)],
              validator: (v) => _positive(v, field: 'Width'),
            ),
            TextFormField(
              controller: form.roadWidthFt,
              decoration: const InputDecoration(
                labelText: 'Road width',
                suffixText: 'ft',
              ),
              inputFormatters: [DecimalFormatter(decimals: 2)],
              validator: (v) => _positive(v, field: 'Road width'),
            ),
          ]),
          const SizedBox(height: 12),
          _SwitchRow(
            icon: Icons.turn_right,
            title: 'Corner plot',
            value: form.isCorner,
            onChanged: (value) => form.set(() => form.isCorner = value),
          ),
          const SizedBox(height: 20),
          _Pair([
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Water available?'),
                _Choices<bool>(
                  options: const [true, false],
                  selected: form.waterAvailable,
                  label: (v) => v ? 'Yes' : 'No',
                  onChanged: (v) => form.set(() => form.waterAvailable = v),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Electricity available?'),
                _Choices<bool>(
                  options: const [true, false],
                  selected: form.electricityAvailable,
                  label: (v) => v ? 'Yes' : 'No',
                  onChanged: (v) =>
                      form.set(() => form.electricityAvailable = v),
                ),
              ],
            ),
          ]),
          if (form.waterAvailable == true) ...[
            _gap,
            TextFormField(
              controller: form.waterSource,
              decoration: const InputDecoration(
                labelText: 'Water source',
                hintText: 'Borewell, municipal…',
              ),
              validator: (v) => Validators.maxLength(v, 80),
            ),
          ],
        ],
      ),
    );
  }
}

class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.form});

  final PropertyFormController form;

  @override
  Widget build(BuildContext context) {
    return OptionalPanel(
      icon: Icons.verified_outlined,
      title: 'Approvals and legal',
      subtitle: 'DTCP / VMRDA approval, RERA number and title summary.',
      filled: _count([
        form.approvalType == ApprovalType.notApplicable
            ? null
            : form.approvalType,
        form.approvalNumber.text,
        form.reraNumber.text,
        form.legalNotes.text,
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Approval'),
          _Choices<ApprovalType>(
            options: [
              for (final a in ApprovalType.values)
                if (a != ApprovalType.notApplicable) a,
            ],
            selected: form.approvalType == ApprovalType.notApplicable
                ? null
                : form.approvalType,
            label: (a) => a.label,
            onChanged: (value) => form.set(
              () => form.approvalType = value ?? ApprovalType.notApplicable,
            ),
          ),
          const SizedBox(height: 20),
          _Pair([
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
    final choices = [
      for (final a in amenities)
        if (a.isActive || form.amenityIds.contains(a.id)) a,
    ];
    return OptionalPanel(
      icon: Icons.auto_awesome_outlined,
      title: 'Highlights and amenities',
      subtitle: 'Selling points and what the layout offers.',
      filled: form.highlights.length + form.amenityIds.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Amenities'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amenity in choices)
                FilterChip(
                  label: Text(amenity.name),
                  selected: form.amenityIds.contains(amenity.id),
                  selectedColor: BrandColors.sage,
                  checkmarkColor: BrandColors.forest,
                  onSelected: (selected) => form.set(() {
                    selected
                        ? form.amenityIds.add(amenity.id)
                        : form.amenityIds.remove(amenity.id);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const _Label('Key selling points'),
          const Text(
            'Up to 8. The first one appears on the property card.',
            style: TextStyle(fontSize: 12, color: BrandColors.muted),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < form.highlights.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: form.highlights[i],
                      decoration: InputDecoration(
                        hintText: i == 0
                            ? 'e.g. 5 minutes from the highway'
                            : 'Another selling point',
                        prefixIcon: const Icon(
                          Icons.star_outline,
                          size: 20,
                        ),
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
            child: OutlinedButton.icon(
              onPressed: form.highlights.length >= 8 ? null : form.addHighlight,
              icon: const Icon(Icons.add),
              label: const Text('Add a selling point'),
            ),
          ),
        ],
      ),
    );
  }
}

class NearbySection extends StatelessWidget {
  const NearbySection({super.key, required this.form});

  final PropertyFormController form;

  @override
  Widget build(BuildContext context) {
    return OptionalPanel(
      icon: Icons.near_me_outlined,
      title: 'Nearby places',
      subtitle: 'Schools, hospitals, bus stops and highways close by.',
      filled: form.nearby.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < form.nearby.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
            child: OutlinedButton.icon(
              onPressed: form.addNearby,
              icon: const Icon(Icons.add),
              label: const Text('Add a nearby place'),
            ),
          ),
        ],
      ),
    );
  }
}

class NotesSection extends StatelessWidget {
  const NotesSection({super.key, required this.form});

  final PropertyFormController form;

  @override
  Widget build(BuildContext context) {
    return OptionalPanel(
      icon: Icons.lock_outline,
      title: 'Private notes',
      subtitle: 'For admins only. Never shown on the website.',
      filled: _count([form.internalNotes.text]),
      child: TextFormField(
        controller: form.internalNotes,
        decoration: const InputDecoration(
          hintText: 'Owner contact, commission, follow-ups…',
        ),
        minLines: 3,
        maxLines: 6,
        maxLength: 5000,
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
    return OptionalPanel(
      icon: Icons.link,
      title: 'Web address',
      subtitle: 'Made from the title and city when you publish.',
      filled: _count([form.slug.text]),
      child: TextFormField(
        controller: form.slug,
        decoration: InputDecoration(
          prefixText: '/land/',
          helperText: everPublished
              ? 'Changing it keeps the old link working (it redirects).'
              : 'Leave empty to create it automatically.',
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
    );
  }
}
