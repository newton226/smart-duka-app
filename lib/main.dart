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
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

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

  // Kupata eneo rasmi la Hifadhi la PC/Simu
  Future<File> _getFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  // Kupakia Data zilizohifadhiwa kwenye Disk
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

  // Kuhifadhi Data Moja kwa Moja kwenye Hard Drive/Storage
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
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> salesLog;
  final VoidCallback onDataChanged;

  const DashboardScreen({
    super.key,
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
        title: Text("Smart Hardware POS (${widget.products.length})",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
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
                              const SizedBox(width: 8),
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
