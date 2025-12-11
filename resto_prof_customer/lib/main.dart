import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RestoProfCustomerApp());
}

class RestoProfCustomerApp extends StatelessWidget {
  const RestoProfCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fast Food abcd',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.deepOrange,
        useMaterial3: false,
        fontFamily: 'Roboto',
      ),
      home: const MenuScreen(),
    );
  }
}

/// ---------- MODÈLES ----------

class MenuItem {
  final String name;
  final String description;
  final double price;
  final String imageAsset;
  final bool hasExtras; // pizzas / makloubs = true, boissons = false

  const MenuItem({
    required this.name,
    required this.description,
    required this.price,
    required this.imageAsset,
    this.hasExtras = false,
  });
}

class Category {
  final String name;
  final List<MenuItem> items;

  const Category({
    required this.name,
    required this.items,
  });
}

class ExtraOption {
  final String name;
  final double price;

  const ExtraOption({
    required this.name,
    required this.price,
  });
}

class CartItem {
  final MenuItem item;
  final List<ExtraOption> extras;
  final double totalPrice; // prix base + extras

  const CartItem({
    required this.item,
    required this.extras,
    required this.totalPrice,
  });
}

/// Extras disponibles (pour démo) : 1 DT chacun
const List<ExtraOption> kDefaultExtras = [
  ExtraOption(name: 'Fromage', price: 1.0),
  ExtraOption(name: 'Harissa', price: 1.0),
  ExtraOption(name: 'Olives', price: 1.0),
  ExtraOption(name: 'Sauce blanche', price: 1.0),
  ExtraOption(name: 'Escalope', price: 1.0),
];

/// ---------- DONNÉES DÉMO (LIÉES À TES IMAGES) ----------

const List<Category> demoCategories = [
  Category(
    name: 'Pizzas',
    items: [
      MenuItem(
        name: '4 Fromages',
        description: 'Pizza aux quatre fromages, pâte classique.',
        price: 18.0,
        imageAsset: 'assets/images/pizza_4fromage.png',
        hasExtras: true,
      ),
      MenuItem(
        name: 'Pizza Fruits de Mer',
        description: 'Fruits de mer, fromage, sauce tomate.',
        price: 22.0,
        imageAsset: 'assets/images/pizza_fruit.png',
        hasExtras: true,
      ),
      MenuItem(
        name: 'Pizza Thon',
        description: 'Thon, fromage, olives, sauce tomate.',
        price: 16.0,
        imageAsset: 'assets/images/pizza_thon.png',
        hasExtras: true,
      ),
    ],
  ),
  Category(
    name: 'Makloubs',
    items: [
      MenuItem(
        name: 'Makloub Merguez',
        description: 'Merguez, frites, salade, sauce.',
        price: 15.0,
        imageAsset: 'assets/images/makloub_merguez.png',
        hasExtras: true,
      ),
      MenuItem(
        name: 'Makloub Mixte',
        description: 'Viandes variées, frites, sauce.',
        price: 17.0,
        imageAsset: 'assets/images/makloub_mixte.png',
        hasExtras: true,
      ),
      MenuItem(
        name: 'Makloub Viande Hachée',
        description: 'Viande hachée, salade, frites, sauce.',
        price: 15.0,
        imageAsset: 'assets/images/makloub_viande.png',
        hasExtras: true,
      ),
    ],
  ),
  Category(
    name: 'Boissons',
    items: [
      MenuItem(
        name: 'Coca-Cola',
        description: 'Canette 33cl bien fraîche.',
        price: 3.0,
        imageAsset: 'assets/images/drink_coca.png',
        hasExtras: false,
      ),
      MenuItem(
        name: 'Fanta Orange',
        description: 'Canette 33cl bien fraîche.',
        price: 3.0,
        imageAsset: 'assets/images/drink_fanta.png',
        hasExtras: false,
      ),
      MenuItem(
        name: 'Sprite',
        description: 'Canette 33cl bien fraîche.',
        price: 3.0,
        imageAsset: 'assets/images/drink_sprite.png',
        hasExtras: false,
      ),
    ],
  ),
];

