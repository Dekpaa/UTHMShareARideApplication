import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class DriverEarningsPage extends StatefulWidget {
  const DriverEarningsPage({super.key});

  @override
  State<DriverEarningsPage> createState() => _DriverEarningsPageState();
}

class _DriverEarningsPageState extends State<DriverEarningsPage> {
  final String _driverId = FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;

  double _monthTotal = 0;
  int _monthTrips = 0;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedYear = DateTime.now().year;

  List<Map<String, dynamic>> _monthlyList = [];
  Map<int, double> _yearlyChartData = {}; // month -> earnings

  // List bulan
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    setState(() => _loading = true);

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('driverId', isEqualTo: _driverId)
        .where('paymentStatus', isEqualTo: 'approved')
        .get();

    Map<int, double> chartTemp = {};
    List<Map<String, dynamic>> listTemp = [];

    double monthTotal = 0;
    int monthTrips = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final fare = (data['fare'] ?? 0).toDouble();
      final approvedAt = data['paymentApprovedAt'] as Timestamp?;

      if (approvedAt == null) continue;

      final date = approvedAt.toDate();

      // ===== CHART (YEAR) =====
      if (date.year == DateTime.now().year) {
        chartTemp[date.month] = (chartTemp[date.month] ?? 0) + fare;
      }

      // ===== FILTER MONTH =====
      if (date.month == _selectedMonth.month &&
          date.year == _selectedMonth.year) {
        monthTotal += fare;
        monthTrips++;

        listTemp.add({
          'passengerName': data['passengerName'] ?? 'Passenger',
          'fare': fare,
          'approvedAt': approvedAt,
        });
      }
    }

    listTemp.sort((a, b) {
      final t1 = a['approvedAt'] as Timestamp;
      final t2 = b['approvedAt'] as Timestamp;
      return t2.compareTo(t1);
    });

    setState(() {
      _yearlyChartData = chartTemp;
      _monthlyList = listTemp;
      _monthTotal = monthTotal;
      _monthTrips = monthTrips;
      _loading = false;
    });
  }

  Future<void> _selectMonth() async {
    final years = List<int>.generate(5, (i) => DateTime.now().year - 2 + i);
    String selectedMonthName = _months[_selectedMonth.month - 1];
    int selectedYear = _selectedYear;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Month'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dropdown untuk tahun
                    DropdownButtonFormField<int>(
                      value: selectedYear,
                      items: years.map((year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedYear = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Grid untuk bulan
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _months.length,
                      itemBuilder: (context, index) {
                        final monthName = _months[index];
                        final isSelected = monthName == selectedMonthName;
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedMonthName = monthName;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                monthName.substring(0, 3), // Short form
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final monthIndex = _months.indexOf(selectedMonthName) + 1;
                    setState(() {
                      _selectedMonth = DateTime(selectedYear, monthIndex);
                      _selectedYear = selectedYear;
                    });
                    Navigator.pop(context);
                    _fetchEarnings();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('My Earnings', style: TextStyle(color: Colors.white,fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ================= FILTER =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _selectMonth,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Change'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ================= SUMMARY =================
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryItem(
                          title: 'Earnings',
                          value: 'RM ${_monthTotal.toStringAsFixed(2)}',
                        ),
                        _summaryItem(
                          title: 'Trips',
                          value: '$_monthTrips',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ================= BAR CHART =================
                const Text(
                  'Monthly Earnings (This Year)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              return Text(
                                DateFormat.MMM().format(
                                  DateTime(0, value.toInt()),
                                ),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(12, (index) {
                        final month = index + 1;
                        final value = _yearlyChartData[month] ?? 0;
                        return BarChartGroupData(
                          x: month,
                          barRods: [
                            BarChartRodData(
                              toY: value,
                              color: Colors.green,
                              width: 14,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ================= LIST =================
                const Text(
                  'Earnings Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (_monthlyList.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No earnings for selected month',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),

                ..._monthlyList.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(
                        Icons.attach_money,
                        color: Colors.green,
                      ),
                      title: Text(item['passengerName']),
                      subtitle: Text(
                        DateFormat('dd MMM yyyy, hh:mm a')
                            .format(item['approvedAt'].toDate()),
                      ),
                      trailing: Text(
                        'RM ${item['fare'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _summaryItem({required String title, required String value}) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}