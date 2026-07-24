import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uthmshareride/modules/SearchRides/availableride.dart';
import 'package:uthmshareride/modules/ShareRide/locationpicker.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class SearchRidePage extends StatefulWidget {
  const SearchRidePage({super.key});

  @override
  State<SearchRidePage> createState() => _SearchRidePageState();
}

class _SearchRidePageState extends State<SearchRidePage> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  LatLng? _fromLatLng;
  LatLng? _toLatLng;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      _dateController.text =
          "${picked.day}/${picked.month}/${picked.year}";
      setState(() {});
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      _timeController.text = picked.format(context);
      setState(() {});
    }
  }

  Future<void> _openLocationPicker(
      bool isStart, TextEditingController controller) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(isStart: isStart),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        controller.text = result['address'];
        if (isStart) {
          _fromLatLng = result['latLng'];
        } else {
          _toLatLng = result['latLng'];
        }
      });
    }
  }

  void _searchRides() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableRidesPage(
          fromLocation:
              _fromController.text.isEmpty ? null : _fromController.text,
          toLocation:
              _toController.text.isEmpty ? null : _toController.text,
          selectedDate:
              _dateController.text.isEmpty ? null : _dateController.text,
          selectedTime:
              _timeController.text.isEmpty ? null : _timeController.text,
          fromLatLng: _fromLatLng,
          toLatLng: _toLatLng,
        ),
      ),
    );
  }

  Widget _inputTile({
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hint,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
void _viewAllAvailableRides() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const AvailableRidesPage(
        fromLocation: null,
        toLocation: null,
        selectedDate: null,
        selectedTime: null,
        fromLatLng: null,
        toLatLng: null,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text("Search Ride",style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),),
                ),
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Search a ride",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Choose route, date and time",
                        style:
                            TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                Expanded(
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputTile(
                          label: "Starting point",
                          hint: _fromController.text.isEmpty
                              ? "Select starting point"
                              : _fromController.text,
                          icon: Icons.radio_button_checked,
                          onTap: () =>
                              _openLocationPicker(true, _fromController),
                        ),
                        const SizedBox(height: 14),

                        _inputTile(
                          label: "Destination",
                          hint: _toController.text.isEmpty
                              ? "Select destination"
                              : _toController.text,
                          icon: Icons.location_on,
                          onTap: () =>
                              _openLocationPicker(false, _toController),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _inputTile(
                                label: "Date",
                                hint: _dateController.text.isEmpty
                                    ? "Select date"
                                    : _dateController.text,
                                icon: Icons.calendar_today,
                                onTap: _selectDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _inputTile(
                                label: "Time",
                                hint: _timeController.text.isEmpty
                                    ? "Select time"
                                    : _timeController.text,
                                icon: Icons.access_time,
                                onTap: _selectTime,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searchRides,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: bg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Search Ride",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 180),
            SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _viewAllAvailableRides,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: bg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              child: const Text(
                "View All Available Rides",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