/// ---------- ÉCRAN MENU ----------

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int cartItemCount = 0;
  double cartTotal = 0.0;
  final List<CartItem> cartItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: demoCategories.length, vsync: this);
  }

  Future<void> _addToCart(MenuItem item) async {
    if (item.hasExtras) {
      final CartItem? withExtras = await _showExtrasSheet(item);
      if (withExtras != null) {
        setState(() {
          cartItems.add(withExtras);
          cartItemCount = cartItems.length;
          cartTotal += withExtras.totalPrice;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} ajouté avec options.'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      final cartItem = CartItem(
        item: item,
        extras: const [],
        totalPrice: item.price,
      );
      setState(() {
        cartItems.add(cartItem);
        cartItemCount = cartItems.length;
        cartTotal += cartItem.totalPrice;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} ajouté au panier.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<CartItem?> _showExtrasSheet(MenuItem item) async {
    final List<ExtraOption> selectedExtras = [];

    return showModalBottomSheet<CartItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        double currentTotal = item.price;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void toggleExtra(ExtraOption extra) {
              if (selectedExtras.contains(extra)) {
                selectedExtras.remove(extra);
                currentTotal -= extra.price;
              } else {
                selectedExtras.add(extra);
                currentTotal += extra.price;
              }
              setModalState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prix de base : DT ${item.price.toStringAsFixed(3)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Extras (1 DT chacun) :',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...kDefaultExtras.map(
                    (extra) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${extra.name} (+ DT ${extra.price.toStringAsFixed(3)})',
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: selectedExtras.contains(extra),
                      onChanged: (_) => toggleExtra(extra),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Prix total : DT ${currentTotal.toStringAsFixed(3)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(null);
                        },
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final cartItem = CartItem(
                            item: item,
                            extras: List<ExtraOption>.from(selectedExtras),
                            totalPrice: currentTotal,
                          );
                          Navigator.of(context).pop(cartItem);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirmer'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCart() {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre panier est vide.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartScreen(
          items: cartItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryTabs =
        demoCategories.map((c) => Tab(text: c.name)).toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'FAST FOOD abcd',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.deepOrange,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              tabs: categoryTabs,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: demoCategories.map((category) {
                if (category.items.isEmpty) {
                  return const Center(
                    child: Text('Bientôt disponible...'),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 80.0, top: 12.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: category.items.length,
                    itemBuilder: (context, index) {
                      final item = category.items[index];
                      return MenuItemCard(
                        item: item,
                        onAdd: () => _addToCart(item),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          _buildCartBar(),
        ],
      ),
    );
  }

  Widget _buildCartBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ouvrir le panier pour valider la commande',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _openCart,
              child: const Text(
                'Voir le panier',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- CARD D’UN PRODUIT (TOUTE LA CARTE CLIQUABLE) ----------

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onAdd;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd, // taper n’importe où sur la carte = ajouter
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.asset(
                item.imageAsset,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Text(
                'DT ${item.price.toStringAsFixed(3)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                children: [
                  const Spacer(),
                  ElevatedButton(
                    onPressed: onAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Ajouter',
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- PANIER (EDITABLE, ENVOIE LA COMMANDE À FIRESTORE) ----------

class CartScreen extends StatefulWidget {
  final List<CartItem> items;

  const CartScreen({
    super.key,
    required this.items,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<CartItem> _items;

  double get total => _items.fold(
        0.0,
        (sum, item) => sum + item.totalPrice,
      );

  @override
  void initState() {
    super.initState();
    _items = List<CartItem>.from(widget.items);
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _removeExtra(int itemIndex, int extraIndex) {
    final cartItem = _items[itemIndex];
    final newExtras = List<ExtraOption>.from(cartItem.extras)
      ..removeAt(extraIndex);
    final newTotalPrice = cartItem.item.price +
        newExtras.fold<double>(0.0, (sum, e) => sum + e.price);

    setState(() {
      _items[itemIndex] = CartItem(
        item: cartItem.item,
        extras: newExtras,
        totalPrice: newTotalPrice,
      );
    });
  }

  Future<Map<String, String>?> _askCustomerInfo(
      BuildContext context) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vos coordonnées'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom et prénom',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Merci de saisir votre nom.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Merci de saisir votre numéro.';
                    }
                    if (value.trim().length < 6) {
                      return 'Numéro trop court.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              child: const Text(
                'Confirmer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Renvoie l'ID de la commande créée dans Firestore
  Future<String?> _sendOrderToFirestore(
    BuildContext context, {
    required String customerName,
    required String customerPhone,
  }) async {
    final List<Map<String, dynamic>> lineList = _items.map((cartItem) {
      return {
        'name': cartItem.item.name,
        'unitPrice': cartItem.item.price,
        'quantity': 1,
        'extras': cartItem.extras
            .map((e) => {
                  'name': e.name,
                  'price': e.price,
                })
            .toList(),
      };
    }).toList();

    final docRef =
        await FirebaseFirestore.instance.collection('orders').add({
      'total': total,
      'status': 'received', // reçu par le système, en attente de resto
      'createdAt': FieldValue.serverTimestamp(),
      'items': lineList,
      'customerName': customerName,
      'customerPhone': customerPhone,
    });

    return docRef.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Votre commande'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Votre panier est vide.'),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final cartItem = _items[index];
                      final basePrice = cartItem.item.price;
                      final extrasTotal = cartItem.extras
                          .fold<double>(0.0, (sum, e) => sum + e.price);
                      final lineTotal = cartItem.totalPrice;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(cartItem.item.name),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (cartItem.extras.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Extras :',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Wrap(
                                  spacing: 4,
                                  children: List.generate(
                                      cartItem.extras.length,
                                      (extraIndex) {
                                    final extra =
                                        cartItem.extras[extraIndex];
                                    return InputChip(
                                      label: Text(extra.name),
                                      onDeleted: () {
                                        _removeExtra(
                                            index, extraIndex);
                                      },
                                    );
                                  }),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Détail : ${basePrice.toStringAsFixed(3)}'
                                '${extrasTotal > 0 ? ' + ${extrasTotal.toStringAsFixed(3)}' : ''}'
                                ' = ${lineTotal.toStringAsFixed(3)} DT',
                                style:
                                    const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                'DT ${lineTotal.toStringAsFixed(3)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: const Border(
                  top: BorderSide(color: Colors.black12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Total : DT ${total.toStringAsFixed(3)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _items.isEmpty
                        ? null
                        : () async {
                            final info =
                                await _askCustomerInfo(context);
                            if (info == null) return;

                            String? orderId;
                            try {
                              orderId =
                                  await _sendOrderToFirestore(
                                context,
                                customerName: info['name']!,
                                customerPhone: info['phone']!,
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Erreur lors de l\'envoi de la commande : $e',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (orderId == null) return;

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderStatusScreen(
                                  orderId: orderId!,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Valider la commande',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- ÉCRAN STATUT DE COMMANDE (SYNC FIRESTORE) ----------

enum OrderStage { received, preparing, ready }

class OrderStatusScreen extends StatelessWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  OrderStage _stageFromStatus(String status) {
    switch (status) {
      case 'received':
        return OrderStage.received;
      case 'preparing':
        return OrderStage.preparing;
      case 'ready':
        return OrderStage.ready;
      default:
        return OrderStage.received;
    }
  }

  String _headerMessage(String status) {
    switch (status) {
      case 'received':
        return 'Commande envoyée.\nEn attente de validation du restaurant.';
      case 'preparing':
        return 'Commande acceptée !\nLe restaurant prépare votre commande.';
      case 'ready':
        return 'Commande prête !\nVous pouvez venir la récupérer.';
      default:
        return 'Votre commande est en cours de traitement.';
    }
  }

  Color _colorForStage(OrderStage currentStage, OrderStage stage) {
    if (currentStage.index > stage.index) {
      return Colors.green;
    } else if (currentStage == stage) {
      return Colors.deepOrange;
    } else {
      return Colors.grey;
    }
  }

  IconData _iconForStage(OrderStage currentStage, OrderStage stage) {
    if (currentStage.index >= stage.index) {
      return Icons.check_circle;
    }
    return Icons.radio_button_unchecked;
  }

  String _labelForStage(OrderStage stage) {
    switch (stage) {
      case OrderStage.received:
        return 'Commande envoyée';
      case OrderStage.preparing:
        return 'Commande acceptée / en préparation';
      case OrderStage.ready:
        return 'Commande prête';
    }
  }

  @override
  Widget build(BuildContext context) {
    final docStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statut de la commande'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erreur de chargement du statut.',
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.data()!;
          final status = (data['status'] as String?) ?? 'received';
          final currentStage = _stageFromStatus(status);
          final stages = OrderStage.values;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  _headerMessage(status),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children:
                        List.generate(stages.length * 2 - 1, (index) {
                      if (index.isOdd) {
                        final previousStage =
                            stages[(index - 1) ~/ 2];
                        final isCompleted = currentStage.index >
                            previousStage.index;
                        return Container(
                          width: 2,
                          height: 40,
                          color: isCompleted
                              ? Colors.green
                              : Colors.grey.shade300,
                        );
                      } else {
                        final stage = stages[index ~/ 2];
                        final color =
                            _colorForStage(currentStage, stage);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              _iconForStage(currentStage, stage),
                              color: color,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _labelForStage(stage),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                if (currentStage == OrderStage.ready)
                  const Text(
                    'Votre commande est prête !',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 32,
                    ),
                  ),
                  child: const Text(
                    'Retour au menu',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
