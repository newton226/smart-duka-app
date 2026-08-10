import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HardwareStoreApp());
}

class HardwareStoreApp extends StatelessWidget {
  const HardwareStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Duka POS',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isFirstTime = true;
  String _savedName = '';
  String _savedPin = '';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<File> _getFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  Future<void> _checkAuthStatus() async {
    try {
      final userFile = await _getFile('smart_duka_user.json');
      if (await userFile.exists()) {
        final content = await userFile.readAsString();
        final data = jsonDecode(content);
        setState(() {
          _savedName = data['name'] ?? '';
          _savedPin = data['pin'] ?? '';
          _isFirstTime = _savedPin.isEmpty;
        });
      }
    } catch (e) {
      debugPrint("Error checking auth status: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSetupComplete(String name, String pin) async {
    try {
      final userFile = await _getFile('smart_duka_user.json');
      await userFile.writeAsString(jsonEncode({'name': name, 'pin': pin}));
      setState(() {
        _savedName = name;
        _savedPin = pin;
        _isFirstTime = false;
      });
    } catch (e) {
      debugPrint("Error saving user profile: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isFirstTime) {
      return SetupScreen(onComplete: _onSetupComplete);
    }

    return LoginScreen(
      userName: _savedName,
      correctPin: _savedPin,
      onSuccess: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(userName: _savedName),
          ),
        );
      },
    );
  }
}

class SetupScreen extends StatefulWidget {
  final Function(String name, String pin) onComplete;

  const SetupScreen({super.key, required this.onComplete});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String? _errorMessage;

