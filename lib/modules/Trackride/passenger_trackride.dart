import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uthmshareride/modules/Message/drivertopassmessage.dart';
import 'package:uthmshareride/modules/Message/passtodrivermessage.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class PassengerTrackRidePage extends StatefulWidget {
  final String rideId;
  final String bookingId;
  final String driverName;
  final LatLng? initialLocation;

  const PassengerTrackRidePage({
    super.key,
    required this.rideId,
    required this.bookingId,
    required this.driverName,
    this.initialLocation,
  });

  @override
  State<PassengerTrackRidePage> createState() => _PassengerTrackRidePageState();
}

class _PassengerTrackRidePageState extends State<PassengerTrackRidePage> {
  late GoogleMapController _mapController;
  double _mapZoom = 16.0;
  final double _zoomStep = 1.0;
  final String googleApiKey = "AIzaSyA8XyUAaBTUaIFZnyJFenC41_paHZelsXk";

  Ride? _ride;
  LatLng? _driverLocation;
  LatLng? _startLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePolyline = [];
  List<LatLng> _driverHistory = [];
  List<LatLng> _driverToStartRoute = [];
  
  StreamSubscription<DocumentSnapshot>? _rideStreamSub;
  StreamSubscription<DocumentSnapshot>? _routeStreamSub;
  Timer? _refreshTimer;

  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _startIcon; 
  BitmapDescriptor? _passengerIcon;
  double _carRotation = 0.0;
  
  double? _etaMinutes;
  double? _remainingDistanceKm;

  String _trackingStatus = "Loading ride details...";
  bool _isTrackingActive = false;
  bool _showDriverToStartRoute = false;

  // Current passenger location
  LatLng? _passengerLocation;

  @override
  void initState() {
    super.initState();
    _createCarIcon();
    _createStartIcon();
    _createPassengerIcon();
    _loadRideDetails();
    _loadRouteFromFirestore();
    _listenToRideUpdates();
    _listenToRouteUpdates();
    _startAutoRefresh();
    _testFirestoreConnection();
  }

  Future<void> _testFirestoreConnection() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();
      
      debugPrint('🔍 PASSENGER: TEST FIRESTORE CONNECTION');
      debugPrint('🔍 Ride ID: ${widget.rideId}');
      debugPrint('🔍 Document exists: ${doc.exists}');
      
