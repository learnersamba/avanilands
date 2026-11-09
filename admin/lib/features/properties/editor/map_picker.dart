import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';

/// Visakhapatnam — where the map opens when a property has no pin yet.
const defaultMapCenter = LatLng(17.6868, 83.2185);

/// Tap the map to drop the property pin. OpenStreetMap tiles (decision 17).
class MapPicker extends StatefulWidget {
  const MapPicker({super.key, required this.value, required this.onChanged});

  final LatLng? value;
  final ValueChanged<LatLng?> onChanged;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(covariant MapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    // Follow coordinates typed into the fields.
    if (_ready && value != null && value != oldWidget.value) {
      _controller.move(value, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: value ?? defaultMapCenter,
                initialZoom: value == null ? 10 : 15,
                onMapReady: () => _ready = true,
                onTap: (_, point) => widget.onChanged(
                  LatLng(_round(point.latitude), _round(point.longitude)),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.avanilands.admin',
                ),
                if (value != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: value,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          size: 40,
                          color: BrandColors.danger,
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value == null
                      ? 'Tap the map to place the pin'
                      : 'Tap again to move the pin',
                ),
              ),
            ),
            if (value != null)
              Positioned(
                right: 8,
                top: 8,
                child: FilledButton.tonalIcon(
                  onPressed: () => widget.onChanged(null),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove pin'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(6));
}
