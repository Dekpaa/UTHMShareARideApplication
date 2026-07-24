import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uthmshareride/modules/Message/passtodrivermessage.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/modules/Message/drivertopassmessage.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class DriverTrackRidePage extends StatefulWidget {
  final String rideId;
  final String driverId;
  final bool isResuming;

  const DriverTrackRidePage({
    super.key,
    required this.rideId,
    required this.driverId,
    this.isResuming = false,
  });

  @override
  State<DriverTrackRidePage> createState() => _DriverTrackRidePageState();
}

class _DriverTrackRidePageState extends State<DriverTrackRidePage> {
  final String googleApiKey = "";

  Ride? _ride;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<Ride>>? _ridesStreamSub;
  Timer? _locationUpdateTimer;
  GoogleMapController? _mapController;

  String _trackingStatus = "Waiting for location...";
  double _mapZoom = 16.0;

  List<LatLng> _roadPolylinePoints = [];
  List<LatLng> _driverHistory = [];
  double? _etaMinutes;
  double? _remainingDistanceKm;

  // ✅ TAMBAH: Variabel untuk driver ke start route
  List<LatLng> _driverToStartRoute = [];
  bool _showDriverToStartRoute = false;

  // arrival
  double _arrivalThresholdMeters = 40.0;
  bool _arrivedTriggered = false;

  // generated car icon & rotation
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _startIcon; 
  double _carRotation = 0.0;

  // zoom step
  final double _zoomStep = 1.0;

  // Variable untuk track jika ini resume
  bool _isTrackingActive = false;

