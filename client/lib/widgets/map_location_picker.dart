import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';

class MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;

  const MapLocationPicker({super.key, this.initialLocation});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late final MapController _mapController;
  LatLng? _selectedLocation;
  LatLng? _userLocation;
  String? _currentTimeZone;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _updateTimeZone(_selectedLocation!);
      _getUserLocation();
    } else {
      _getUserLocation().then((_) {
        if (_userLocation != null) {
          setState(() {
            _selectedLocation = _userLocation;
          });
          _updateTimeZone(_userLocation!);
        }
      });
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _updateTimeZone(LatLng latLng) async {
    final tz = latLngToTimezoneString(latLng.latitude, latLng.longitude);
    if (!mounted) return;
    setState(() {
      _currentTimeZone = tz;
    });
  }

  Future<List<String>> _getSuggestions(String query) async {
    if (query.isEmpty) return [];
    try {
      final locations = await placemarkFromCoordinates(
        widget.initialLocation?.latitude ?? 0.0,
        widget.initialLocation?.longitude ?? 0.0,
      );
      return locations
          .map((p) => '${p.name}, ${p.locality}, ${p.country}')
          .where((name) => name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _onSearchSelected(String suggestion) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        widget.initialLocation?.latitude ?? 0.0,
        widget.initialLocation?.longitude ?? 0.0,
      );
      final selected = placemarks.firstWhere((p) => '${p.name}, ${p.locality}, ${p.country}' == suggestion);
      final coordinates = await locationFromAddress('${selected.name}, ${selected.locality}, ${selected.country}');
      final newLocation = LatLng(coordinates.first.latitude, coordinates.first.longitude);
      setState(() {
        _selectedLocation = newLocation;
      });
      _mapController.move(newLocation, 15.0);
    } catch (e) {
      // Handle error
    }
  }

  bool _isSameLocation(LatLng? a, LatLng? b, {double epsilon = 1e-6}) {
    if (a == null || b == null) return false;
    return (a.latitude - b.latitude).abs() < epsilon && (a.longitude - b.longitude).abs() < epsilon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: FilledButton.icon(
              icon: Icon(Icons.check, size: 28),
              label: Text("Apply"),
              onPressed:
                  (_selectedLocation == null || _isSameLocation(_selectedLocation, widget.initialLocation))
                      ? null
                      : () {
                        Navigator.pop(context, _selectedLocation);
                      },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation ?? const LatLng(25.0430, 102.7062),
              initialZoom: 4.0,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
                _updateTimeZone(point);
              },
            ),
            children: [
              TileLayer(urlTemplate: 'https://{s}.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['tile']),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      child: Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary, size: 30),
                    ),
                  if (_selectedLocation != null)
                    Marker(
                      point: _selectedLocation!,
                      child: Icon(Icons.location_pin, color: Theme.of(context).colorScheme.error, size: 30),
                    ),
                ],
              ),
            ],
          ),

          Positioned(
            right: 24,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'locate',
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
              onPressed:
                  _userLocation == null
                      ? null
                      : () {
                        setState(() {
                          _selectedLocation = _userLocation;
                        });
                        if (_userLocation != null) {
                          _mapController.move(_userLocation!, _mapController.camera.zoom);
                          _updateTimeZone(_userLocation!);
                        }
                      },
              tooltip: 'Current location',
              child: Icon(Icons.my_location, color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),

          Positioned(
            left: 24,
            bottom: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(128),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLocation == null
                              ? 'Please select a location'
                              : '(${_selectedLocation!.latitude.toStringAsFixed(3)}, ${_selectedLocation!.longitude.toStringAsFixed(3)})',
                          textAlign: TextAlign.left,
                        ),
                        if (_currentTimeZone != null) Text('TZ: $_currentTimeZone'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
