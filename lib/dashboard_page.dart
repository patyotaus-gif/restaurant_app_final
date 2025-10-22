// lib/dashboard_page.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'currency_provider.dart';

// NOTE: This model is a local helper, not from a file, so it's okay.
class _ProfitData {
  String name;
  int quantitySold = 0;
  double totalRevenue = 0;
  double totalCost = 0;
  double get netProfit => totalRevenue - totalCost;

  _ProfitData({required this.name});
}

enum TimeFilter { today, thisWeek, thisMonth }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  TimeFilter _selectedFilter = TimeFilter.thisWeek;
  late Future<Map<String, dynamic>> _salesData;

  @override
  void initState() {
    super.initState();
    _fetchDataForSelectedRange();
  }

  void _fetchDataForSelectedRange() {
    setState(() {
      _salesData = _generateReport();
    });
  }

  Map<String, DateTimeRange> _getDateRanges() {
    final now = DateTime.now();
    DateTime startCurrent, endCurrent, startPrevious, endPrevious;

    switch (_selectedFilter) {
      case TimeFilter.today:
        startCurrent = DateTime(now.year, now.month, now.day);
        endCurrent = startCurrent.add(const Duration(days: 1));
        startPrevious = startCurrent.subtract(const Duration(days: 1));
        endPrevious = startCurrent;
        break;
      case TimeFilter.thisWeek:
        startCurrent = now.subtract(Duration(days: now.weekday - 1));
        startCurrent = DateTime(
          startCurrent.year,
          startCurrent.month,
          startCurrent.day,
        );
        endCurrent = startCurrent.add(const Duration(days: 7));
        startPrevious = startCurrent.subtract(const Duration(days: 7));
        endPrevious = startCurrent;
        break;
      case TimeFilter.thisMonth:
        startCurrent = DateTime(now.year, now.month, 1);
        endCurrent = DateTime(now.year, now.month + 1, 1);
        startPrevious = DateTime(now.year, now.month - 1, 1);
        endPrevious = startCurrent;
        break;
    }
    return {
      'current': DateTimeRange(start: startCurrent, end: endCurrent),
      'previous': DateTimeRange(start: startPrevious, end: endPrevious),
    };
  }

  Future<Map<String, dynamic>> _generateReport() async {
    final ranges = _getDateRanges();
    final currentRange = ranges['current']!;
    final previousRange = ranges['previous']!;

    final results = await Future.wait([
      _fetchDataForRange(currentRange),
      _fetchDataForRange(previousRange),
    ]);

    final currentData = results[0];
    final previousData = results[1];

    return {
      'totalRevenue': currentData['totalRevenue'],
      'previousTotalRevenue': previousData['totalRevenue'],
      'totalCogs': currentData['totalCogs'],
      'grossProfit': currentData['grossProfit'],
      'totalOrders': currentData['totalOrders'],
      'previousTotalOrders': previousData['totalOrders'],
      'lineChartSpots': currentData['dailySalesSpots'],
      'maxYLineChart': currentData['maxY'],
      'hourlySales': currentData['hourlySales'],
      'profitabilityReport': currentData['profitabilityReport'],
    };
  }

  Future<Map<String, dynamic>> _fetchDataForRange(
    DateTimeRange dateRange,
  ) async {
    final startOfDay = Timestamp.fromDate(dateRange.start);
    final endOfDay = Timestamp.fromDate(dateRange.end);

    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThanOrEqualTo: endOfDay)
        .get();

    double totalRevenue = 0;
    double totalCogs = 0;
    double grossProfit = 0;
    Map<int, double> dailySales = {};
    Map<int, double> hourlySales = {};
    Map<String, _ProfitData> profitabilityData = {};

    for (var doc in ordersSnapshot.docs) {
      final data = doc.data();
      final orderTotal = (data['total'] as num? ?? 0.0).toDouble();
      final orderCost = (data['totalCostOfGoodsSold'] as num? ?? 0.0)
          .toDouble();

      totalRevenue += orderTotal;
      totalCogs += orderCost;

      final date = (data['timestamp'] as Timestamp).toDate();
      dailySales.update(
        date.weekday,
        (v) => v + orderTotal,
        ifAbsent: () => orderTotal,
      );
      hourlySales.update(
        date.hour,
        (v) => v + orderTotal,
        ifAbsent: () => orderTotal,
      );

      final itemsSold = data['items'];
      if (itemsSold is List) {
        for (final itemData in itemsSold) {
          if (itemData is Map<String, dynamic>) {
            final profitEntry = profitabilityData.putIfAbsent(
              itemData['name'],
              () => _ProfitData(name: itemData['name']),
            );
            profitEntry.quantitySold +=
                (itemData['quantity'] as num?)?.toInt() ?? 0;
          }
        }
      }
    }

    grossProfit = totalRevenue - totalCogs;

    final spots = dailySales.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maxY = dailySales.values.isEmpty
        ? 100.0
        : dailySales.values.reduce(max);

    final sortedProfitReport = profitabilityData.values.toList();

    return {
      'totalRevenue': totalRevenue,
      'totalCogs': totalCogs,
      'grossProfit': grossProfit,
      'totalOrders': ordersSnapshot.docs.length,
      'dailySalesSpots': spots,
      'maxY': maxY * 1.2,
      'hourlySales': hourlySales,
      'profitabilityReport': sortedProfitReport,
    };
  }

  Widget _buildStatCard(
    String title,
    double currentValue, {
    double? previousValue,
  }) {
    final currencyProvider = context.watch<CurrencyProvider>();
    double percentageChange = 0.0;
    bool isOrderCount = title == 'Total Orders';
    bool showComparison = previousValue != null;

    if (showComparison) {
      final difference = currentValue - previousValue;
      percentageChange = (previousValue.abs() < 0.01)
          ? 0.0
          : (difference / previousValue) * 100;
    }
    final isPositive = percentageChange >= 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isOrderCount
                  ? currentValue.toInt().toString()
                  : currencyProvider.formatBaseAmount(currentValue),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (showComparison)
              Text(
                percentageChange.isInfinite || percentageChange.isNaN
                    ? 'vs. 0'
                    : '${isPositive ? '▲' : '▼'} ${percentageChange.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getBottomTitlesDaily(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    String text;
    switch (value.toInt()) {
      case 1:
        text = 'Mon';
        break;
      case 2:
        text = 'Tue';
        break;
      case 3:
        text = 'Wed';
        break;
      case 4:
        text = 'Thu';
        break;
      case 5:
        text = 'Fri';
        break;
      case 6:
        text = 'Sat';
        break;
      case 7:
        text = 'Sun';
        break;
      default:
        text = '';
        break;
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      child: Text(text, style: style),
    );
  }

  Widget _buildPeakHoursChart(Map<int, double> hourlySales) {
    if (hourlySales.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text("No sales data for hourly analysis.")),
      );
    }
    final barGroups = hourlySales.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: Colors.amber,
            width: 16,
            borderRadius: BorderRadius.zero,
          ),
        ],
      );
    }).toList();
    return Column(
      children: [
        const SizedBox(height: 24),
        const Text(
          'Peak Hours Analysis (Sales per Hour)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: _getBottomTitlesHourly,
                        reservedSize: 22,
                      ),
                    ),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getBottomTitlesHourly(double value, TitleMeta meta) {
    final style = TextStyle(color: Colors.grey.shade700, fontSize: 10);
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4,
      child: Text('${value.toInt()}h', style: style),
    );
  }

  Widget _buildProfitabilityReport(List<_ProfitData> report) {
    if (report.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Most Profitable Items',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 4,
            child: DataTable(
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Menu Item')),
                DataColumn(label: Text('Qty Sold'), numeric: true),
              ],
              rows: report.take(5).map((data) {
                return DataRow(
                  cells: [
                    DataCell(Text(data.name)),
                    DataCell(Text(data.quantitySold.toString())),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Profit Dashboard'),
        backgroundColor: Colors.indigo,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Wrap(
            spacing: 8.0,
            alignment: WrapAlignment.center,
            children: [
              FilterChip(
                label: const Text('Today'),
                selected: _selectedFilter == TimeFilter.today,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedFilter = TimeFilter.today;
                      _fetchDataForSelectedRange();
                    });
                  }
                },
              ),
              FilterChip(
                label: const Text('This Week'),
                selected: _selectedFilter == TimeFilter.thisWeek,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedFilter = TimeFilter.thisWeek;
                      _fetchDataForSelectedRange();
                    });
                  }
                },
              ),
              FilterChip(
                label: const Text('This Month'),
                selected: _selectedFilter == TimeFilter.thisMonth,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedFilter = TimeFilter.thisMonth;
                      _fetchDataForSelectedRange();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _salesData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData ||
                  (snapshot.data?['totalOrders'] as int) == 0) {
                return const Center(child: Text('No data for this period.'));
              }
              final data = snapshot.data!;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Revenue',
                          data['totalRevenue'],
                          previousValue: data['previousTotalRevenue'],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Cost of Goods Sold',
                          data['totalCogs'],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Gross Profit',
                          data['grossProfit'],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Total Orders',
                          (data['totalOrders'] as int).toDouble(),
                          previousValue: (data['previousTotalOrders'] as int)
                              .toDouble(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Daily Sales Trend',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: _getBottomTitlesDaily,
                                  reservedSize: 22,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: data['lineChartSpots'],
                                isCurved: true,
                                color: Colors.indigo,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.indigo.withAlpha(50),
                                ),
                              ),
                            ],
                            minX: 1,
                            maxX: 7,
                            maxY: data['maxYLineChart'],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildPeakHoursChart(
                    Map<int, double>.from(data['hourlySales'] ?? {}),
                  ),
                  _buildProfitabilityReport(data['profitabilityReport']),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
