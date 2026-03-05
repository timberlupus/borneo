import 'package:borneo_app/shared/widgets/app_bar_apply_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';

class MapLocationPicker extends StatefulWidget {
  final GlobeCoordinates? initialLocation;

  const MapLocationPicker({super.key, this.initialLocation});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late final FlutterEarthGlobeController _globeController;
  GlobeCoordinates? _selectedLocation;
  GlobeCoordinates? _userLocation;
  String? _currentTimeZone;

  static const _selectedPointId = 'selected';
  static const _userPointId = 'user_location';

  @override
  void initState() {
    super.initState();
    _globeController = FlutterEarthGlobeController(
      rotationSpeed: 0.0,
      isZoomEnabled: true,
      zoom: 0.0,
      surface: const AssetImage('assets/images/2k_earth-day.jpg'),
    );

    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _updateTimeZone(_selectedLocation!);
    }

    _globeController.onLoaded = () {
      if (_selectedLocation != null) {
        _globeController.focusOnCoordinates(_selectedLocation!, animate: false);
        _addSelectedMarker(_selectedLocation!);
      }
      _getUserLocation();
    };
  }

  @override
  void dispose() {
    // Clear the onLoaded callback to prevent stale invocations after unmount.
    // Do NOT call _globeController.dispose() here — its internal AnimationControllers
    // (rotationController, decelerationController, etc.) are owned by RotatingGlobeState
    // and will be disposed when that state is torn down. Double-disposing them causes
    // "AnimationController.dispose() called more than once".
    _globeController.onLoaded = null;
    super.dispose();
  }

  void _addSelectedMarker(GlobeCoordinates coords) {
    _globeController.removePoint(_selectedPointId);
    _globeController.addPoint(
      Point(
        id: _selectedPointId,
        coordinates: coords,
        isLabelVisible: true,
        // Use transparent dot so only the icon label is visible
        style: const PointStyle(color: Colors.transparent, size: 0),
        labelBuilder: (context, point, isHovering, isVisible) =>
            Icon(Icons.location_pin, color: Theme.of(context).colorScheme.error, size: 36),
      ),
    );
  }

  void _addUserLocationMarker(GlobeCoordinates coords) {
    _globeController.removePoint(_userPointId);
    _globeController.addPoint(
      Point(
        id: _userPointId,
        coordinates: coords,
        isLabelVisible: true,
        style: const PointStyle(color: Colors.transparent, size: 0),
        labelBuilder: (context, point, isHovering, isVisible) => Icon(
          Icons.my_location,
          // Semi-transparent to indicate it's the device location, not the selection
          color: Theme.of(context).colorScheme.primary.withAlpha(160),
          size: 28,
        ),
      ),
    );
  }

  Future<void> _getUserLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    final coords = GlobeCoordinates(position.latitude, position.longitude);
    setState(() => _userLocation = coords);
    _addUserLocationMarker(coords);

    // If no initial location was provided, snap to the user's GPS position.
    if (widget.initialLocation == null) {
      setState(() => _selectedLocation = coords);
      _updateTimeZone(coords);
      _globeController.focusOnCoordinates(coords, animate: true);
      _addSelectedMarker(coords);
    }
  }

  void _updateTimeZone(GlobeCoordinates coords) {
    final tz = latLngToTimezoneString(coords.latitude, coords.longitude);
    if (!mounted) return;
    setState(() => _currentTimeZone = tz);
  }

  bool _isSameLocation(GlobeCoordinates? a, GlobeCoordinates? b, {double epsilon = 1e-6}) {
    if (a == null || b == null) return false;
    return (a.latitude - b.latitude).abs() < epsilon && (a.longitude - b.longitude).abs() < epsilon;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.translate('Select Location')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: AppBarApplyButton(
              label: context.translate('Apply'),
              onPressed: (_selectedLocation == null || _isSameLocation(_selectedLocation, widget.initialLocation))
                  ? null
                  : () => Navigator.pop(context, _selectedLocation),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final radius = constraints.biggest.shortestSide * 0.45;
          // FlutterEarthGlobe internally calls MediaQuery.of(context).size to
          // compute the sphere centre. Override it to match the actual body
          // area so the globe is centred rather than offset by the AppBar.
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(size: constraints.biggest),
            child: Stack(
              children: [
                // 3D globe – fills body, centred via alignment
                Positioned.fill(
                  child: FlutterEarthGlobe(
                    controller: _globeController,
                    radius: radius,
                    alignment: Alignment.center,
                    onTap: (coords) {
                      if (coords == null) return;
                      setState(() => _selectedLocation = coords);
                      _updateTimeZone(coords);
                      _addSelectedMarker(coords);
                    },
                  ),
                ),

                // FAB: snap globe to current GPS position
                Positioned(
                  right: 24,
                  bottom: 24 + bottomPadding,
                  child: FloatingActionButton(
                    heroTag: 'locate',
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    tooltip: context.translate('Current location'),
                    onPressed: _userLocation == null
                        ? null
                        : () {
                            setState(() => _selectedLocation = _userLocation);
                            _updateTimeZone(_userLocation!);
                            _addSelectedMarker(_userLocation!);
                            _globeController.focusOnCoordinates(_userLocation!, animate: true);
                          },
                    child: Icon(Icons.my_location, color: Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                ),

                // Bottom-left: coordinates + timezone display
                Positioned(
                  left: 24,
                  bottom: 24 + bottomPadding,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(180),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLocation == null
                                ? context.translate('Tap globe to select location')
                                : '(${_selectedLocation!.latitude.toStringAsFixed(3)},'
                                      ' ${_selectedLocation!.longitude.toStringAsFixed(3)})',
                          ),
                          if (_currentTimeZone != null) Text('TZ: $_currentTimeZone'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
