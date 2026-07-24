import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class CarDetails {
  String id;
  String model;
  String plateNumber;
  String color;
  String seatingRange;
  int year;
  String transmission;
  String fuelType;
  String? insuranceCompany;
  String? imageUrl;
  File? carImage;

  CarDetails({
    required this.id,
    required this.model,
    required this.plateNumber,
    required this.color,
    required this.seatingRange,
    required this.year,
    required this.transmission,
    required this.fuelType,
    this.insuranceCompany,
    this.imageUrl,
    this.carImage,
  });

  static int parseYear(dynamic raw) {
    final currentYear = DateTime.now().year;
    if (raw == null) return currentYear;
    if (raw is int) return raw;
    return int.tryParse(raw.toString()) ?? currentYear;
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'plateNumber': plateNumber,
      'color': color,
      'seatingRange': seatingRange,
      'year': year,
      'transmission': transmission,
      'fuelType': fuelType,
      'insuranceCompany': insuranceCompany,
      'imageUrl': imageUrl,
    };
  }

  factory CarDetails.fromFirestore(Map<String, dynamic> data, String docId) {
    return CarDetails(
      id: docId,
      model: data['model'] ?? '',
      plateNumber: data['plateNumber'] ?? '',
      color: data['color'] ?? '',
      seatingRange: data['seatingRange'] ?? 'Select',
      year: CarDetails.parseYear(data['year']),
      transmission: data['transmission'] ?? 'Select',
      fuelType: data['fuelType'] ?? 'Select',
      insuranceCompany: data['insuranceCompany'],
      imageUrl: data['imageUrl'],
    );
  }

  factory CarDetails.fromMap(Map<String, dynamic> data) {
    return CarDetails(
      id: data['id'] ?? '',
      model: data['model'] ?? '',
      plateNumber: data['plateNumber'] ?? '',
      color: data['color'] ?? '',
      seatingRange: data['seatingRange'] ?? 'Select',
      year: CarDetails.parseYear(data['year']),
      transmission: data['transmission'] ?? 'Select',
      fuelType: data['fuelType'] ?? 'Select',
      insuranceCompany: data['insuranceCompany'],
      imageUrl: data['imageUrl'],
    );
  }

  int get carAge {
    final currentYear = DateTime.now().year;
    return currentYear - year;
  }

  String get seatingDisplay {
    switch (seatingRange) {
      case '1 Seat':
        return '1 Seat (Sports)';
      case '2 Seats':
        return '2 Seats (Coupe)';
      case '4-5 Seats':
        return '4-5 Seats (Sedan)';
      case '6-7 Seats':
        return '6-7 Seats (MPV/SUV)';
      case '8-9 Seats':
        return '8-9 Seats (Large MPV)';
      case '10+ Seats':
        return '10+ Seats (Van)';
      default:
        return seatingRange;
    }
  }
}


class CarService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _carsRef {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Not logged in');

    return _firestore.collection('drivers').doc(userId).collection('cars');
  }

  Stream<List<CarDetails>> getCarsStream() {
    return _carsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CarDetails.fromFirestore(data, doc.id);
      }).toList();
    });
  }

  Future<void> addCar(CarDetails car, {File? imageFile}) async {
    String? uploadedImageUrl;

    if (imageFile != null) {
      uploadedImageUrl = await _uploadImage(imageFile);
    }

    final carData = car.toMap();
    if (uploadedImageUrl != null) {
      carData['imageUrl'] = uploadedImageUrl;
    }

    await _carsRef.add(carData);
  }

  Future<void> updateCar(CarDetails car, {File? newImageFile}) async {
    String? imageUrl = car.imageUrl;

    if (newImageFile != null) {
      if (car.imageUrl != null && car.imageUrl!.isNotEmpty) {
        await _deleteImage(car.imageUrl!);
      }
      imageUrl = await _uploadImage(newImageFile);
    }

    final carData = car.toMap();
    if (imageUrl != null) {
      carData['imageUrl'] = imageUrl;
    }

    await _carsRef.doc(car.id).update(carData);
  }

  Future<void> deleteCar(String carId, {String? imageUrl}) async {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      await _deleteImage(imageUrl);
    }

    await _carsRef.doc(carId).delete();
  }

  Future<String> _uploadImage(File imageFile) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'unknown';
      final fileName = 'car_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('cars/$userId/$fileName');

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }
}

// ==================== MY CARS PAGE ====================
class MyCarsPage extends StatefulWidget {
  const MyCarsPage({super.key});

  @override
  State<MyCarsPage> createState() => _MyCarsPageState();
}

