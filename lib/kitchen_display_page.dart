// lib/kitchen_display_page.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'services/query_edge_filter.dart';

class KitchenDisplayPage extends StatefulWidget {
  const KitchenDisplayPage({super.key, this.initialStationId});

  final String? initialStationId;

  @override
  State<KitchenDisplayPage> createState() => _KitchenDisplayPageState();
}

class _KitchenDisplayPageState extends State<KitchenDisplayPage> {
  static const Duration _activeWindow = Duration(hours: 3);
  static const int _kdsDisplayLimit = 60;

  String? _selectedStationId;
  List<KitchenStation> _stations = const [];
  DateTime _edgeAnchor = DateTime.now();
  Timer? _edgeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedStationId = widget.initialStationId;
    _edgeRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshEdge(),
    );
  }

  @override
  void dispose() {
    _edgeRefreshTimer?.cancel();
    super.dispose();
  }

  KitchenStation? get _activeStation {
    if (_selectedStationId == null) {
      return null;
    }
    for (final station in _stations) {
      if (station.id == _selectedStationId) {
        return station;
      }
    }
    return null;
  }

  void _onStationChanged(String? stationId) {
    setState(() {
      _selectedStationId = stationId?.isEmpty ?? false ? null : stationId;
    });
  }

  void _refreshEdge() {
    setState(() {
      _edgeAnchor = DateTime.now();
    });
  }

  Query<Map<String, dynamic>> _activeOrdersQuery() {
    final DateTime lowerBound = _edgeAnchor.subtract(_activeWindow);
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'preparing')
        .edgeFilter(field: 'timestamp', startAt: lowerBound)
        .orderBy('timestamp', descending: false)
        .limit(_kdsDisplayLimit);
  }

  @override
  Widget build(BuildContext context) {
    final baseBackground = Colors.blueGrey[900];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)'),
        backgroundColor: Colors.blueGrey[800],
      ),
      backgroundColor: baseBackground,
      body: Column(
        children: [
          _StationSelector(
            onStationsLoaded: (stations) {
              _stations = stations;
            },
            selectedStationId: _selectedStationId,
            onChanged: _onStationChanged,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activeOrdersQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _KdsSkeletonGrid();
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Something went wrong',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final station = _activeStation;
                final orderDocs = snapshot.data!.docs.where((doc) {
                  if (station == null) {
                    return true;
                  }
                  final data = doc.data();
                  final items = (data['items'] ?? []) as List<dynamic>;
                  return items.any(
                    (item) =>
                        item is Map<String, dynamic> &&
                        station.matchesItem(item),
                  );
                }).toList();

                if (orderDocs.isEmpty) {
                  return Center(
                    child: Text(
                      station == null
                          ? 'No active orders'
                          : 'No orders for ${station.name}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: orderDocs.length,
                  itemBuilder: (context, index) {
                    final order = orderDocs[index];
                    return RepaintBoundary(
                      key: ValueKey(order.id),
                      child: _OrderCard(orderDoc: order, station: station),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StationSelector extends StatelessWidget {
  const _StationSelector({
    required this.selectedStationId,
    required this.onChanged,
    required this.onStationsLoaded,
  });

  final String? selectedStationId;
  final ValueChanged<String?> onChanged;
  final ValueChanged<List<KitchenStation>> onStationsLoaded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.blueGrey[850],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('kitchenStations')
            .orderBy('displayOrder')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _StationSelectorSkeleton();
          }
          if (snapshot.hasError) {
            return const Text(
              'Unable to load kitchen stations',
              style: TextStyle(color: Colors.white70),
            );
          }

          final stations =
              snapshot.data?.docs
                  .map((doc) => KitchenStation.fromFirestore(doc))
                  .toList() ??
              const <KitchenStation>[];
          onStationsLoaded(stations);

          final dropdownItems = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Stations'),
            ),
            ...stations.map(
              (station) => DropdownMenuItem<String?>(
                value: station.id,
                child: Text(station.name),
              ),
            ),
          ];

          return Row(
            children: [
              const Icon(Icons.route, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: stations.any((s) => s.id == selectedStationId)
                        ? selectedStationId
                        : null,
                    items: dropdownItems,
                    onChanged: onChanged,
                    dropdownColor: Colors.blueGrey[900],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({required this.orderDoc, this.station});

  final DocumentSnapshot orderDoc;
  final KitchenStation? station;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggleItemComplete(int itemIndex) {
    final rawData = widget.orderDoc.data() as Map<String, dynamic>? ?? {};
    final List<dynamic> items = List<dynamic>.from(rawData['items'] ?? []);
    if (itemIndex < 0 || itemIndex >= items.length) {
      return;
    }
    final Map<String, dynamic> item = Map<String, dynamic>.from(
      items[itemIndex] as Map<String, dynamic>,
    );
    final bool currentStatus = item['isComplete'] == true;
    item['isComplete'] = !currentStatus;
    items[itemIndex] = item;
    widget.orderDoc.reference.update({'items': items});
  }

  Future<void> _acknowledgeOrder() async {
    await widget.orderDoc.reference.update({
      'kdsAcknowledged': true,
      'kdsAcknowledgedAt': Timestamp.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderData = widget.orderDoc.data() as Map<String, dynamic>;
    final items = (orderData['items'] ?? []) as List<dynamic>;
    final station = widget.station;
    final List<Map<String, dynamic>> filteredItems = station == null
        ? items.whereType<Map<String, dynamic>>().toList()
        : items
              .whereType<Map<String, dynamic>>()
              .where(station.matchesItem)
              .toList();

    if (filteredItems.isEmpty) {
      return const SizedBox.shrink();
    }
    final timestamp = (orderData['timestamp'] as Timestamp).toDate();
    final now = DateTime.now();
    final elapsed = now.difference(timestamp);
    final double slaMinutes = _calculateSla(orderData, filteredItems);
    final Duration slaDuration = Duration(minutes: slaMinutes.round());
    final bool isOverdue = elapsed > slaDuration;
    final bool nearSla =
        !isOverdue && elapsed.inSeconds >= (slaDuration.inSeconds * 0.75);
    final Color? cardColor = isOverdue
        ? Colors.red[700]
        : (nearSla ? Colors.orange[700] : Colors.blueGrey[700]);

    final orderIdentifier = orderData['orderIdentifier'] ?? 'N/A';
    final orderType = orderData['orderType'] ?? '';
    final bool allItemsComplete = items.whereType<Map<String, dynamic>>().every(
      (item) => item['isComplete'] == true,
    );
    final bool isAcknowledged = orderData['kdsAcknowledged'] == true;
    final Timestamp? acknowledgedAtTs =
        orderData['kdsAcknowledgedAt'] as Timestamp?;
    final DateTime? acknowledgedAt = acknowledgedAtTs?.toDate();

    return Card(
      color: cardColor,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderIdentifier,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elapsed: ${_formatDuration(elapsed)} / SLA ${slaMinutes.toStringAsFixed(0)}m',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(orderType),
                      backgroundColor: orderType == 'Dine-in'
                          ? Colors.orange
                          : Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm:ss').format(timestamp),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isAcknowledged ? Icons.check_circle : Icons.touch_app,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isAcknowledged
                        ? 'Acknowledged${acknowledgedAt != null ? ' at ${DateFormat.Hm().format(acknowledgedAt)}' : ''}'
                        : 'Awaiting acknowledgement',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                if (!isAcknowledged)
                  TextButton(
                    onPressed: _acknowledgeOrder,
                    child: const Text('Acknowledge'),
                  ),
              ],
            ),
            const Divider(color: Colors.white54, height: 20),
            Expanded(
              child: RepaintBoundary(
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final bool isComplete = item['isComplete'] ?? false;
                    final List<dynamic> modifiers =
                        item['selectedModifiers'] ?? const [];
                    final modifierWidgets = modifiers.map((mod) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 24.0, top: 2.0),
                        child: Text(
                          "- ${mod['optionName']}",
                          style: TextStyle(
                            fontSize: 14,
                            color: isComplete ? Colors.white38 : Colors.white70,
                            fontStyle: FontStyle.italic,
                            decoration: isComplete
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      );
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onTap: () => _toggleItemComplete(items.indexOf(item)),
                          title: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['quantity']}x',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isComplete
                                      ? Colors.white54
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isComplete
                                            ? Colors.white54
                                            : Colors.white,
                                        decoration: isComplete
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                    if ((item['prepTimeMinutes'] ?? 0) > 0)
                                      Text(
                                        'Prep ${item['prepTimeMinutes']}m',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isComplete
                                              ? Colors.white38
                                              : Colors.white70,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...modifierWidgets,
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: allItemsComplete
                    ? () async {
                        await widget.orderDoc.reference.update({
                          'status': 'serving',
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'READY',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateSla(
    Map<String, dynamic> orderData,
    List<Map<String, dynamic>> items,
  ) {
    final List<double> prepTimes = items
        .map((item) => (item['prepTimeMinutes'] as num?)?.toDouble() ?? 0.0)
        .where((value) => value > 0)
        .toList();
    if (prepTimes.isNotEmpty) {
      return prepTimes.reduce(
        (value, element) => value > element ? value : element,
      );
    }
    return (orderData['slaMinutes'] as num?)?.toDouble() ?? 15.0;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes >= 120) {
      final hours = duration.inHours;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
    if (minutes >= 1) {
      return '${minutes}m';
    }
    return '${seconds}s';
  }
}

class _KdsSkeletonGrid extends StatelessWidget {
  const _KdsSkeletonGrid();

  static const int _placeholderCount = 8;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _placeholderCount,
      itemBuilder: (_, __) => const _KdsSkeletonCard(),
    );
  }
}

class _KdsSkeletonCard extends StatelessWidget {
  const _KdsSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        color: Colors.blueGrey[800],
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _SkeletonBox(width: 80, height: 20),
                  _SkeletonBox(width: 56, height: 20),
                ],
              ),
              const SizedBox(height: 12),
              const _SkeletonBox(width: 140, height: 12),
              const SizedBox(height: 4),
              const _SkeletonBox(width: 110, height: 12),
              const SizedBox(height: 16),
              const _SkeletonBox(width: 120, height: 10),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonOrderLine(),
                    SizedBox(height: 12),
                    _SkeletonOrderLine(),
                    SizedBox(height: 12),
                    _SkeletonOrderLine(),
                    Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _SkeletonBox(height: 40, borderRadius: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonOrderLine extends StatelessWidget {
  const _SkeletonOrderLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SkeletonBox(width: 30, height: 18),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(height: 16),
              SizedBox(height: 6),
              _SkeletonBox(width: 120, height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _StationSelectorSkeleton extends StatelessWidget {
  const _StationSelectorSkeleton();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: Row(
        children: [
          _SkeletonBox(width: 28, height: 28, borderRadius: 14),
          SizedBox(width: 12),
          Expanded(child: _SkeletonBox(height: 36, borderRadius: 12)),
          SizedBox(width: 12),
          _SkeletonBox(width: 80, height: 14),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.height = 16, this.width, this.borderRadius = 8});

  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF4A6572),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
