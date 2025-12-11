import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RestaurantApp());
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAST FOOD abcd - Restaurant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB24024),
          brightness: Brightness.light,
          primary: const Color(0xFFB24024),
          secondary: const Color(0xFF1F6B4D),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F1E8),
        primaryColor: const Color(0xFFB24024),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF2C1B14),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      home: const OrdersScreen(),
    );
  }
}

/// --------- MODÈLES ---------

class RestaurantOrder {
  final String id;
  final String status;
  final double total;
  final DateTime? createdAt;
  final String? customerName;
  final String? customerPhone;
  final DateTime? scheduledReadyAt;
  final List<OrderLine> items;

  RestaurantOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.scheduledReadyAt,
    required this.items,
  });

  factory RestaurantOrder.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    // items peut être une liste ou autre chose -> on sécurise
    final dynamic rawItemsValue = data['items'];
    final List<dynamic> rawItems =
        rawItemsValue is List ? rawItemsValue : <dynamic>[];

    return RestaurantOrder(
      id: doc.id,
      status: (data['status'] as String?) ?? 'received',
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      customerName: data['customerName'] as String?,
      customerPhone: data['customerPhone'] as String?,
      scheduledReadyAt:
          (data['scheduledReadyAt'] as Timestamp?)?.toDate(),
      items: rawItems
          .whereType<Map>() // ignore ce qui n’est pas un map
          .map((e) =>
              OrderLine.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class OrderLine {
  final String name;
  final double unitPrice;
  final int quantity;
  final List<OrderExtra> extras;

  OrderLine({
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.extras,
  });

  factory OrderLine.fromMap(Map<String, dynamic> map) {
    final dynamic rawExtrasValue = map['extras'];
    final List<dynamic> rawExtras =
        rawExtrasValue is List ? rawExtrasValue : <dynamic>[];

    return OrderLine(
      name: map['name'] as String? ?? 'Produit',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      extras: rawExtras
          .whereType<Map>()
          .map((e) =>
              OrderExtra.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class OrderExtra {
  final String name;
  final double price;

  OrderExtra({
    required this.name,
    required this.price,
  });

  factory OrderExtra.fromMap(Map<String, dynamic> map) {
    return OrderExtra(
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// --------- ÉCRAN PRINCIPAL ---------

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, Timer> _readyTimers = {};
  final Set<String> _knownOrderIds = {};
  final Set<String> _freshOrderIds = {};
  bool _hasLoadedOnce = false;
  late final AnimationController _blinkController;
  late final AudioPlayer _audioPlayer;
  late final Uint8List _notificationTone;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _audioPlayer = AudioPlayer();
    unawaited(_audioPlayer.setReleaseMode(ReleaseMode.stop));
    _notificationTone = _buildNotificationTone();
  }

  @override
  void dispose() {
    // On annule les timers quand l'écran est détruit
    for (final t in _readyTimers.values) {
      t.cancel();
    }
    _readyTimers.clear();
    _blinkController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Stream<List<RestaurantOrder>> _ordersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final List<RestaurantOrder> orders = [];
      for (final doc in snapshot.docs) {
        try {
          orders.add(RestaurantOrder.fromDoc(doc));
        } catch (e, st) {
          // En prod on loguerait ça, mais on ne casse pas tout l'écran
          // print('Erreur de parsing pour ${doc.id} : $e\n$st');
        }
      }
      return orders;
    });
  }

  void _handleIncomingOrders(List<RestaurantOrder> orders) {
    final incomingIds = orders.map((o) => o.id).toSet();
    final receivedIds =
        orders.where((o) => o.status == 'received').map((o) => o.id).toSet();

    _freshOrderIds.removeWhere((id) => !receivedIds.contains(id));

    final newIds = incomingIds.difference(_knownOrderIds);
    _knownOrderIds
      ..clear()
      ..addAll(incomingIds);

    final bool isFirstLoad = !_hasLoadedOnce;
    _hasLoadedOnce = true;

    if (newIds.isEmpty) return;

    final Set<String> newReceived = receivedIds.intersection(newIds);
    _freshOrderIds.addAll(newReceived);
    if (!isFirstLoad && newReceived.isNotEmpty) {
      _playNotificationSound();
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(BytesSource(_notificationTone));
    } catch (_) {
      // On ignore les erreurs sonores pour ne pas bloquer l'interface.
    }
  }

  Uint8List _buildNotificationTone() {
    const int sampleRate = 44100;
    const double durationSeconds = 0.35;
    const double frequency = 880.0;
    final int sampleCount = (sampleRate * durationSeconds).toInt();
    final BytesBuilder dataBuilder = BytesBuilder();

    for (int i = 0; i < sampleCount; i++) {
      final double t = i / sampleRate;
      final double envelope = 1 - (i / sampleCount);
      final double tone = sin(2 * pi * frequency * t) * envelope;
      final int sample =
          (tone * 32767).toInt().clamp(-32768, 32767) as int;
      dataBuilder.add([sample & 0xff, (sample >> 8) & 0xff]);
    }

    final int subchunk2Size = dataBuilder.length;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int audioFormat = 1; // PCM
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);

    final BytesBuilder bytes = BytesBuilder();
    void writeString(String value) => bytes.add(utf8.encode(value));
    void writeUint32(int value) => bytes.add([
          value & 0xff,
          (value >> 8) & 0xff,
          (value >> 16) & 0xff,
          (value >> 24) & 0xff,
        ]);
    void writeUint16(int value) => bytes.add([
          value & 0xff,
          (value >> 8) & 0xff,
        ]);

    writeString('RIFF');
    writeUint32(36 + subchunk2Size);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(audioFormat);
    writeUint16(numChannels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeString('data');
    writeUint32(subchunk2Size);
    bytes.add(dataBuilder.toBytes());

    return bytes.toBytes();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return const Color(0xFFD38B22);
      case 'preparing':
        return const Color(0xFF1F6B4D);
      case 'ready':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'received':
        return 'Reçue';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête';
      default:
        return status;
    }
  }

  Future<void> _updateStatus(String orderId, String status) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'status': status,
      if (status == 'ready') 'scheduledReadyAt': null,
    });

    if (status != 'received') {
      setState(() {
        _freshOrderIds.remove(orderId);
      });
    }
  }

  /// Planifie automatiquement le passage en "ready" après X minutes.
  Future<void> _scheduleReadyIn(
      RestaurantOrder order, int minutes) async {
    final now = DateTime.now();
    final scheduled = now.add(Duration(minutes: minutes));

    // Mise à jour Firestore avec info de planning
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .update({
      'status': 'preparing',
      'scheduledReadyAt': Timestamp.fromDate(scheduled),
    });

    setState(() {
      _freshOrderIds.remove(order.id);
    });

    // Annule éventuellement un ancien timer pour cette commande
    _readyTimers[order.id]?.cancel();

    // Crée un nouveau timer local
    final timer = Timer(Duration(minutes: minutes), () async {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .get();

      if (!doc.exists) return;
      final currentStatus =
          (doc.data()?['status'] as String?) ?? 'received';

      // On ne passe en "ready" que si la commande n'est pas déjà prête
      if (currentStatus != 'ready') {
        await doc.reference.update({'status': 'ready'});
      }
    });

    _readyTimers[order.id] = timer;
  }

  void _openOrderDetails(RestaurantOrder order) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Commande ${order.id.substring(0, 6)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(order.status),
                      style: TextStyle(
                        fontSize: 13,
                        color: _statusColor(order.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Infos client
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client : ${order.customerName ?? '—'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Téléphone : ${order.customerPhone ?? '—'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (order.scheduledReadyAt != null)
                      Text(
                        'Prêt vers : '
                        '${_formatTime(order.scheduledReadyAt!)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Liste des produits
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final line = order.items[index];
                    final extrasText = line.extras.isEmpty
                        ? ''
                        : ' + ${line.extras.map((e) => e.name).join(', ')}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${line.name}${extrasText}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Qté: ${line.quantity} | '
                        'Prix: DT ${line.unitPrice.toStringAsFixed(3)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total : DT ${order.total.toStringAsFixed(3)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Boutons d'actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(color: colorScheme.primary),
                      ),
                      onPressed: order.status == 'received'
                          ? () => _updateStatus(
                                order.id,
                                'preparing',
                              )
                          : null,
                      child: const Text('Accepter / Préparer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(color: colorScheme.primary),
                      ),
                      onPressed: order.status != 'ready'
                          ? () => _updateStatus(order.id, 'ready')
                          : null,
                      child: const Text('Prête maintenant'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: order.status == 'ready'
                      ? null
                      : () => _showScheduleDialog(order),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Définir "prête dans..."'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showScheduleDialog(RestaurantOrder order) {
    final colorScheme = Theme.of(context).colorScheme;
    final List<int> delays = [5, 10, 15, 20, 25, 30, 35, 40];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Prête dans combien de minutes ?'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: delays.map((m) {
              return ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _scheduleReadyIn(order, m);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Commande planifiée "prête" dans $m minutes.'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text('$m min'),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAST FOOD abcd - Commandes'),
      ),
      body: StreamBuilder<List<RestaurantOrder>>(
        stream: _ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Erreur de chargement des commandes.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!;
          _handleIncomingOrders(orders);
          final totalRevenue = orders.fold<double>(
              0.0, (sum, o) => sum + o.total);
          final readyCount =
              orders.where((o) => o.status == 'ready').length;

          return Column(
            children: [
              // Résumé en haut
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Commandes totales',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${orders.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Montant total',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'DT ${totalRevenue.toStringAsFixed(3)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Commandes prêtes',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$readyCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: orders.isEmpty
                    ? const Center(
                        child: Text('Aucune commande pour le moment.'),
                      )
                    : ListView.builder(
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return _buildOrderCard(order);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(RestaurantOrder order) {
    final colorScheme = Theme.of(context).colorScheme;
    final created =
        order.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timeStr = _formatTime(created);
    final String shortId =
        order.id.length > 6 ? order.id.substring(0, 6) : order.id;
    final bool isFresh =
        order.status == 'received' && _freshOrderIds.contains(order.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Commande $shortId',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isFresh)
                    AnimatedBuilder(
                      animation: _blinkController,
                      builder: (context, child) => Opacity(
                        opacity:
                            0.45 + 0.55 * (1 - _blinkController.value),
                        child: child,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'NOUVEAU',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(order.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(order.status),
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(order.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Client : ${order.customerName ?? '—'}',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                'Téléphone : ${order.customerPhone ?? '—'}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Heure : $timeStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  if (order.scheduledReadyAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Prêt vers : ${_formatTime(order.scheduledReadyAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'DT ${order.total.toStringAsFixed(3)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