class _MyCarsPageState extends State<MyCarsPage> {
  final CarService _carService = CarService();
  List<CarDetails> _cars = [];

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  void _loadCars() {
    _carService.getCarsStream().listen((cars) {
      if (mounted) {
        setState(() {
          _cars = cars;
        });
      }
    });
  }

  void _addNewCar() async {
    // >>> Hadkan 1 kereta sahaja per driver
    if (_cars.length >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can only register one car. Please edit the existing car to change details.',
          ),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CarDetailsFormPage()),
    );

    if (result == true) {
      _loadCars();
    }
  }

  void _editCar(CarDetails car) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CarDetailsFormPage(carToEdit: car)),
    );

    if (result == true) {
      _loadCars();
    }
  }

  void _deleteCar(String carId, String? imageUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Car'),
        content: const Text('Are you sure you want to delete this car?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: hexStringToColor("365770"))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _carService.deleteCar(carId, imageUrl: imageUrl);
        _loadCars();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting car: $e')),
        );
      }
    }
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'My Cars',
          style: TextStyle(color: Colors.white, fontSize: 24 ,fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bg, bg, bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _cars.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 80, color: Colors.white70),
                    const SizedBox(height: 20),
                    const Text(
                      'No cars registered yet',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap "Add New Car" to register your car',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
                itemCount: _cars.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 20,
                  color: Colors.transparent,
                ),
                itemBuilder: (context, index) {
                  final car = _cars[index];
                  return Card(
                    color: Colors.white.withOpacity(0.95),
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: bg,
                                backgroundImage:
                                    car.imageUrl != null ? NetworkImage(car.imageUrl!) : null,
                                child: car.imageUrl == null
                                    ? const Icon(Icons.directions_car,
                                        color: Colors.white, size: 30)
                                    : null,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      car.model,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      car.plateNumber,
                                      style:
                                          TextStyle(fontSize: 16, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editCar(car),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCar(car.id, car.imageUrl),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (car.transmission != 'Select' || car.fuelType != 'Select')
                            Row(
                              children: [
                                if (car.transmission != 'Select')
                                  _buildDetailItem(Icons.settings, car.transmission),
                                if (car.transmission != 'Select' && car.fuelType != 'Select')
                                  const SizedBox(width: 15),
                                if (car.fuelType != 'Select')
                                  _buildDetailItem(Icons.local_gas_station, car.fuelType),
                              ],
                            ),
                          if (car.transmission != 'Select' || car.fuelType != 'Select')
                            const SizedBox(height: 8),
                          if (car.insuranceCompany != null &&
                              car.insuranceCompany!.isNotEmpty)
                            Row(
                              children: [
                                _buildDetailItem(Icons.security, 'Insurance:'),
                                const SizedBox(width: 8),
                                Text(
                                  car.insuranceCompany!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          if (car.insuranceCompany != null &&
                              car.insuranceCompany!.isNotEmpty)
                            const SizedBox(height: 5),
                          Text(
                            'Color: ${car.color} | Year: ${car.year} | ${car.seatingDisplay}',
                            style:
                                const TextStyle(fontSize: 13, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      // >>> FAB hanya muncul kalau belum ada kereta
      floatingActionButton: _cars.length >= 1
          ? null
          : FloatingActionButton.extended(
              onPressed: _addNewCar,
              backgroundColor: Colors.white,
              foregroundColor: bg,
              icon: const Icon(Icons.add),
              label: const Text('Add New Car'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ==================== CAR FORM PAGE ====================
class CarDetailsFormPage extends StatefulWidget {
  final CarDetails? carToEdit;
  const CarDetailsFormPage({super.key, this.carToEdit});

  @override
  State<CarDetailsFormPage> createState() => _CarDetailsFormPageState();
}

class _CarDetailsFormPageState extends State<CarDetailsFormPage> {
  final CarService _carService = CarService();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();

  String _selectedTransmission = 'Select';
  String _selectedFuelType = 'Select';
  String _selectedSeatingRange = 'Select';
  String _selectedYear = 'Select';

  File? _carImage;
  bool _isSaving = false;

  final List<String> _transmissionOptions = ['Select', 'Auto', 'Manual'];
  final List<String> _fuelTypeOptions = ['Select', 'Petrol', 'Diesel', 'Electric', 'Hybrid'];
  final List<String> _seatingRangeOptions = [
    'Select',
    '1 Seat',
    '2 Seats',
    '4-5 Seats',
    '6-7 Seats',
    '8-9 Seats',
    '10+ Seats',
  ];
  final List<String> _yearOptions = [];

  @override
  void initState() {
    super.initState();
    _generateYearOptions();

    if (widget.carToEdit != null) {
      _modelController.text = widget.carToEdit!.model;
      _plateController.text = widget.carToEdit!.plateNumber;
      _colorController.text = widget.carToEdit!.color;
      _selectedYear = widget.carToEdit!.year.toString();
      _insuranceController.text = widget.carToEdit!.insuranceCompany ?? '';
      _selectedTransmission = widget.carToEdit!.transmission;
      _selectedFuelType = widget.carToEdit!.fuelType;
      _selectedSeatingRange = widget.carToEdit!.seatingRange;
      _carImage = widget.carToEdit!.carImage;
    } else {
      _selectedYear = DateTime.now().year.toString();
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _insuranceController.dispose();
    super.dispose();
  }

  void _generateYearOptions() {
    final currentYear = DateTime.now().year;
    const startYear = 1990;

    for (int year = currentYear + 1; year >= startYear; year--) {
      _yearOptions.add(year.toString());
    }
    _yearOptions.insert(0, 'Select');
  }

  Future<void> _pickCarImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _carImage = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _saveCar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedYear == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select car year')),
      );
      return;
    }

    final int? year = int.tryParse(_selectedYear);
    final currentYear = DateTime.now().year;

    if (year == null || year < 1990 || year > currentYear + 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid year (1990-${currentYear + 1})')),
      );
      return;
    }

    if (_selectedTransmission == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select transmission type')),
      );
      return;
    }

    if (_selectedFuelType == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select fuel type')),
      );
      return;
    }

    if (_selectedSeatingRange == 'Select') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select seating range')),
      );
      return;
    }

    if (_carImage == null && widget.carToEdit?.imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a car image')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final carDetails = CarDetails(
        id: widget.carToEdit?.id ?? '',
        model: _modelController.text.trim(),
        plateNumber: _plateController.text.trim(),
        color: _colorController.text.trim(),
        seatingRange: _selectedSeatingRange,
        year: year,
        transmission: _selectedTransmission,
        fuelType: _selectedFuelType,
        insuranceCompany: _insuranceController.text.trim().isNotEmpty
            ? _insuranceController.text.trim()
            : null,
        imageUrl: widget.carToEdit?.imageUrl,
        carImage: _carImage,
      );

      if (widget.carToEdit == null) {
        await _carService.addCar(carDetails, imageFile: _carImage);
      } else {
        await _carService.updateCar(carDetails, newImageFile: _carImage);
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
      validator: validator ??
          (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
    );
  }

  Widget _buildDropdown(
      String label, String value, List<String> items, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: hexStringToColor("365770"),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            iconSize: 24,
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    color: item == 'Select' ? Colors.white70 : Colors.white,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Car Image',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickCarImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white70),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _carImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_carImage!, fit: BoxFit.cover),
                  )
                : widget.carToEdit?.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.carToEdit!.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.error, color: Colors.white70),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.add_a_photo, size: 40, color: Colors.white70),
                      ),
          ),
        ),
        if (_carImage != null || widget.carToEdit?.imageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _carImage != null
                  ? 'Selected: ${_carImage!.path.split('/').last}'
                  : 'Current image from database',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          widget.carToEdit == null ? 'Add New Car' : 'Edit Car',
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bg, bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
            child: Column(
              children: [
                _buildTextField(
                  controller: _modelController,
                  label: "Car Model",
                  icon: Icons.directions_car,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _plateController,
                  label: "Plate Number",
                  icon: Icons.tag,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Plate number is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Plate number is too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _colorController,
                  label: "Color",
                  icon: Icons.color_lens,
                ),
                const SizedBox(height: 20),
                _buildDropdown(
                  'Year',
                  _selectedYear,
                  _yearOptions,
                  (value) {
                    if (value != null) {
                      setState(() => _selectedYear = value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _insuranceController,
                  label: "Insurance Company (Optional)",
                  icon: Icons.security,
                  isRequired: false,
                ),
                const SizedBox(height: 20),
                _buildDropdown(
                  'Transmission',
                  _selectedTransmission,
                  _transmissionOptions,
                  (value) {
                    if (value != null) {
                      setState(() => _selectedTransmission = value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                _buildDropdown(
                  'Fuel Type',
                  _selectedFuelType,
                  _fuelTypeOptions,
                  (value) {
                    if (value != null) {
                      setState(() => _selectedFuelType = value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                _buildDropdown(
                  'Seating Range',
                  _selectedSeatingRange,
                  _seatingRangeOptions,
                  (value) {
                    if (value != null) {
                      setState(() => _selectedSeatingRange = value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                _buildImagePicker(),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveCar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.carToEdit == null ? "Add Car" : "Save Changes",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
