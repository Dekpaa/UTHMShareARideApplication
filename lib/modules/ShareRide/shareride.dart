import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uthmshareride/modules/Payment/driver_info_payment.dart';
import 'package:uthmshareride/modules/ShareRide/locationpicker.dart';
import 'package:uthmshareride/modules/ShareRide/myrides.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'package:uthmshareride/modules/Driver/car.dart';

class ShareRideFormPage extends StatefulWidget {
  const ShareRideFormPage({super.key});

  @override
  State<ShareRideFormPage> createState() => _ShareRideFormPageState();
}

class _ShareRideFormPageState extends State<ShareRideFormPage> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  final TextEditingController fareController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();

  LatLng? startLatLng;
  LatLng? endLatLng;

  String? _currentDriverId;
  final CarService _carService = CarService();
  List<CarDetails> _availableCars = [];
  CarDetails? _selectedCar;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentDriverId = FirebaseAuth.instance.currentUser?.uid;
    _loadAvailableCars();
  }

  void _loadAvailableCars() {
    _carService.getCarsStream().listen((cars) {
      if (!mounted) return;
      setState(() {
        _availableCars = cars;

        if (_availableCars.isNotEmpty) {
          _selectedCar = _availableCars.first;
        } else {
          _selectedCar = null;
        }
      });
    });
  }

  @override
  void dispose() {
    startController.dispose();
    endController.dispose();
    fareController.dispose();
    dateController.dispose();
    timeController.dispose();
    super.dispose();
  }

  void _updateFareIfPossible() {
    if (startLatLng != null && endLatLng != null) {
      const Distance distance = Distance();
      final km = distance.as(
        LengthUnit.Kilometer,
        startLatLng!,
        endLatLng!,
      );
      fareController.text = (km * 2.0).toStringAsFixed(2);
    }
  }

  Future<void> _getAddressFromLatLng(
    LatLng latLng,
    TextEditingController controller,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        controller.text =
            "${place.name}, ${place.locality}, ${place.country}";
      } else {
        controller.text = "Selected location";
      }
    } catch (e) {
      controller.text = "Location selected";
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        cursorColor: Colors.white,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: hexStringToColor("365770"),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        dateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: hexStringToColor("365770"),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (pickedTime != null) {
      setState(() {
        timeController.text = pickedTime.format(context);
      });
    }
  }

  Future<bool> _hasPaymentInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('driver_payment')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;
    final data = doc.data();
    if (data == null) return false;

    return (data['bankName'] ?? '').toString().isNotEmpty &&
        (data['accountName'] ?? '').toString().isNotEmpty &&
        (data['accountNumber'] ?? '').toString().isNotEmpty &&
        (data['qrUrl'] ?? '').toString().isNotEmpty;
  }

  Future<void> _submitRide() async {
    if (_currentDriverId == null || _currentDriverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver not logged in. Please log in again.'),
        ),
      );
      return;
    }

    if (_selectedCar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No car found. Please add your car first.'),
        ),
      );
      return;
    }

    final hasPayment = await _hasPaymentInfo();
    if (!hasPayment) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Payment Info Required'),
          content: const Text(
            'You must complete your bank & QR payment info before sharing a ride.\n\n'
            'Cash payment is NOT allowed. Please set up your QR / bank transfer details first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverInfoPayment(),
                  ),
                );
              },
              child: const Text('Go to Payment Info'),
            ),
          ],
        ),
      );
      return;
    }

    bool hasError = false;

    if (startController.text.isEmpty ||
        endController.text.isEmpty ||
        fareController.text.isEmpty ||
        dateController.text.isEmpty ||
        timeController.text.isEmpty ||
        startLatLng == null ||
        endLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all ride details and select locations.',
          ),
        ),
      );
      hasError = true;
    }

    if (hasError) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final fare = double.tryParse(fareController.text) ?? 0.0;

      final ride = Ride(
        id: '',
        driverId: _currentDriverId!,
        start: startController.text.trim(),
        end: endController.text.trim(),
        date: dateController.text.trim(),
        time: timeController.text.trim(),
        fare: fare,
        status: 'ongoing',
        hasArrived: false,
        isTracking: false,
        startLat: startLatLng!.latitude,
        startLng: startLatLng!.longitude,
        endLat: endLatLng!.latitude,
        endLng: endLatLng!.longitude,
        currentLat: null,
        currentLng: null,
        carDetails: _selectedCar!,
        bookings: [],
      );

      await RideStorage().createRide(ride);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride shared successfully!'),
        ),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyRidesPage(
            initialTabIndex: 0,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share ride. Please try again. ($e)'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openLocationPicker(bool isStart) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          isStart: isStart,
        ),
      ),
    );
    
    if (result != null && result is Map<String, dynamic>) {
      final latLng = result['latLng'] as LatLng;
      final address = result['address'] as String;
      
      if (isStart) {
        setState(() {
          startLatLng = latLng;
          startController.text = address;
        });
      } else {
        setState(() {
          endLatLng = latLng;
          endController.text = address;
        });
      }
      
      _updateFareIfPossible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseBg = hexStringToColor("365770");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: baseBg,
        title: const Text(
          "Share Ride",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [baseBg, baseBg.withOpacity(0.95)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Share your ride",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Set your route, time, and car details.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          "Starting point",
                          startController,
                          Icons.radio_button_checked,
                          readOnly: true,
                          onTap: () => _openLocationPicker(true),
                        ),
                        _buildTextField(
                          "Destination",
                          endController,
                          Icons.place,
                          readOnly: true,
                          onTap: () => _openLocationPicker(false),
                        ),
                        _buildTextField(
                          "Fare (RM)",
                          fareController,
                          Icons.price_change_outlined,
                          readOnly: true,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                "Date",
                                dateController,
                                Icons.calendar_today,
                                readOnly: true,
                                onTap: _selectDate,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextField(
                                "Time",
                                timeController,
                                Icons.access_time,
                                readOnly: true,
                                onTap: _selectTime,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Text(
          "Car",
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),

        if (_availableCars.isEmpty)
          const Text(
            "No cars found. Please add your car first.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

        if (_selectedCar != null) ...[
          const SizedBox(height: 8),
          const Text(
            "Car details",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Car details text di sebelah kiri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Model: ${_selectedCar!.model}",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      "Plate: ${_selectedCar!.plateNumber}",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      "Color: ${_selectedCar!.color}",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      "Seats: ${_selectedCar!.seatingDisplay}",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      "Year: ${_selectedCar!.year}",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    if (_selectedCar!.insuranceCompany != null &&
                        _selectedCar!.insuranceCompany!.isNotEmpty)
                      Text(
                        "Insurance: ${_selectedCar!.insuranceCompany}",
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
      
                    // Gambar kereta di sebelah kanan
                    if (_selectedCar!.imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _selectedCar!.imageUrl!,
                                height: 100,
                                width: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 100,
                                  width: 140,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.car_rental,
                                    color: Colors.white54,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                  ],
                ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: baseBg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 6,
                      ),
                      onPressed: _isSubmitting || _availableCars.isEmpty
                          ? null
                          : _submitRide,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : const Text(
                              "Share Ride",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                 ],
                ],
              ),
            ),
          ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}