  @override
  void initState() {
    super.initState();
    _createCarIcon();
    _createStartIcon();
    _loadRideDetails();
    _startLocationUpdates();
    _listenToRideStream();
    
    // ✅ TAMBAH: Compute driver route segera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPosition != null && _ride != null) {
        _updateDriverToStartRoute();
      }
    });
    
    _isTrackingActive = widget.isResuming;
  }

  // ✅ TAMBAH: Function untuk fetch directions dari driver ke start
  Future<List<LatLng>> _fetchDriverToStartDirections(LatLng driverPos, LatLng startPos) async {
    try {
      final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${driverPos.latitude},${driverPos.longitude}&"
        "destination=${startPos.latitude},${startPos.longitude}&"
        "mode=driving&"
        "key=$googleApiKey"
      );
      
      final res = await http.get(url);
      if (res.statusCode != 200) return [driverPos, startPos];
      
      final data = jsonDecode(res.body);
      if (data["status"] != "OK" || data["routes"] == null || data["routes"].isEmpty) {
        return [driverPos, startPos];
      }
      
      final route = data["routes"][0];
      if (route["overview_polyline"] == null) {
        return [driverPos, startPos];
      }
      
      String encodedPolyline = route["overview_polyline"]["points"];
      return _decodePolyline(encodedPolyline);
    } catch (e) {
      debugPrint('❌ Driver-to-start directions error: $e');
      return [driverPos, startPos];
    }
  }

  // ✅ TAMBAH: Function untuk update rute driver ke start
  Future<void> _updateDriverToStartRoute() async {
    if (_currentPosition == null || _ride == null || 
        _ride!.startLat == null || _ride!.startLng == null) {
      return;
    }
    
    final driverPos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final startPos = LatLng(_ride!.startLat!, _ride!.startLng!);
    
    // Check distance - jika < 50m, jangan tunjuk
    final distanceToStart = _distanceMeters(driverPos, startPos);
    
    if (distanceToStart < 50) {
      setState(() {
        _driverToStartRoute.clear();
        _showDriverToStartRoute = false;
      });
      return;
    }
    
    try {
      final routePoints = await _fetchDriverToStartDirections(driverPos, startPos);
      
      if (routePoints.isNotEmpty) {
        setState(() {
          _driverToStartRoute = routePoints;
          _showDriverToStartRoute = true;
        });
        debugPrint('✅ Driver-to-start route loaded (${routePoints.length} points)');
      }
    } catch (e) {
      debugPrint('❌ Driver-to-start error: $e');
      // Fallback ke garis lurus
      setState(() {
        _driverToStartRoute = [driverPos, startPos];
        _showDriverToStartRoute = true;
      });
    }
  }

  Future<void> _createCarIcon() async {
    try {
      final BitmapDescriptor bmp = await _bitmapDescriptorFromIcon(
        Icons.directions_car,
        iconColor: Colors.blue,
        size: 96,
      );
      setState(() => _carIcon = bmp);
    } catch (e) {
      debugPrint('createCarIcon error: $e');
    }
  }

  Future<void> _createStartIcon() async {
    try {
      final BitmapDescriptor bmp = await _bitmapDescriptorFromIcon(
        Icons.flag,
        iconColor: Colors.orange,
        size: 72,
      );
      setState(() => _startIcon = bmp);
    } catch (e) {
      debugPrint('createStartIcon error: $e');
    }
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromIcon(
    IconData icon, {
    Color iconColor = Colors.black,
    int size = 64,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size.toDouble(),
        fontFamily: icon.fontFamily,
        color: iconColor,
      ),
    );

    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(size, size);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _ridesStreamSub?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadRideDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _ride = Ride.fromFirestore(data, widget.rideId);
          _isTrackingActive = data['isTracking'] ?? false;
        });
      } else {
        _ride = RideStorage().getRideById(widget.rideId);
      }
    } catch (e) {
      debugPrint('Error loading ride details: $e');
      _ride = RideStorage().getRideById(widget.rideId);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _computeRoadRoute(forceFromStartToEnd: true);
    });
    setState(() {});
  }

  void _listenToRideStream() {
    _ridesStreamSub = RideStorage().ridesStream.listen(
      (rides) async {
        final matched = rides.where((r) => r.id == widget.rideId).toList();
        final updated = matched.isNotEmpty ? matched.first : _ride;

        if (mounted && updated != null) {
          setState(() => _ride = updated);
          await _computeRoadRoute(forceFromStartToEnd: true);
        }
      },
      onError: (e) {
        debugPrint('rides stream error: $e');
      },
    );
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission perm = await Geolocator.checkPermission();

    if (!serviceEnabled) {
      setState(() => _trackingStatus = 'Location services disabled');
      return;
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _trackingStatus = 'Location permission denied');
        return;
      }
    }

    await _updateRideTrackingStatus(true);
    
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      _handlePosition(pos);
    });

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        _handlePosition(pos);
      } catch (_) {}
    });

    setState(() {
      _isTrackingActive = true;
      _trackingStatus = widget.isResuming ? "Resumed tracking" : "Tracking started";
    });
  }

  Future<void> _updateRideTrackingStatus(bool isTracking) async {
    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
            'isTracking': isTracking,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error updating tracking status: $e');
    }
  }

  Future<void> _updateRideArrivalStatus(bool hasArrived) async {
    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
            'hasArrived': hasArrived,
            'isTracking': false,
            'arrivedAt': hasArrived ? FieldValue.serverTimestamp() : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error updating arrival status: $e');
    }
  }

  Future<void> _updateRideLocationToFirestore(double lat, double lng) async {
    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
            'driverLocation': {
              'latitude': lat,
              'longitude': lng,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          });
    } catch (e) {
      debugPrint('Error updating ride location: $e');
    }
  }

  Future<void> _saveRouteToFirestore(List<LatLng> points) async {
    try {
      final data = points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
            'routePolyline': data,
            'routeUpdatedAt': FieldValue.serverTimestamp(),
          });
      debugPrint('✅ Saved ${points.length} route points to Firestore');
    } catch (e) {
      debugPrint('❌ Failed saving route to Firestore: $e');
    }
  }

  void _handlePosition(Position pos) async {
    final newLocation = LatLng(pos.latitude, pos.longitude);
    
    if (_currentPosition != null && 
        _distanceMeters(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
          newLocation
        ) > 20) { // ✅ Update threshold menjadi 20 meter
      _driverHistory.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      
      // ✅ TAMBAH: Update rute driver ke start bila driver bergerak cukup jauh
      _updateDriverToStartRoute();
    }

    setState(() {
      _currentPosition = pos;
      _trackingStatus = "On the way";
    });

    if (_roadPolylinePoints.isNotEmpty) {
      final next = _findNextPointOnRoad(newLocation);
      if (next != null) {
        _carRotation = _bearing(newLocation, next);
      }
    }

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: newLocation, zoom: _mapZoom),
      ),
    );

    RideStorage().updateRideLocation(
      widget.rideId,
      pos.latitude,
      pos.longitude,
    );
    
    await _updateRideLocationToFirestore(pos.latitude, pos.longitude);
    await _computeRoadRoute(forceFromStartToEnd: true);
    _checkAutoArrival(newLocation);
  }

  LatLng? _findNextPointOnRoad(LatLng current) {
    if (_roadPolylinePoints.isEmpty) return null;
    for (final p in _roadPolylinePoints) {
      final d = _distanceMeters(current, p);
      if (d > 2) return p;
    }
    return _roadPolylinePoints.last;
  }

  Future<void> _computeRoadRoute({bool forceFromStartToEnd = false}) async {
    if (_ride == null) return;
    
    // ✅ TAMBAH: Update driver-to-start route setiap kali compute main route
    if (_currentPosition != null && _ride!.startLat != null && _ride!.startLng != null) {
      _updateDriverToStartRoute();
    }
    
    if (_ride!.endLat == null || _ride!.endLng == null) return;

    LatLng originCoord;
    if (forceFromStartToEnd &&
        _ride!.startLat != null &&
        _ride!.startLng != null) {
      originCoord = LatLng(_ride!.startLat!, _ride!.startLng!);
    } else if (_currentPosition != null) {
      originCoord = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    } else if (_ride!.startLat != null && _ride!.startLng != null) {
      originCoord = LatLng(_ride!.startLat!, _ride!.startLng!);
    } else {
      return;
    }

    final origin = "${originCoord.latitude},${originCoord.longitude}";
    final dest = "${_ride!.endLat},${_ride!.endLng}";

    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json?"
      "origin=$origin&destination=$dest"
      "&key=AIzaSyA8XyUAaBTUaIFZnyJFenC41_paHZelsXk"
      "&mode=driving"
      "&alternatives=true",
    );

    try {
      final res = await http.get(url);
      if (res.statusCode != 200) {
        debugPrint('❌ API Response failed: ${res.statusCode}');
        return;
      }

      final data = jsonDecode(res.body);
      
      if (data["status"] != "OK") {
        debugPrint('❌ Directions API Status: ${data["status"]}');
        return;
      }
      
      if (data["routes"] == null || data["routes"].isEmpty) {
        debugPrint('❌ No routes found in response');
        return;
      }

      final route = data["routes"][0];
      
      if (route["overview_polyline"] == null) {
        debugPrint('❌ No overview_polyline in route');
        return;
      }
      
      String encodedPolyline = route["overview_polyline"]["points"];
      List<LatLng> newPolyline = _decodePolyline(encodedPolyline);
      
      debugPrint('✅ Polyline decoded successfully!');
      debugPrint('✅ Number of points: ${newPolyline.length}');
      
      if (newPolyline.length > 1) {
        await _saveRouteToFirestore(newPolyline);
      }
      
      setState(() {
        _roadPolylinePoints = newPolyline;
      });
      
      _calculateDistanceAndETA();
      
    } catch (e) {
      debugPrint('❌ Directions API error: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return poly;
  }

  void _calculateDistanceAndETA() {
    if (_roadPolylinePoints.isEmpty || _ride?.endLat == null || _ride?.endLng == null) {
      return;
    }
    
    try {
      double totalDistance = 0.0;
      
      for (int i = 0; i < _roadPolylinePoints.length - 1; i++) {
        totalDistance += _distanceMeters(_roadPolylinePoints[i], _roadPolylinePoints[i + 1]);
      }
      
      _remainingDistanceKm = totalDistance / 1000;
      
      const double averageSpeedKmh = 40.0;
      if (_remainingDistanceKm! > 0) {
        _etaMinutes = (_remainingDistanceKm! / averageSpeedKmh) * 60;
        _etaMinutes = _etaMinutes! * 1.3;
      }
      
      debugPrint('📏 Route distance: ${_remainingDistanceKm!.toStringAsFixed(2)} km, ETA: ${_etaMinutes!.round()} min');
      setState(() {});
    } catch (e) {
      debugPrint('❌ Error calculating route distance: $e');
    }
  }

  void _checkAutoArrival(LatLng current) {
    if (_arrivedTriggered) return;
    if (_ride == null || _ride!.endLat == null || _ride!.endLng == null) return;

    final dest = LatLng(_ride!.endLat!, _ride!.endLng!);
    final dist = _distanceMeters(current, dest);

    if (dist <= _arrivalThresholdMeters) {
      _arrivedTriggered = true;
      
      _updateRideArrivalStatus(true);
      
      RideStorage().setRideArrivalStatus(widget.rideId, true);
      
      setState(() {
        _trackingStatus = "Arrived at destination";
        _isTrackingActive = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Auto arrived at destination'),
        backgroundColor: Colors.green,
      ));
      
      Future.delayed(const Duration(seconds: 2), () => _stopTrackingAndPop());
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const double R = 6371000;
    double dLat = _deg(b.latitude - a.latitude);
    double dLon = _deg(b.longitude - a.longitude);
    double lat1 = _deg(a.latitude);
    double lat2 = _deg(b.latitude);

    double h = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    return 2 * R * asin(sqrt(h));
  }

  double _deg(double v) => v * (pi / 180);

  double _bearing(LatLng from, LatLng to) {
    final lat1 = _deg(from.latitude);
    final lat2 = _deg(to.latitude);
    final dLon = _deg(to.longitude - from.longitude);
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final brng = atan2(y, x);
    return (brng * 180.0 / pi + 360.0) % 360.0;
  }

  Future<void> _stopTracking() async {
    _positionStreamSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    
    await _updateRideTrackingStatus(false);
    
    RideStorage().setRideTrackingStatus(widget.rideId, false);
    
    setState(() {
      _isTrackingActive = false;
      _trackingStatus = "Tracking stopped";
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracking stopped. You can resume from My Rides.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
    
    Navigator.pop(context);
  }

  void _stopTrackingAndPop() {
    _positionStreamSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    
    _updateRideTrackingStatus(false);
    
    RideStorage().setRideTrackingStatus(widget.rideId, false);
    
    Navigator.pop(context);
  }

  Future<void> _manualArrive() async {
    _arrivedTriggered = true;
    
    await _updateRideArrivalStatus(true);
    
    RideStorage().setRideArrivalStatus(widget.rideId, true);
    
    setState(() {
      _trackingStatus = "Arrived at destination";
      _isTrackingActive = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marked as arrived. Ride can be completed in My Rides.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 800), () => _stopTrackingAndPop());
  }
  
  String? _passengerName() {
    if (_ride == null) return null;
    if (_ride!.bookings.isEmpty) return null;
    final accepted = _ride!.bookings.where((b) => b.status == BookingStatus.accepted).toList();
    if (accepted.isNotEmpty) return accepted.first.passengerName;
    return _ride!.bookings.first.passengerName;
  }

  String? _passengerId() {
    if (_ride == null) return null;
    if (_ride!.bookings.isEmpty) return null;

    final accepted = _ride!.bookings.where((b) => b.status == BookingStatus.accepted).toList();
    if (accepted.isNotEmpty) {
      final pid = accepted.first.passengerId;
      return pid.isNotEmpty ? pid : null;
    }

    final firstPid = _ride!.bookings.first.passengerId;
    return (firstPid.isNotEmpty) ? firstPid : null;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // DRIVER MARKER (BLUE CAR)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: _carRotation,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: 'You (Driver)',
            snippet: _trackingStatus,
          ),
        ),
      );
    }
    
    // ✅ START MARKER (ORANGE FLAG)
    if (_ride != null && _ride!.startLat != null && _ride!.startLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(_ride!.startLat!, _ride!.startLng!),
          icon: _startIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: 'Start: ${_ride?.start ?? ''}',
            snippet: 'Pickup location',
          ),
        ),
      );
    }

    // DESTINATION MARKER (RED)
    if (_ride != null && _ride!.endLat != null && _ride!.endLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_ride!.endLat!, _ride!.endLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination: ${_ride?.end ?? ''}'),
        ),
      );
    }


    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    
    // 🛣️ 1. ROUTE POLYLINE UTAMA (Start ke Destination) - SOLID BLUE LINE
    if (_roadPolylinePoints.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _roadPolylinePoints,
          color: Colors.blue,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: false,
          jointType: JointType.round,
        ),
      );
    }
    
    // 🟢 2. LINE DARI DRIVER KE START LOCATION (GREEN DASHED - IKUT JALAN RAYA)
    if (_showDriverToStartRoute && _driverToStartRoute.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_to_start_road'),
          points: _driverToStartRoute,
          color: Colors.green,
          width: 3,
          geodesic: false, 
          patterns: [PatternItem.dash(10), PatternItem.gap(5)],
          jointType: JointType.round,
        ),
      );
    }
    
    // 🟩 3. DRIVER HISTORY POLYLINE
    if (_driverHistory.isNotEmpty && _currentPosition != null) {
      List<LatLng> fullPath = List.from(_driverHistory) 
        ..add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      
      polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_path'),
          points: fullPath,
          color: Colors.green.withOpacity(0.3),
          width: 2,
          geodesic: false,
        ),
      );
    }
    
    return polylines;
  }

  Future<void> _goToStartLocation() async {
    if (_ride != null && _ride!.startLat != null && _ride!.startLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_ride!.startLat!, _ride!.startLng!), 
            zoom: _mapZoom
          ),
        ),
      );
    }
  }

  Future<void> _zoomIn() async {
    try {
      _mapZoom = (_mapZoom + _zoomStep).clamp(2.0, 20.0);
      await _mapController?.animateCamera(CameraUpdate.zoomTo(_mapZoom));
    } catch (e) {
      debugPrint('zoomIn error: $e');
    }
  }

  Future<void> _zoomOut() async {
    try {
      _mapZoom = (_mapZoom - _zoomStep).clamp(2.0, 20.0);
      await _mapController?.animateCamera(CameraUpdate.zoomTo(_mapZoom));
    } catch (e) {
      debugPrint('zoomOut error: $e');
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentPosition == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        setState(() => _currentPosition = pos);
      } catch (e) {
        debugPrint('getCurrentLocation error: $e');
        return;
      }
    }

    if (_currentPosition != null) {
      final latLng = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: _mapZoom),
        ),
      );
    }
  }

  Future<void> _goToDestination() async {
    if (_ride != null && _ride!.endLat != null && _ride!.endLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_ride!.endLat!, _ride!.endLng!), 
            zoom: _mapZoom
          ),
        ),
      );
    }
  }

  Future<void> _refreshRoute() async {
    await _loadRideDetails();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _navigateToMessagePage() {
    final pid = _passengerId();
    final pname = _passengerName() ?? 'Passenger';
    final ride = _ride;
    
    if (pid == null || pid.isEmpty || ride == null) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('No passenger'),
          content: const Text(
            'There is no passenger to message at this time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PassengerMessagePage(
          rideId: widget.rideId,
          driverId: widget.driverId,
          passengerId: pid,
          passengerName: pname,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");

    final LatLng initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (_ride != null && _ride!.startLat != null && _ride!.startLng != null
            ? LatLng(_ride!.startLat!, _ride!.startLng!)
            : const LatLng(3.1390, 101.6869));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          widget.isResuming 
            ? "Driver: Resume Tracking" 
            : "Driver: Track Ride",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Google Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialCenter,
                zoom: _mapZoom,
              ),
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              polylines: _buildPolylines(),
              markers: _buildMarkers(),
            ),
          ),

          // Legend untuk markers dan garis
          Positioned(
            top: 100,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Markers
                  Row(
                    children: [
                      Icon(Icons.directions_car, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Text('You', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.flag, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text('Start', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('Destination', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Zoom & location controls
          Positioned(
            top: 100,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: _zoomIn,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 8),

                // Zoom Out
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: _zoomOut,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
                const SizedBox(height: 8),

                // Go to Start Location
                FloatingActionButton(
                  heroTag: 'to_start',
                  mini: true,
                  onPressed: _goToStartLocation,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.flag, color: Colors.orange),
                ),
                const SizedBox(height: 8),

                // Go to Current Location
                FloatingActionButton(
                  heroTag: 'loc',
                  mini: true,
                  onPressed: _goToCurrentLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.navigation, color: Colors.blue),
                ),
                const SizedBox(height: 8),

                // Go to Destination
                FloatingActionButton(
                  heroTag: 'dest',
                  mini: true,
                  onPressed: _goToDestination,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.place, color: Colors.red),
                ),
                const SizedBox(height: 8),
                
                // Refresh Main Route
                FloatingActionButton(
                  heroTag: 'refresh_route',
                  mini: true,
                  onPressed: _refreshRoute,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.refresh, color: Colors.black),
                ),
                const SizedBox(height: 8),
                
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grab handle
                      Center(
                        child: Container(
                          width: 70,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Title
                      Text(
                        widget.isResuming ? 'Resuming Ride Progress' : 'Ride Progress',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tracking Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isTrackingActive 
                            ? Colors.green.shade50 
                            : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isTrackingActive 
                              ? Colors.green.shade200 
                              : Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isTrackingActive ? Icons.play_arrow : Icons.pause,
                              size: 16,
                              color: _isTrackingActive ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isTrackingActive ? 'Tracking Active' : 'Tracking Paused',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isTrackingActive ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // From dengan icon flag
                      Row(
                        children: [
                          Icon(
                            Icons.flag,
                            size: 20,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'From: ${_ride?.start ?? '-'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // To dengan icon place
                      Row(
                        children: [
                          Icon(Icons.place, size: 20, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'To: ${_ride?.end ?? '-'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Passenger name
                      Row(
                        children: [
                          Icon(Icons.person, size: 20, color: Colors.grey[700]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Passenger: ${_passengerName() ?? 'Passenger'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Fare
                      Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 20,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Fare: RM ${_ride?.fare.toStringAsFixed(2) ?? '0.00'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Status tracking
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            size: 20,
                            color: _isTrackingActive ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _trackingStatus,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _isTrackingActive ? Colors.blue : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ETA and Distance Info
                      if (_etaMinutes != null && _remainingDistanceKm != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${_remainingDistanceKm!.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const Text(
                                    'Distance',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${_etaMinutes!.round()} min',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const Text(
                                    'Estimated ETA',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Buttons
                      Column(
                        children: [
                          // Message Passenger button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _navigateToMessagePage,
                              icon: const Icon(Icons.message),
                              label: const Text('Message Passenger'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _manualArrive,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Mark as Arrived'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _stopTracking,
                                  icon: Icon(
                                    _isTrackingActive 
                                      ? Icons.stop_circle_outlined 
                                      : Icons.play_arrow,
                                  ),
                                  label: Text(
                                    _isTrackingActive 
                                      ? 'Stop Tracking' 
                                      : 'Resume Tracking',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isTrackingActive 
                                      ? Colors.red 
                                      : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 1),
        Offset(startX + dashWidth, 1),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
