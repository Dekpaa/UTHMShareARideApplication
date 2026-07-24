import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;

class LocationPickerPage extends StatefulWidget {
  final bool isStart;
  const LocationPickerPage({super.key, required this.isStart});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  gmaps.GoogleMapController? _gmapController;
  gmaps.LatLng _selectedLocation = const gmaps.LatLng(1.4927, 103.7414); // Johor center
  String _selectedAddress = "Selecting location...";
  
  // Johor boundary coordinates (approximate)
  static var _johorBounds = gmaps.LatLngBounds(
    southwest: gmaps.LatLng(1.2085, 102.3699), // Southwest corner of Johor
    northeast: gmaps.LatLng(2.7993, 104.4355), // Northeast corner of Johor
  );

  final TextEditingController searchController = TextEditingController();
  bool _isSearching = false;
  bool _isGettingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Check if location is within Johor
  bool _isWithinJohor(gmaps.LatLng location) {
    return _johorBounds.contains(location);
  }

  // Validate and show error if outside Johor
  void _validateLocation(gmaps.LatLng location) async {
    if (!_isWithinJohor(location)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is outside Johor. Please select a location within Johor.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Move camera back to Johor center
      _gmapController?.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: const gmaps.LatLng(1.4927, 103.7414), // Johor center
            zoom: 15,
          ),
        ),
      );
      
      // Reset to last valid location or Johor center
      setState(() {
        _selectedLocation = const gmaps.LatLng(1.4927, 103.7414);
        _selectedAddress = "Location reset to Johor";
      });
      
      await _getAddressFromLatLng(_selectedLocation);
      return;
    }
    
    // Location is valid, get address
    await _getAddressFromLatLng(location);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingCurrentLocation = true);
    
    try {
      // Check permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final newLocation = gmaps.LatLng(position.latitude, position.longitude);
      
      // Check if current location is within Johor
      if (!_isWithinJohor(newLocation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are outside Johor. Please move to Johor area or search for Johor locations.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Default to Johor center
        setState(() {
          _selectedLocation = const gmaps.LatLng(1.4927, 103.7414);
        });
        
        _gmapController?.animateCamera(
          gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(
              target: const gmaps.LatLng(1.4927, 103.7414),
              zoom: 10,
            ),
          ),
        );
        
        await _getAddressFromLatLng(_selectedLocation);
        return;
      }
      
      setState(() => _selectedLocation = newLocation);
      
      // Update camera
      _gmapController?.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(target: newLocation, zoom: 15),
        ),
      );
      
      // Get address
      await _getAddressFromLatLng(newLocation);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGettingCurrentLocation = false);
    }
  }

  Future<void> _getAddressFromLatLng(gmaps.LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "";
        
        if (place.street != null && place.street!.isNotEmpty) {
          address += place.street!;
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          if (address.isNotEmpty) address += ", ";
          address += place.subLocality!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += ", ";
          address += place.locality!;
        }
        
        // Check if in Johor state
        bool isInJohor = place.administrativeArea?.toLowerCase().contains('johor') == true ||
                         place.subAdministrativeArea?.toLowerCase().contains('johor') == true ||
                         _isWithinJohor(latLng);
        
        if (!isInJohor) {
          address += " [Outside Johor]";
          setState(() {
            _selectedAddress = address;
          });
          return;
        }
        
        if (address.isEmpty && place.name != null) {
          address = place.name!;
        }
        
        setState(() {
          _selectedAddress = address.isNotEmpty ? address : "Johor, Malaysia";
        });
      } else {
        setState(() => _selectedAddress = "Johor, Malaysia");
      }
    } catch (e) {
      print("Failed to get address: $e");
      setState(() => _selectedAddress = _isWithinJohor(latLng) 
          ? "Johor, Malaysia" 
          : "Location outside Johor");
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      // Add Johor to search query to bias results toward Johor
      String searchQuery = query;
      if (!query.toLowerCase().contains('johor')) {
        searchQuery = "$query Johor, Malaysia";
      }

      final locations = await locationFromAddress(searchQuery);
      
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newPoint = gmaps.LatLng(loc.latitude, loc.longitude);
        
        // Check if search result is within Johor
        if (!_isWithinJohor(newPoint)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Search result is outside Johor. Please search for locations within Johor.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        setState(() => _selectedLocation = newPoint);

        _gmapController?.animateCamera(
          gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(target: newPoint, zoom: 14),
          ),
        );
        
        await _getAddressFromLatLng(newPoint);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location not found in Johor. Try a different search.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to search location: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _zoomIn() {
    _gmapController?.animateCamera(
      gmaps.CameraUpdate.zoomIn(),
    );
  }

  void _zoomOut() {
    _gmapController?.animateCamera(
      gmaps.CameraUpdate.zoomOut(),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    _gmapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF365770);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.isStart ? 'Choose Starting Point' : 'Choose Destination ',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: baseColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: baseColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Search box with Johor hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search location',
                  hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white24,
                  suffixIcon: IconButton(
                    icon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.search, color: Colors.white),
                    onPressed: _isSearching
                        ? null
                        : () => _searchPlace(searchController.text),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onSubmitted: (value) {
                  if (!_isSearching) _searchPlace(value);
                },
              ),
            ),

            const SizedBox(height: 12),

            // Selected Location Address
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedAddress.contains('[Outside Johor]') 
                          ? Icons.warning 
                          : Icons.location_on,
                      color: _selectedAddress.contains('[Outside Johor]') 
                          ? Colors.orange 
                          : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedAddress,
                        style: TextStyle(
                          color: _selectedAddress.contains('[Outside Johor]') 
                              ? Colors.orange 
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Google Map
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      gmaps.GoogleMap(
                        initialCameraPosition: gmaps.CameraPosition(
                          target: _selectedLocation,
                          zoom: 10,
                        ),
                        onMapCreated: (controller) {
                          _gmapController = controller;
                          // Restrict camera to Johor bounds
                          controller.moveCamera(
                            gmaps.CameraUpdate.newLatLngBounds(_johorBounds, 50),
                          );
                        },
                        onCameraMoveStarted: () {
                          // Can add loading indicator if needed
                        },
                        onCameraIdle: () async {
                          // When user stops moving map, get center location
                          if (_gmapController != null) {
                            final latLng = await _gmapController!.getLatLng(
                              const gmaps.ScreenCoordinate(x: 0, y: 0),
                            );
                            // This is approximate, better to use onTap for precise selection
                          }
                        },
                        onTap: (latLng) async {
                          // Check if tapped location is within Johor
                          if (!_isWithinJohor(latLng)) {
                            _validateLocation(latLng);
                            return;
                          }
                          
                          setState(() => _selectedLocation = latLng);
                          _gmapController?.animateCamera(
                            gmaps.CameraUpdate.newLatLng(latLng),
                          );
                          await _getAddressFromLatLng(latLng);
                        },
                        markers: {
                          gmaps.Marker(
                            markerId: const gmaps.MarkerId('selected'),
                            position: _selectedLocation,
                            icon: _isWithinJohor(_selectedLocation)
                                ? gmaps.BitmapDescriptor.defaultMarkerWithHue(
                                    gmaps.BitmapDescriptor.hueGreen,
                                  )
                                : gmaps.BitmapDescriptor.defaultMarkerWithHue(
                                    gmaps.BitmapDescriptor.hueRed,
                                  ),
                          ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        minMaxZoomPreference: const gmaps.MinMaxZoomPreference(8, 18),
                      ),
                      
                      // My Location Button (below zoom buttons)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Column(
                          children: [
                            // Zoom buttons
                            Column(
                              children: [
                                FloatingActionButton(
                                  heroTag: "zoomInPicker",
                                  mini: true,
                                  backgroundColor: Colors.white,
                                  onPressed: _zoomIn,
                                  child: const Icon(Icons.zoom_in, color: Colors.black),
                                ),
                                const SizedBox(height: 8),
                                FloatingActionButton(
                                  heroTag: "zoomOutPicker",
                                  mini: true,
                                  backgroundColor: Colors.white,
                                  onPressed: _zoomOut,
                                  child: const Icon(Icons.zoom_out, color: Colors.black),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // My Location Button
                            FloatingActionButton(
                              heroTag: "myLocationPicker",
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: _isGettingCurrentLocation ? null : _getCurrentLocation,
                              child: _isGettingCurrentLocation
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.my_location, color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            
            // Confirm Button (disabled if outside Johor)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _isWithinJohor(_selectedLocation) ? () {
                  final result = ll.LatLng(
                    _selectedLocation.latitude,
                    _selectedLocation.longitude,
                  );
                  Navigator.pop(context, {
                    'latLng': result,
                    'address': _selectedAddress.replaceAll(' [Outside Johor]', ''),
                  });
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isWithinJohor(_selectedLocation) ? Colors.white : Colors.grey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  _isWithinJohor(_selectedLocation) 
                      ? "Confirm location" 
                      : "Select location",
                  style: TextStyle(
                    color: _isWithinJohor(_selectedLocation) ? baseColor : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}