      if (doc.exists) {
        final data = doc.data()!;
        debugPrint('🔍 Document data keys: ${data.keys.toList()}');
        
        // Check for route data
        if (data.containsKey('routePolyline')) {
          final polylineData = data['routePolyline'];
          if (polylineData is List) {
            debugPrint('✅ routePolyline exists with ${polylineData.length} points');
          }
        }
        
        // Check for driver location
        if (data.containsKey('driverLocation')) {
          debugPrint('✅ driverLocation exists: ${data['driverLocation']}');
        }
        
        // Check for driver-to-start route
        if (data.containsKey('driverToStartRoute')) {
          debugPrint('✅ driverToStartRoute exists');
        }
      }
    } catch (e) {
      debugPrint('❌ Passenger Firestore test error: $e');
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

  Future<void> _createPassengerIcon() async {
    try {
      final BitmapDescriptor bmp = await _bitmapDescriptorFromIcon(
        Icons.person_pin_circle,
        iconColor: Colors.purple,
        size: 72,
      );
      setState(() => _passengerIcon = bmp);
    } catch (e) {
      debugPrint('createPassengerIcon error: $e');
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

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _isTrackingActive) {
        _loadRideDetails();
        _logTrackingInfo();
      }
    });
  }

  @override
  void dispose() {
    _rideStreamSub?.cancel();
    _routeStreamSub?.cancel();
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ✅ TAMBAH: Fungsi untuk decode polyline dari Google Directions API
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

  // ✅ TAMBAH: Fungsi untuk fetch driver-to-start route dari Google Directions API
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
      debugPrint('❌ Passenger: Driver-to-start directions error: $e');
      return [driverPos, startPos];
    }
  }

  // ✅ TAMBAH: Fungsi untuk update driver-to-start route secara dinamis
  Future<void> _updateDriverToStartRoute() async {
    if (_driverLocation == null || _startLocation == null) {
      return;
    }
    
    final driverPos = _driverLocation!;
    final startPos = _startLocation!;
    
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
        debugPrint('✅ Passenger: Driver-to-start road route loaded (${routePoints.length} points)');
      }
    } catch (e) {
      debugPrint('❌ Passenger: Driver-to-start road route error: $e');
      // Fallback ke garis lurus
      setState(() {
        _driverToStartRoute = [driverPos, startPos];
        _showDriverToStartRoute = true;
      });
    }
  }

  Future<void> _loadRouteFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        
        // 1. Load main route polyline
        if (data.containsKey('routePolyline')) {
          final routeData = data['routePolyline'];
          _updateRoutePolyline(routeData);
        }
        
        // 2. Load driver-to-start route (jika ada dari driver)
        if (data.containsKey('driverToStartRoute')) {
          final driverToStartData = data['driverToStartRoute'];
          _updateDriverToStartRouteFromFirestore(driverToStartData);
        }
        
        // 3. Load showDriverToStart flag
        if (data.containsKey('showDriverToStart')) {
          setState(() {
            _showDriverToStartRoute = data['showDriverToStart'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading route from Firestore: $e');
    }
  }

  void _updateRoutePolyline(dynamic routeData) {
    if (routeData != null && routeData is List) {
      final List<LatLng> polyline = [];
      
      for (var point in routeData) {
        if (point is Map<String, dynamic>) {
          final lat = point['lat']?.toDouble();
          final lng = point['lng']?.toDouble();
          
          if (lat != null && lng != null) {
            polyline.add(LatLng(lat, lng));
          }
        } else if (point is Map) {
          final lat = point['lat'];
          final lng = point['lng'];
          
          if (lat != null && lng != null) {
            polyline.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      
      if (polyline.length > 1) {
        setState(() {
          _routePolyline = polyline;
        });
        _calculateDistanceAndETA();
        debugPrint('✅ Passenger: Loaded ${polyline.length} main route points');
      }
    }
  }

  void _updateDriverToStartRouteFromFirestore(dynamic routeData) {
    if (routeData != null && routeData is List) {
      final List<LatLng> polyline = [];
      
      for (var point in routeData) {
        if (point is Map<String, dynamic>) {
          final lat = point['lat']?.toDouble();
          final lng = point['lng']?.toDouble();
          
          if (lat != null && lng != null) {
            polyline.add(LatLng(lat, lng));
          }
        } else if (point is Map) {
          final lat = point['lat'];
          final lng = point['lng'];
          
          if (lat != null && lng != null) {
            polyline.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      
      if (polyline.length > 1) {
        setState(() {
          _driverToStartRoute = polyline;
          _showDriverToStartRoute = true;
        });
        debugPrint('✅ Passenger: Loaded ${polyline.length} driver-to-start route points from Firestore');
      }
    }
  }

  Future<void> _loadRideDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();

      if (doc.exists) {
        final ride = Ride.fromFirestore(doc.data()!, doc.id);
        setState(() {
          _ride = ride;
          _isTrackingActive = ride.isTracking;
          
          // Update start location
          if (ride.startLat != null && ride.startLng != null) {
            _startLocation = LatLng(ride.startLat!, ride.startLng!);
          }

          // Update destination
          if (ride.endLat != null && ride.endLng != null) {
            _destinationLocation = LatLng(ride.endLat!, ride.endLng!);
          }
          
          // Update driver location
          if (ride.currentLat != null && ride.currentLng != null) {
            final newLocation = LatLng(ride.currentLat!, ride.currentLng!);
            _updateDriverLocation(newLocation);
          }
          
          // Update passenger location (for demo, use start location)
          if (_passengerLocation == null && _startLocation != null) {
            _passengerLocation = _startLocation;
          }
          
          // Update tracking status
          if (ride.hasArrived) {
            _trackingStatus = "Driver has arrived at destination";
          } else if (_isTrackingActive) {
            _trackingStatus = "Driver is on the way";
          } else {
            _trackingStatus = "Waiting for driver to start tracking";
          }
        });

        // ✅ TAMBAH: Update driver-to-start route setiap kali driver location berubah
        if (_driverLocation != null && _startLocation != null) {
          _updateDriverToStartRoute();
        }

        // Auto-center map
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_driverLocation != null) {
            _centerMapOnDriver();
          } else if (_startLocation != null) {
            _mapController.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _startLocation!, zoom: _mapZoom),
              ),
            );
          }
        });
      } else {
        debugPrint('❌ Ride document not found: ${widget.rideId}');
        setState(() => _trackingStatus = "Ride not found");
      }
    } catch (e) {
      debugPrint('❌ Error loading ride details: $e');
      setState(() => _trackingStatus = "Error loading ride details");
    }
  }

  void _updateDriverLocation(LatLng newLocation) {
    if (_driverLocation != null && 
        _distanceMeters(_driverLocation!, newLocation) > 5) {
      // Add to history
      _driverHistory.add(_driverLocation!);
      
      // Calculate rotation
      _carRotation = _calculateBearing(_driverLocation!, newLocation);
    }
    
    setState(() {
      _driverLocation = newLocation;
    });
    
    // ✅ TAMBAH: Update driver-to-start route setiap kali driver bergerak
    if (_startLocation != null) {
      _updateDriverToStartRoute();
    }
    
    _calculateDistanceAndETA();
  }

  void _centerMapOnDriver() {
    if (_driverLocation != null && mounted) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _driverLocation!, zoom: _mapZoom),
        ),
      );
    }
  }

  void _listenToRideUpdates() {
    _rideStreamSub = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((docSnapshot) {
      if (docSnapshot.exists) {
        final ride = Ride.fromFirestore(docSnapshot.data()!, docSnapshot.id);
        
        setState(() {
          _ride = ride;
          _isTrackingActive = ride.isTracking;
          
          // Update locations
          if (ride.startLat != null && ride.startLng != null) {
            _startLocation = LatLng(ride.startLat!, ride.startLng!);
          }
          
          if (ride.endLat != null && ride.endLng != null) {
            _destinationLocation = LatLng(ride.endLat!, ride.endLng!);
          }
          
          // Update driver location
          if (ride.currentLat != null && ride.currentLng != null) {
            final newLocation = LatLng(ride.currentLat!, ride.currentLng!);
            _updateDriverLocation(newLocation);
          }
          
          // Update status
          if (ride.hasArrived) {
            _trackingStatus = "Driver has arrived";
          } else if (_isTrackingActive) {
            _trackingStatus = "Driver is on the way";
          } else {
            _trackingStatus = "Waiting for driver";
          }
        });
      }
    }, onError: (error) {
      debugPrint('❌ Passenger ride stream error: $error');
      setState(() => _trackingStatus = "Connection error");
    });
  }

  void _listenToRouteUpdates() {
    _routeStreamSub = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((docSnapshot) {
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        
        // Update main route
        if (data.containsKey('routePolyline')) {
          final routeData = data['routePolyline'];
          _updateRoutePolyline(routeData);
        }
        
        // Update driver-to-start route dari Firestore
        if (data.containsKey('driverToStartRoute')) {
          final driverToStartData = data['driverToStartRoute'];
          _updateDriverToStartRouteFromFirestore(driverToStartData);
        }
        
        // Update flag
        if (data.containsKey('showDriverToStart')) {
          setState(() {
            _showDriverToStartRoute = data['showDriverToStart'] ?? false;
          });
        }
        
        // Update driver location directly
        if (data.containsKey('driverLocation')) {
          final driverLoc = data['driverLocation'];
          if (driverLoc != null && driverLoc is Map) {
            final lat = driverLoc['latitude']?.toDouble();
            final lng = driverLoc['longitude']?.toDouble();
            
            if (lat != null && lng != null) {
              final newDriverLoc = LatLng(lat, lng);
              _updateDriverLocation(newDriverLoc);
            }
          }
        }
      }
    }, onError: (error) {
      debugPrint('❌ Passenger route stream error: $error');
    });
  }

  void _calculateDistanceAndETA() {
    if (_driverLocation == null || _destinationLocation == null) return;
    
    if (_routePolyline.isNotEmpty) {
      _calculateRouteBasedDistance();
    } else {
      _calculateDirectDistance();
    }
  }

  void _calculateRouteBasedDistance() {
    try {
      double totalDistance = 0.0;
      
      // Find the closest point on route to driver
      int closestIndex = 0;
      double minDistance = double.infinity;
      
      for (int i = 0; i < _routePolyline.length; i++) {
        final dist = _distanceMeters(_driverLocation!, _routePolyline[i]);
        if (dist < minDistance) {
          minDistance = dist;
          closestIndex = i;
        }
      }
      
      // Calculate remaining distance from closest point to end
      for (int i = closestIndex; i < _routePolyline.length - 1; i++) {
        totalDistance += _distanceMeters(_routePolyline[i], _routePolyline[i + 1]);
      }
      
      _remainingDistanceKm = totalDistance / 1000;
      
      const double averageSpeedKmh = 40.0;
      if (_remainingDistanceKm! > 0) {
        _etaMinutes = (_remainingDistanceKm! / averageSpeedKmh) * 60;
        _etaMinutes = _etaMinutes! * 1.3; // Add buffer
      }
      
      setState(() {});
      
      debugPrint('📏 Passenger: Route distance: ${_remainingDistanceKm!.toStringAsFixed(2)} km, ETA: ${_etaMinutes!.round()} min');
    } catch (e) {
      debugPrint('❌ Error calculating route distance: $e');
      _calculateDirectDistance();
    }
  }

  void _calculateDirectDistance() {
    if (_driverLocation == null || _destinationLocation == null) return;
    
    _remainingDistanceKm = _distanceMeters(_driverLocation!, _destinationLocation!) / 1000;

    const double averageSpeedKmh = 40.0;
    if (_remainingDistanceKm! > 0) {
      _etaMinutes = (_remainingDistanceKm! / averageSpeedKmh) * 60;
      _etaMinutes = _etaMinutes! * 1.3;
    }
    
    setState(() {});
    
    debugPrint('📏 Passenger: Direct distance: ${_remainingDistanceKm!.toStringAsFixed(2)} km, ETA: ${_etaMinutes!.round()} min');
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const double R = 6371000;
    double dLat = _toRadians(b.latitude - a.latitude);
    double dLon = _toRadians(b.longitude - a.longitude);
    double lat1 = _toRadians(a.latitude);
    double lat2 = _toRadians(b.latitude);

    double aCalc = sin(dLat/2) * sin(dLat/2) +
        sin(dLon/2) * sin(dLon/2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(aCalc), sqrt(1-aCalc));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * (pi / 180);

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x);
    
    return (bearing * 180 / pi + 360) % 360;
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};
    
    // 🟠 START MARKER (ORANGE FLAG)
    if (_startLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: _startLocation!,
          icon: _startIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: 'Start: ${_ride?.start ?? ''}',
            snippet: 'Pickup location',
          ),
        ),
      );
    }
    
    // 🟣 PASSENGER MARKER (PURPLE - current location)
    if (_passengerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('passenger'),
          position: _passengerLocation!,
          icon: _passengerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: const InfoWindow(
            title: 'You (Passenger)',
            snippet: 'Your current location',
          ),
        ),
      );
    }
    
    // 🔵 DRIVER MARKER (BLUE CAR)
    if (_driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: _carRotation,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: 'Driver: ${widget.driverName}',
            snippet: _trackingStatus,
          ),
        ),
      );
    }
    
    // 🔴 DESTINATION MARKER (RED)
    if (_destinationLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination: ${_ride?.end ?? ''}',
            snippet: 'Drop-off location',
          ),
        ),
      );
    }
    
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final Set<Polyline> polylines = {};
    
    // 🟦 1. MAIN ROUTE (START to END) - Blue Solid Line (ikut jalan raya)
    if (_routePolyline.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('main_road_route'),
          points: _routePolyline,
          color: Colors.blue,
          width: 5,
          geodesic: false,  // ✅ FALSE = ikut jalan raya
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }
    
    // 🟩 2. DRIVER-TO-START ROUTE (GREEN DASHED LINE - ikut jalan raya)
    if (_showDriverToStartRoute && _driverToStartRoute.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_to_start_road'),
          points: _driverToStartRoute,
          color: Colors.green,
          width: 3,
          geodesic: false,  // ✅ FALSE = ikut jalan raya
          patterns: [PatternItem.dash(10), PatternItem.gap(5)],
          jointType: JointType.round,
        ),
      );
    }
    
    // 📍 3. DRIVER HISTORY (Light Green)
    if (_driverHistory.isNotEmpty && _driverLocation != null) {
      List<LatLng> fullPath = List.from(_driverHistory)..add(_driverLocation!);
      
      polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_path_history'),
          points: fullPath,
          color: Colors.green.withOpacity(0.3),
          width: 2,
          geodesic: false,
        ),
      );
    }
    
    // 🔴 4. FALLBACK: Garis lurus dari driver ke destination (hanya jika tidak ada rute)
    if (_driverLocation != null && 
        _destinationLocation != null && 
        _routePolyline.length <= 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('fallback_direct_line'),
          points: [_driverLocation!, _destinationLocation!],
          color: Colors.red.withOpacity(0.5),
          width: 2,
          geodesic: false,
          patterns: [PatternItem.dash(5), PatternItem.gap(5)],
        ),
      );
    }
    
    return polylines;
  }

  Future<void> _zoomIn() async {
    try {
      _mapZoom = (_mapZoom + _zoomStep).clamp(2.0, 20.0);
      await _mapController.animateCamera(CameraUpdate.zoomTo(_mapZoom));
    } catch (e) {
      debugPrint('zoomIn error: $e');
    }
  }

  Future<void> _zoomOut() async {
    try {
      _mapZoom = (_mapZoom - _zoomStep).clamp(2.0, 20.0);
      await _mapController.animateCamera(CameraUpdate.zoomTo(_mapZoom));
    } catch (e) {
      debugPrint('zoomOut error: $e');
    }
  }

  Future<void> _goToDriverLocation() async {
    if (_driverLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _driverLocation!, zoom: _mapZoom),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver location not available'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _goToStartLocation() async {
    if (_startLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _startLocation!, zoom: _mapZoom),
        ),
      );
    }
  }

  Future<void> _goToDestination() async {
    if (_destinationLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _destinationLocation!, zoom: _mapZoom),
        ),
      );
    }
  }

  Future<void> _goToPassengerLocation() async {
    if (_passengerLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _passengerLocation!, zoom: _mapZoom),
        ),
      );
    }
  }

  Future<void> _refreshRoute() async {
    await _loadRideDetails();
    await _loadRouteFromFirestore();
    
    // ✅ TAMBAH: Refresh driver-to-start route juga
    if (_driverLocation != null && _startLocation != null) {
      _updateDriverToStartRoute();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _logTrackingInfo() {
    debugPrint('=== PASSENGER TRACKING INFO ===');
    debugPrint('Driver Location: $_driverLocation');
    debugPrint('Start Location: $_startLocation');
    debugPrint('Destination Location: $_destinationLocation');
    debugPrint('Main Route Points: ${_routePolyline.length}');
    debugPrint('Driver-to-Start Road Route: ${_driverToStartRoute.length}');
    debugPrint('Show Driver-to-Start: $_showDriverToStartRoute');
    debugPrint('Tracking Active: $_isTrackingActive');
    debugPrint('ETA: ${_etaMinutes?.round()} min');
    debugPrint('Distance: ${_remainingDistanceKm?.toStringAsFixed(2)} km');
    
    // Log route details
    if (_driverToStartRoute.isNotEmpty) {
      debugPrint('Driver-to-Start Route First Point: ${_driverToStartRoute.first}');
      debugPrint('Driver-to-Start Route Last Point: ${_driverToStartRoute.last}');
    }
    
    debugPrint('================================');
  }

  Future<void> _showMessageDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    Ride? ride = _ride;
    if (ride == null) {
      ride = await _getRideFromFirestore();
      if (ride == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride not found')),
        );
        return;
      }
      setState(() => _ride = ride);
    }

    String bookingId = widget.bookingId;
    String passengerName = await _getPassengerName(currentUser.uid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverMessagePage(
          ride: ride!,
          bookingId: bookingId,
          driverName: widget.driverName,
          currentUserId: currentUser.uid,
          passengerId: currentUser.uid,
        ),
      ),
    );
  }

  Future<String> _getPassengerName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('passengers')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data()?['fullName'] ?? 
               doc.data()?['name'] ?? 
               'Passenger';
      }
    } catch (e) {
      debugPrint('Error getting passenger name: $e');
    }
    return 'Passenger';
  }

  Future<Ride?> _getRideFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();
      
      if (doc.exists) {
        return Ride.fromFirestore(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('Error getting ride: $e');
    }
    return null;
  }

  Widget _buildLegend() {
    return Positioned(
      top: 100,
      left: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Markers Section
            const Text(
              'Markers:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _legendItem(Icons.flag, Colors.orange, 'Start'),
            _legendItem(Icons.person_pin_circle, Colors.purple, 'You'),
            _legendItem(Icons.directions_car, Colors.blue, 'Driver'),
            _legendItem(Icons.place, Colors.red, 'Destination'),
            
          ],
        ),
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _routeLegendItem(Color color, double width, bool dashed, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20,
            height: width.toDouble(),
            decoration: BoxDecoration(
              color: dashed ? Colors.transparent : color,
              borderRadius: BorderRadius.circular(2),
              border: dashed
                  ? Border.all(color: color, width: 1)
                  : null,
            ),
            child: dashed
                ? CustomPaint(
                    painter: DashedLinePainter(color: color),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");
    
    // Determine initial camera position
    LatLng initialCameraPosition;
    if (widget.initialLocation != null) {
      initialCameraPosition = widget.initialLocation!;
    } else if (_driverLocation != null) {
      initialCameraPosition = _driverLocation!;
    } else if (_startLocation != null) {
      initialCameraPosition = _startLocation!;
    } else if (_destinationLocation != null) {
      initialCameraPosition = _destinationLocation!;
    } else {
      initialCameraPosition = const LatLng(1.4927, 103.7414);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text(
          "Passenger: Track Ride",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                target: initialCameraPosition,
                zoom: _mapZoom,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Center on driver after map is created
                if (_driverLocation != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _centerMapOnDriver();
                  });
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
            ),
          ),

          // Legend
          _buildLegend(),

          // Map Controls
          Positioned(
            top: 100,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In
                _mapControlButton(
                  icon: Icons.add,
                  onPressed: _zoomIn,
                  heroTag: 'zoom_in',
                ),
                const SizedBox(height: 8),
                
                // Zoom Out
                _mapControlButton(
                  icon: Icons.remove,
                  onPressed: _zoomOut,
                  heroTag: 'zoom_out',
                ),
                const SizedBox(height: 8),
                
                // Go to Start
                _mapControlButton(
                  icon: Icons.flag,
                  onPressed: _goToStartLocation,
                  heroTag: 'to_start',
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                
                // Go to Passenger
                _mapControlButton(
                  icon: Icons.person_pin_circle,
                  onPressed: _goToPassengerLocation,
                  heroTag: 'to_passenger',
                  color: Colors.purple,
                ),
                const SizedBox(height: 8),
                
                // Go to Driver
                _mapControlButton(
                  icon: Icons.navigation,
                  onPressed: _goToDriverLocation,
                  heroTag: 'to_driver',
                  color: Colors.blue,
                ),
                const SizedBox(height: 8),
                
                // Go to Destination
                _mapControlButton(
                  icon: Icons.place,
                  onPressed: _goToDestination,
                  heroTag: 'to_destination',
                  color: Colors.red,
                ),
                const SizedBox(height: 8),
                
                // Refresh Route
                _mapControlButton(
                  icon: Icons.refresh,
                  onPressed: _refreshRoute,
                  heroTag: 'refresh_route',
                  color: Colors.black,
                ),
              ],
            ),
          ),

          // Bottom info sheet
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(blurRadius: 10, color: Colors.black26)
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 60,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Title
                        const Text(
                          'Ride Progress',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(top: 8),
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
                                _isTrackingActive ? 'Driver Tracking Active' : 'Driver Not Tracking',
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
                        
                        // Ride Details
                        _detailRow(
                          icon: Icons.flag,
                          iconColor: Colors.orange,
                          text: 'From: ${_ride?.start ?? '-'}',
                        ),
                        const SizedBox(height: 8),
                        
                        _detailRow(
                          icon: Icons.place,
                          iconColor: Colors.red,
                          text: 'To: ${_ride?.end ?? '-'}',
                        ),
                        const SizedBox(height: 8),
                        
                        _detailRow(
                          icon: Icons.directions_car,
                          iconColor: Colors.blue,
                          text: 'Driver: ${widget.driverName}',
                        ),
                        const SizedBox(height: 8),
                        
                        _detailRow(
                          icon: Icons.attach_money,
                          iconColor: Colors.green,
                          text: 'Fare: RM ${_ride?.fare.toStringAsFixed(2) ?? '0.00'}',
                        ),
                        const SizedBox(height: 8),
                        
                        _detailRow(
                          icon: _isTrackingActive ? Icons.directions_car : Icons.access_time,
                          iconColor: _isTrackingActive ? Colors.blue : Colors.orange,
                          text: _trackingStatus,
                        ),
                        
                        // Route Status
                        if (_showDriverToStartRoute && _driverToStartRoute.isNotEmpty)
                          _detailRow(
                            icon: Icons.directions,
                            iconColor: Colors.green,
                            text: 'Driver on the way to pickup (${_driverToStartRoute.length} road points)',
                          ),
                        
                        // ETA and Distance
                        if (_etaMinutes != null && _remainingDistanceKm != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(top: 12),
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

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showMessageDialog,
                            icon: const Icon(Icons.message),
                            label: const Text('Message Driver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String heroTag,
    Color? color,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      onPressed: onPressed,
      backgroundColor: Colors.white,
      child: Icon(icon, color: color ?? Colors.black),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter untuk dashed line di legend
class DashedLinePainter extends CustomPainter {
  final Color color;
  
  DashedLinePainter({this.color = Colors.green});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}