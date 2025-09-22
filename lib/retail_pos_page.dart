// lib/retail_pos_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:rxdart/rxdart.dart';
import 'cart_provider.dart';
import 'models/product_model.dart';
import 'widgets/customer_header_widget.dart';
import 'services/menu_cache_provider.dart';

class RetailPosPage extends StatefulWidget {
  const RetailPosPage({super.key});

  @override
  State<RetailPosPage> createState() => _RetailPosPageState();
}

class _RetailPosPageState extends State<RetailPosPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _barcodeStreamController = StreamController<String>();
  StreamSubscription<String>? _barcodeSubscription;

  @override
  void initState() {
    super.initState();
    _listenToBarcodeStream();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cart = Provider.of<CartProvider>(context, listen: false);
      cart.clear();
      cart.selectRetailSale();
    });
  }

  void _listenToBarcodeStream() {
    _barcodeSubscription = _barcodeStreamController.stream
        .debounceTime(const Duration(milliseconds: 500))
        .listen(_handleScannedBarcode);
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final String? code = capture.barcodes.first.rawValue;
    if (code != null) {
      _barcodeStreamController.add(code);
    }
  }

  Future<void> _handleScannedBarcode(String code) async {
    if (!mounted) return;

    try {
      final menuCache = Provider.of<MenuCacheProvider>(context, listen: false);
      Product? product = menuCache.productByBarcode(code);

      if (product == null) {
        final productQuery = await FirebaseFirestore.instance
            .collection('menu_items')
            .where('barcode', isEqualTo: code)
            .limit(1)
            .get();
        if (productQuery.docs.isNotEmpty) {
          product = Product.fromFirestore(productQuery.docs.first);
        }
      }

      if (product != null) {
        if (!mounted) return;
        final cart = Provider.of<CartProvider>(context, listen: false);
        cart.addItem(product);
        await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode [$code] not found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // <-- FIXED
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retail - New Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              context.push('/cart');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onBarcodeDetected,
                ),
                MobileScannerOverlay(
                  overlayColour: Colors.black.withOpacity(0.2),
                  borderColor: Colors.white,
                  borderRadius: 10,
                  borderStrokeWidth: 3,
                  cutOutSize: Size(
                    MediaQuery.of(context).size.width * 0.8,
                    120,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Consumer<CartProvider>(
              builder: (context, cart, child) {
                return Column(
                  children: [
                    const CustomerHeaderWidget(),
                    const Divider(height: 1),
                    Expanded(
                      child: cart.items.isEmpty
                          ? const Center(child: Text('Scan an item to begin.'))
                          : ListView.builder(
                              itemCount: cart.items.length,
                              itemBuilder: (context, index) {
                                final item = cart.items.values.toList()[index];
                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: Text('Qty: ${item.quantity}'),
                                  trailing: Text(
                                    (item.price * item.quantity)
                                        .toStringAsFixed(2),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${cart.totalAmount.toStringAsFixed(2)} Baht',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: cart.items.isEmpty
                                  ? null
                                  : () {
                                      context.push('/cart');
                                    },
                              child: const Text('Payment'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _audioPlayer.dispose();
    _barcodeStreamController.close();
    _barcodeSubscription?.cancel();
    super.dispose();
  }
}

class MobileScannerOverlay extends StatelessWidget {
  const MobileScannerOverlay({
    super.key,
    required this.overlayColour,
    required this.borderColor,
    required this.borderRadius,
    required this.borderStrokeWidth,
    required this.cutOutSize,
  });

  final Color overlayColour;
  final Color borderColor;
  final double borderRadius;
  final double borderStrokeWidth;
  final Size cutOutSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(overlayColour, BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(color: Colors.transparent),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: cutOutSize.height,
                  width: cutOutSize.width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            height: cutOutSize.height,
            width: cutOutSize.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: borderStrokeWidth),
            ),
          ),
        ),
      ],
    );
  }
}