  void _submit() {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (name.isEmpty || pin.isEmpty || confirmPin.isEmpty) {
      setState(() {
        _errorMessage = "Tafadhali jaza nafasi zote!";
      });
      return;
    }

    if (pin.length < 4) {
      setState(() {
        _errorMessage = "PIN lazima iwe na angalau tarakimu 4!";
      });
      return;
    }

    if (pin != confirmPin) {
      setState(() {
        _errorMessage = "PIN hazifanani!";
      });
      return;
    }

    widget.onComplete(name, pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storefront, size: 70, color: Colors.indigo),
                  const SizedBox(height: 15),
                  const Text(
                    "Seti Akaunti ya Mwenye Duka",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tengeneza PIN itakayolinda mfumo wako wa duka.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Jina Lako / Jina la Mwenye Duka',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tengeneza PIN (Tarakimu 4+)',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _confirmPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thibitisha PIN (Confirm PIN)',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _submit,
                      child: const Text("HIFADHI & ANZA MFUMO",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
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

class LoginScreen extends StatefulWidget {
  final String userName;
  final String correctPin;
  final VoidCallback onSuccess;

  const LoginScreen({
    super.key,
    required this.userName,
    required this.correctPin,
    required this.onSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  String? _errorMsg;

  void _verifyPin() {
    if (_pinController.text.trim() == widget.correctPin) {
      widget.onSuccess();
    } else {
      setState(() {
        _errorMsg = "PIN sio sahihi! Jaribu tena.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_person, size: 80, color: Colors.indigo),
                  const SizedBox(height: 15),
                  Text(
                    "Welcome, ${widget.userName}!",
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo),
                  ),
                  const SizedBox(height: 5),
                  const Text("Ingiza PIN yako ili kufungua mfumo"),
                  const SizedBox(height: 25),
                  if (_errorMsg != null) ...[
                    Text(_errorMsg!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: 250,
                    child: TextField(
                      controller: _pinController,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 22, letterSpacing: 8),
                      decoration: const InputDecoration(
                        hintText: 'PIN',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _verifyPin(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12),
                    ),
                    onPressed: _verifyPin,
                    child: const Text("INGIA DUKANI",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final String userName;

  const MainNavigationScreen({super.key, required this.userName});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _salesLog = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataFromDisk();
  }

  Future<File> _getFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  Future<void> _loadDataFromDisk() async {
    try {
      final productsFile = await _getFile('smart_duka_products.json');
      final salesFile = await _getFile('smart_duka_sales.json');

      if (await productsFile.exists()) {
        final String productsContent = await productsFile.readAsString();
        final List<dynamic> decoded = jsonDecode(productsContent);
        _allProducts = decoded.map((e) {
          final map = Map<String, dynamic>.from(e);
          if (map['image'] != null) {
            map['image'] = base64Decode(map['image']);
          }
          return map;
        }).toList();
      }

      if (await salesFile.exists()) {
        final String salesContent = await salesFile.readAsString();
        final List<dynamic> decoded = jsonDecode(salesContent);
        _salesLog = decoded.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['date'] = DateTime.parse(map['date']);
          return map;
        }).toList();
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDataToDisk() async {
    try {
      final productsFile = await _getFile('smart_duka_products.json');
      final salesFile = await _getFile('smart_duka_sales.json');

      final productsToSave = _allProducts.map((p) {
        final map = Map<String, dynamic>.from(p);
        if (map['image'] != null) {
          map['image'] = base64Encode(map['image'] as Uint8List);
        }
        return map;
      }).toList();

      final salesToSave = _salesLog.map((s) {
        final map = Map<String, dynamic>.from(s);
        map['date'] = (map['date'] as DateTime).toIso8601String();
        return map;
      }).toList();

      await productsFile.writeAsString(jsonEncode(productsToSave));
      await salesFile.writeAsString(jsonEncode(salesToSave));
    } catch (e) {
      debugPrint("Error saving data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = [
      DashboardScreen(
        userName: widget.userName,
        products: _allProducts,
        salesLog: _salesLog,
        onDataChanged: () {
          _saveDataToDisk();
          setState(() {});
        },
      ),
      SalesReportScreen(salesLog: _salesLog),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store), label: 'Stoki & Duka'),
          NavigationDestination(
              icon: Icon(Icons.analytics), label: 'Mauzo & Ripoti'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> salesLog;
  final VoidCallback onDataChanged;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.products,
    required this.salesLog,
    required this.onDataChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredProducts = widget.products;
      } else {
        final q = query.toLowerCase();
        _filteredProducts = widget.products.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          final kw = (p['keywords'] ?? '').toString().toLowerCase();
          return name.contains(q) || kw.contains(q);
        }).toList();
      }
    });
  }

  void _showImagePreview(Uint8List imageBytes, String productName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(productName, style: const TextStyle(fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  height: 300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductModal(Map<String, dynamic> product) {
    final nameCtrl = TextEditingController(text: product['name']);
    final kwCtrl = TextEditingController(text: product['keywords'] ?? '');
    final sellCtrl =
        TextEditingController(text: product['sell_price'].toString());
    final stockCtrl = TextEditingController(text: product['stock'].toString());
    final locCtrl = TextEditingController(text: product['location'] ?? '');
    Uint8List? selectedImageBytes = product['image'] as Uint8List?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Badili Taarifa / Bei ya Bidhaa",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Center(
                  child: GestureDetectingAvatar(
                    imageBytes: selectedImageBytes,
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setModalState(() {
                          selectedImageBytes = bytes;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Jina la Bidhaa',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: kwCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Keywords / Aliases',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: sellCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Bei ya Kuuza (Tsh)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Stoki Iliyopo',
                                border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: locCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Shelfi / Eneo',
                                border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      if (nameCtrl.text.isNotEmpty &&
                          sellCtrl.text.isNotEmpty) {
                        setState(() {
                          product['name'] = nameCtrl.text;
                          product['keywords'] = kwCtrl.text;
                          product['sell_price'] =
                              double.tryParse(sellCtrl.text) ?? 0.0;
                          product['stock'] = int.tryParse(stockCtrl.text) ?? 0;
                          product['location'] = locCtrl.text;
                          product['image'] = selectedImageBytes;
                          _filterProducts(_searchController.text);
                        });
                        widget.onDataChanged();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("✅ Taarifa za bidhaa zimebadilishwa!"),
                              backgroundColor: Colors.green),
                        );
                      }
                    },
                    child: const Text("HIFADHI MABADILIKO",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteProduct(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Thibitisha Kufuta"),
        content: Text(
            "Je, una uhakika unataka kufuta bidhaa ya '${product['name']}' kwenye mfumo?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Kughairi")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                widget.products
                    .removeWhere((item) => item['id'] == product['id']);
                _filterProducts(_searchController.text);
              });
              widget.onDataChanged();
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("🗑️ Bidhaa imefutwa kikamilifu!"),
                    backgroundColor: Colors.red),
              );
            },
            child: const Text("FUTA BIDHAA"),
          ),
        ],
      ),
    );
  }

  void _showAddProductModal() {
    final nameCtrl = TextEditingController();
    final kwCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    Uint8List? selectedImageBytes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ongeza Bidhaa Mpya",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Center(
                  child: GestureDetectingAvatar(
                    imageBytes: selectedImageBytes,
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setModalState(() {
                          selectedImageBytes = bytes;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Jina la Bidhaa',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: kwCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Keywords / Aliases',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: sellCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Bei ya Kuuza (Tsh)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Stoki ya Mwanzo',
                                border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: locCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Shelfi / Eneo',
                                border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      if (nameCtrl.text.isNotEmpty &&
                          sellCtrl.text.isNotEmpty) {
                        final newProduct = {
                          'id': DateTime.now().millisecondsSinceEpoch,
                          'name': nameCtrl.text,
                          'keywords': kwCtrl.text,
                          'sell_price': double.tryParse(sellCtrl.text) ?? 0.0,
                          'stock': int.tryParse(stockCtrl.text) ?? 0,
                          'location': locCtrl.text,
                          'image': selectedImageBytes,
                        };

                        setState(() {
                          widget.products.insert(0, newProduct);
                          _filterProducts(_searchController.text);
                        });
                        widget.onDataChanged();
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text("HIFADHI BIDHAA",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddStockDialog(Map<String, dynamic> product) {
    final addStockCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text("Ongeza Stoki: ${product['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Stoki ya sasa: ${product['stock']}"),
            const SizedBox(height: 10),
            TextField(
              controller: addStockCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Idadi Mpya Inayoingia',
                  border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Kughairi")),
          ElevatedButton(
            onPressed: () {
              int qty = int.tryParse(addStockCtrl.text) ?? 0;
              if (qty > 0) {
                setState(() {
                  product['stock'] += qty;
                });
                widget.onDataChanged();
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ Stoki imeongezeka kwa $qty!")),
                );
              }
            },
            child: const Text("Ongeza Stoki"),
          )
        ],
      ),
    );
  }

  void _showSaleDialog(Map<String, dynamic> product) {
    final qtyCtrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text("Uza: ${product['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Bei kwa Moja: Tsh ${product['sell_price']}"),
            Text("Stoki Iliyopo: ${product['stock']}"),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Idadi anayonunua mteja',
                  border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Kughairi")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              int qty = int.tryParse(qtyCtrl.text) ?? 1;
              if (qty <= product['stock']) {
                setState(() {
                  product['stock'] -= qty;
                  widget.salesLog.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'product_name': product['name'],
                    'qty': qty,
                    'unit_price': product['sell_price'],
                    'total': product['sell_price'] * qty,
                    'date': DateTime.now(),
                  });
                });
                widget.onDataChanged();
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("✅ Mauzo Yamekamilika!"),
                      backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("⚠️ Idadi inazidi Stoki iliyopo!"),
                      backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text("Kamilisha Mauzo"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Karibu, ${widget.userName} 👋",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text("Stoki na Bidhaa (${widget.products.length})",
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
            onPressed: _showAddProductModal,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterProducts,
              decoration: InputDecoration(
                hintText: 'Tafuta miongoni mwa bidhaa...',
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text("Hakuna bidhaa zilizopatikana."))
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemExtent: 72.0,
                    itemBuilder: (context, index) {
                      final p = _filteredProducts[index];
                      final bool isLowStock = (p['stock'] ?? 0) <= 5;
                      final imageBytes = p['image'] as Uint8List?;

                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              if (imageBytes != null) {
                                _showImagePreview(imageBytes, p['name']);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageBytes != null
                                  ? Image.memory(imageBytes,
                                      width: 45, height: 45, fit: BoxFit.cover)
                                  : Container(
                                      width: 45,
                                      height: 45,
                                      color: Colors.indigo.shade50,
                                      child: const Icon(Icons.inventory_2,
                                          color: Colors.indigo),
                                    ),
                            ),
                          ),
                          title: Text(p['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              "Bei: Tsh ${p['sell_price']} | Shelfi: ${p['location']}",
                              style: const TextStyle(fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Stoki: ${p['stock']}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isLowStock
                                              ? Colors.red
                                              : Colors.green)),
                                  InkWell(
                                    onTap: () => _showAddStockDialog(p),
                                    child: const Icon(Icons.add_box,
                                        color: Colors.indigo, size: 20),
                                  )
                                ],
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.orange, size: 20),
                                tooltip: 'Badili Bei / Taarifa',
                                onPressed: () => _showEditProductModal(p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                tooltip: 'Futa Bidhaa',
                                onPressed: () => _confirmDeleteProduct(p),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10)),
                                onPressed: () => _showSaleDialog(p),
                                child: const Text("Uza",
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class GestureDetectingAvatar extends StatelessWidget {
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  const GestureDetectingAvatar(
      {super.key, required this.imageBytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.indigo.shade100,
        backgroundImage: imageBytes != null ? MemoryImage(imageBytes!) : null,
        child: imageBytes == null
            ? const Icon(Icons.add_a_photo, size: 30, color: Colors.indigo)
            : null,
      ),
    );
  }
}

class SalesReportScreen extends StatelessWidget {
  final List<Map<String, dynamic>> salesLog;

  const SalesReportScreen({super.key, required this.salesLog});

  double _getTodaySales() {
    final now = DateTime.now();
    return salesLog.where((s) {
      final date = s['date'] as DateTime;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).fold(0.0, (sum, item) => sum + (item['total'] as double));
  }

  double _getMonthSales() {
    final now = DateTime.now();
    return salesLog.where((s) {
      final date = s['date'] as DateTime;
      return date.year == now.year && date.month == now.month;
    }).fold(0.0, (sum, item) => sum + (item['total'] as double));
  }

  void _shareDailyReport(BuildContext context) async {
    final pdf = pw.Document();
    final todaySales = salesLog.where((s) {
      final date = s['date'] as DateTime;
      final now = DateTime.now();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text("SMART DUKA - RIPOTI YA MAUZO YA SIKU",
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Tarehe: ${DateTime.now().toString().split(' ')[0]}"),
              pw.Text("Jumla ya Mauzo ya Leo: Tsh ${_getTodaySales()}"),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Muda', 'Bidhaa', 'Idadi', 'Bei @', 'Jumla'],
                data: todaySales.map((s) {
                  final dt = s['date'] as DateTime;
                  return [
                    "${dt.hour}:${dt.minute}",
                    s['product_name'],
                    "${s['qty']}",
                    "Tsh ${s['unit_price']}",
                    "Tsh ${s['total']}"
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Ripoti_ya_Mauzo_${DateTime.now().day}_${DateTime.now().month}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mauzo & Ripoti",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.indigo.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text("Mauzo ya Leo",
                              style: TextStyle(
                                  fontSize: 14, color: Colors.indigo)),
                          const SizedBox(height: 5),
                          Text("Tsh ${_getTodaySales()}",
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text("Mauzo ya Mwezi",
                              style:
                                  TextStyle(fontSize: 14, color: Colors.green)),
                          const SizedBox(height: 5),
                          Text("Tsh ${_getMonthSales()}",
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("HIFADHI / PRINT RIPOTI YA LEO",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _shareDailyReport(context),
              ),
            ),
            const SizedBox(height: 15),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Historia ya Mauzo:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: salesLog.isEmpty
                  ? const Center(
                      child: Text("Bado hakuna mauzo yaliyofanyika."))
                  : ListView.builder(
                      itemCount: salesLog.length,
                      itemBuilder: (context, index) {
                        final s = salesLog[index];
                        final date = s['date'] as DateTime;
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child:
                                  Icon(Icons.attach_money, color: Colors.white),
                            ),
                            title: Text(s['product_name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                "Idadi: ${s['qty']} | Muda: ${date.hour}:${date.minute}"),
                            trailing: Text("Tsh ${s['total']}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 15)),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }
}
