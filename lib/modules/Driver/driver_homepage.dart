import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:uthmshareride/Component/Universal_nav_bar.dart';
import 'package:uthmshareride/modules/Driver/drawer.dart';
import 'package:uthmshareride/modules/Message/listchatdriver.dart';
import 'package:uthmshareride/modules/ShareRide/myrides.dart';
import 'package:uthmshareride/modules/ShareRide/shareride.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class DriverHomepage extends StatefulWidget {
  const DriverHomepage({super.key});

  @override
  State<DriverHomepage> createState() => _DriverHomepageState();
}

class _DriverHomepageState extends State<DriverHomepage> {
  int _selectedIndex = 0;
  gmaps.LatLng? currentLatLng;
  String? currentAddress;
  gmaps.GoogleMapController? _gmapController;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _getCurrentLocation);
  }

  @override
  void dispose() {
    _gmapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isGettingLocation = true;
      });

      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          currentAddress = "Location services disabled. Please enable them.";
          _isGettingLocation = false;
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            currentAddress = "Location permissions denied.";
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          currentAddress = "Location permissions permanently denied.";
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLatLng = gmaps.LatLng(position.latitude, position.longitude);
      });

      if (_gmapController != null && currentLatLng != null) {
        _gmapController!.animateCamera(
          gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(
              target: currentLatLng!,
              zoom: 18,
            ),
          ),
        );
      }

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            currentAddress =
                "${place.name}, ${place.locality}, ${place.country}";
          });
        } else {
          setState(() {
            currentAddress =
                "Location: (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})";
          });
        }
      } catch (e) {
        setState(() {
          currentAddress =
              "Location: (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})";
        });
      }
    } catch (e) {
      setState(() {
        currentAddress = "Failed to get location: $e";
      });
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    await _getCurrentLocation();
    if (currentLatLng != null && _gmapController != null) {
      _gmapController!.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: currentLatLng!,
            zoom: 18,
          ),
        ),
      );
    }
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const MyRidesPage();
      case 2:
        return const ListChatDriverPage();
      default:
        return _buildHomeContent();
    }
  }

  PreferredSizeWidget? _buildAppBar(int index) {
    if (index == 0) {
      return AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: hexStringToColor("365770"),
        title: const Text(
          "Driver",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(_selectedIndex),
      extendBody: true,
      drawer: const DriverAppDrawer(),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              hexStringToColor("365770"),
              hexStringToColor("365770")
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _getPage(_selectedIndex),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: Colors.white,
              foregroundColor: hexStringToColor("365770"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ShareRideFormPage(),
                  ),
                );
              },
              label: const Text("Share a Ride"),
              icon: const Icon(Icons.directions_car),
            )
          : null,
      bottomNavigationBar: UniversalBottomNavBar.driver(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
      ),
    );
  }

  Widget _buildHomeContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Welcome, Driver 👋",
            style: TextStyle(
              fontSize: 26,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "What would you like to do today?",
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Current Location",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _getCurrentLocation,
              ),
            ],
          ),
          Container(
            height: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildMapOrLoading(),
            ),
          ),
          const SizedBox(height: 10),
          if (currentAddress != null)
            Text(
              currentAddress!,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          const SizedBox(height: 10),
          const Text(
            "Make sure your location is accurate before sharing a ride.",
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMapOrLoading() {
    if (_isGettingLocation && currentLatLng == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (currentLatLng == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              "Unable to get location.\nTap refresh to try again.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        gmaps.GoogleMap(
          initialCameraPosition: gmaps.CameraPosition(
            target: currentLatLng!,
            zoom: 18,
          ),
          onMapCreated: (c) => _gmapController = c,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: {
            gmaps.Marker(
              markerId: const gmaps.MarkerId('me'),
              position: currentLatLng!,
              infoWindow: const gmaps.InfoWindow(title: 'My Location'),
            ),
          },
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: "zoomIn",
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  _gmapController?.animateCamera(
                    gmaps.CameraUpdate.zoomIn(),
                  );
                },
                child: const Icon(Icons.zoom_in, color: Colors.black),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: "zoomOut",
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  _gmapController?.animateCamera(
                    gmaps.CameraUpdate.zoomOut(),
                  );
                },
                child: const Icon(Icons.zoom_out, color: Colors.black),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          right: 10,
          child: FloatingActionButton(
            heroTag: "myLocation",
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _goToMyLocation,
            child: const Icon(Icons.my_location, color: Colors.black),
          ),
        ),
      ],
    );
  }
}