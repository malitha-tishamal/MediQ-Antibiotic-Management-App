// main_store_screen.dart – Final version with PDF certificate, charts, and fixed button
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Required for RenderRepaintBoundary
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF8F9FF);
  static const Color darkText = Color(0xFF2D3748);
  static const Color successGreen = Color(0xFF48BB78);
  static const Color warningOrange = Color(0xFFED8936);
  static const Color disabledColor = Color(0xFFF56565);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF2D3748);
  static const Color chipBackground = Color(0xFFEDF2F7);
  static const Color inputBorder = Color(0xFFE0E0E0);
}

class MainStoreScreen extends StatefulWidget {
  const MainStoreScreen({super.key});

  @override
  State<MainStoreScreen> createState() => _MainStoreScreenState();
}

class _MainStoreScreenState extends State<MainStoreScreen>
    with SingleTickerProviderStateMixin {
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final CollectionReference _stockCollection =
      FirebaseFirestore.instance.collection('main_stock');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchNotifier = ValueNotifier<String>('');

  final Map<String, TextEditingController> _quantityControllers = {};

  late TabController _tabController;

  // Analytics tab filters & sort
  final ValueNotifier<String> _filterStatus = ValueNotifier<String>('All');
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final TextEditingController _analyticsSearchController =
      TextEditingController();

  // Table sorting – using ValueNotifier to avoid full page rebuild
  final ValueNotifier<int> _sortColumnIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> _sortAscending = ValueNotifier<bool>(true);

  // PDF generation state
  bool _isGeneratingPdf = false;

  // Global keys to capture chart widgets for PDF
  final GlobalKey _pieChartKey = GlobalKey();
  final GlobalKey _barChartKey = GlobalKey();

  // ──────────────────────────────────────────────────────────────────
  // Safe directory getter – catches any exception and falls back
  // ──────────────────────────────────────────────────────────────────
  Future<Directory> _getWritableDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (e) {
      try {
        return await getApplicationDocumentsDirectory();
      } catch (_) {
        return Directory.current;
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Helper to capture a widget as image bytes
  // ──────────────────────────────────────────────────────────────────
  Future<ui.Image?> _captureWidget(GlobalKey key) async {
    try {
      final RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      return image;
    } catch (e) {
      debugPrint('Error capturing widget: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCurrentUserDetails();
    _searchController.addListener(() {
      _searchNotifier.value = _searchController.text;
    });
    _analyticsSearchController.addListener(() {
      _searchQuery.value = _analyticsSearchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchNotifier.dispose();
    _analyticsSearchController.dispose();
    _filterStatus.dispose();
    _searchQuery.dispose();
    _sortColumnIndex.dispose();
    _sortAscending.dispose();
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName =
                data['fullName'] ?? user.email?.split('@').first ?? 'User';
            _profileImageUrl = data['profileImageUrl'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching user: $e');
      }
    }
  }

  String _itemKey(String antibioticId, int dosageIndex) {
    return '${antibioticId}_$dosageIndex';
  }

  TextEditingController _getController(String key) {
    if (!_quantityControllers.containsKey(key)) {
      _quantityControllers[key] = TextEditingController();
    }
    return _quantityControllers[key]!;
  }

  // ──────────────────────────────────────────────────────────────────
  // PDF CERTIFICATE GENERATION (with charts)
  // ──────────────────────────────────────────────────────────────────
  Future<void> _generateCertificatePdf(
      List<Map<String, dynamic>> allItems) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMMM yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);

      // --- Safely compute summary stats ---
      int inStock = 0, lowStock = 0, outOfStock = 0;
      int totalQty = 0;
      for (var item in allItems) {
        int qty = 0;
        final qtyDynamic = item['quantity'];
        if (qtyDynamic is int) {
          qty = qtyDynamic;
        } else if (qtyDynamic is String) {
          qty = int.tryParse(qtyDynamic) ?? 0;
        } else if (qtyDynamic is num) {
          qty = qtyDynamic.toInt();
        }
        totalQty += qty;
        if (qty == 0) outOfStock++;
        else if (qty < 50) lowStock++;
        else inStock++;
      }

      final sorted = List<Map<String, dynamic>>.from(allItems)
        ..sort((a, b) =>
            (a['drugName'] ?? '').compareTo(b['drugName'] ?? ''));

      final pdf = pw.Document();

      const pdfPurple = PdfColor.fromInt(0xFF9F7AEA);
      const pdfGreen = PdfColor.fromInt(0xFF48BB78);
      const pdfOrange = PdfColor.fromInt(0xFFED8936);
      const pdfRed = PdfColor.fromInt(0xFFF56565);
      const pdfDark = PdfColor.fromInt(0xFF2D3748);
      const pdfLightBg = PdfColor.fromInt(0xFFF8F9FF);
      const pdfPurpleLight = PdfColor.fromInt(0xFFEDE9FF);

      // ── PAGE 1: Certificate Cover ──
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: pdfLightBg,
                ),
                pw.Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: pw.Container(
                    height: 160,
                    decoration: const pw.BoxDecoration(
                      gradient: pw.LinearGradient(
                        colors: [
                          PdfColor.fromInt(0xFF9F7AEA),
                          PdfColor.fromInt(0xFFB794F4),
                        ],
                        begin: pw.Alignment.topLeft,
                        end: pw.Alignment.bottomRight,
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'MAIN STORE',
                            style: pw.TextStyle(
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Stock Inventory Certificate',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                pw.Positioned(
                  top: 180,
                  left: 40,
                  right: 40,
                  bottom: 40,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Certificate No: CERT-${now.millisecondsSinceEpoch.toString().substring(7)}',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey600),
                          ),
                          pw.Text(
                            'Generated: $dateStr at $timeStr',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 20),
                      pw.Container(
                          height: 2,
                          color: pdfPurple,
                          margin:
                              const pw.EdgeInsets.symmetric(vertical: 4)),
                      pw.SizedBox(height: 16),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(20),
                        decoration: pw.BoxDecoration(
                          color: pdfPurpleLight,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(12)),
                          border: pw.Border.all(color: pdfPurple, width: 1),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'THIS IS TO CERTIFY THAT',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: pdfPurple,
                              ),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Text(
                              'The following Main Store stock inventory report has been generated and verified by the system administrator.',
                              style: const pw.TextStyle(
                                  fontSize: 11, color: pdfDark),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'All data is accurate as of $dateStr.',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: pdfDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 24),
                      pw.Text(
                        'INVENTORY SUMMARY',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfDark,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        children: [
                          _pdfStatBox('Total Items', allItems.length.toString(),
                              pdfPurple),
                          pw.SizedBox(width: 10),
                          _pdfStatBox(
                              'Total Qty', totalQty.toString(), pdfGreen),
                          pw.SizedBox(width: 10),
                          _pdfStatBox('In Stock', inStock.toString(), pdfGreen),
                          pw.SizedBox(width: 10),
                          _pdfStatBox(
                              'Low Stock', lowStock.toString(), pdfOrange),
                          pw.SizedBox(width: 10),
                          _pdfStatBox(
                              'Out of Stock', outOfStock.toString(), pdfRed),
                        ],
                      ),
                      pw.SizedBox(height: 32),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('PREPARED BY',
                                    style: pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.grey600,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 30),
                                pw.Container(
                                    height: 1,
                                    color: pdfDark,
                                    margin: const pw.EdgeInsets.only(
                                        right: 20)),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  _currentUserName,
                                  style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      color: pdfDark),
                                ),
                                pw.Text('Administrator',
                                    style: const pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.grey600)),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('APPROVED BY',
                                    style: pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.grey600,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 30),
                                pw.Container(
                                    height: 1,
                                    color: pdfDark,
                                    margin: const pw.EdgeInsets.only(
                                        right: 20)),
                                pw.SizedBox(height: 4),
                                pw.Text('Name & Signature',
                                    style: const pw.TextStyle(
                                        fontSize: 10,
                                        color: PdfColors.grey500)),
                                pw.Text('Designation',
                                    style: const pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.grey500)),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('DATE',
                                    style: pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.grey600,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 30),
                                pw.Container(
                                    height: 1,
                                    color: pdfDark,
                                    margin: const pw.EdgeInsets.only(
                                        right: 20)),
                                pw.SizedBox(height: 4),
                                pw.Text(dateStr,
                                    style: pw.TextStyle(
                                        fontSize: 10,
                                        color: pdfDark,
                                        fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.Spacer(),
                      pw.Container(height: 1, color: pdfPurple),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Main Store Management System',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey500)),
                          pw.Text('Page 1 of 3',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey500)),
                          pw.Text('CONFIDENTIAL',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: pdfPurple,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // ── PAGE 2: Analytics Charts ──
      // Capture chart widgets
      final ui.Image? pieImage = await _captureWidget(_pieChartKey);
      final ui.Image? barImage = await _captureWidget(_barChartKey);

      // Convert images to bytes before building the PDF page (synchronous)
      Uint8List? pieImageBytes;
      Uint8List? barImageBytes;
      if (pieImage != null) {
        final byteData = await pieImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          pieImageBytes = byteData.buffer.asUint8List();
        }
      }
      if (barImage != null) {
        final byteData = await barImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          barImageBytes = byteData.buffer.asUint8List();
        }
      }

      if (pieImageBytes != null || barImageBytes != null) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Stock Analytics',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: pdfPurple),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Pie chart: Stock health distribution',
                    style: const pw.TextStyle(fontSize: 12, color: pdfDark),
                  ),
                  pw.SizedBox(height: 12),
                  if (pieImageBytes != null)
                    pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(pieImageBytes!),
                        width: 350,
                        height: 250,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Bar chart: Top 10 drugs by quantity',
                    style: const pw.TextStyle(fontSize: 12, color: pdfDark),
                  ),
                  pw.SizedBox(height: 12),
                  if (barImageBytes != null)
                    pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(barImageBytes!),
                        width: 350,
                        height: 250,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  pw.Spacer(),
                  pw.Container(height: 1, color: pdfPurple),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Main Store Management System',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey500)),
                      pw.Text('Page 2 of 3',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey500)),
                      pw.Text('CONFIDENTIAL',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: pdfPurple,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      // ── PAGE 3+: Full Stock Table ──
      const int rowsPerPage = 25;
      final chunks = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < sorted.length; i += rowsPerPage) {
        chunks.add(sorted.sublist(
            i, i + rowsPerPage > sorted.length ? sorted.length : i + rowsPerPage));
      }

      int tablePageNum = (pieImageBytes != null || barImageBytes != null) ? 3 : 2;
      final totalTablePages = chunks.length;
      final totalPages = tablePageNum + totalTablePages - 1;

      for (int pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
        final chunk = chunks[pageIdx];
        final currentPage = tablePageNum + pageIdx;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Stock Inventory Detail',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfPurple),
                      ),
                      pw.Text(
                        dateStr,
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Container(
                      height: 2, color: pdfPurple, margin: const pw.EdgeInsets.symmetric(vertical: 8)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(1.2),
                      4: const pw.FlexColumnWidth(1.5),
                      5: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: pdfPurple),
                        children: [
                          _pdfTableHeader('Drug Name'),
                          _pdfTableHeader('Dosage'),
                          _pdfTableHeader('SR Number'),
                          _pdfTableHeader('Qty'),
                          _pdfTableHeader('Status'),
                          _pdfTableHeader('Last Updated'),
                        ],
                      ),
                      ...chunk.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final qty = item['quantity'] as int;
                        final lastUpdated =
                            item['lastUpdated'] as Timestamp?;
                        final dateFormatted = lastUpdated != null
                            ? DateFormat('dd MMM yyyy')
                                .format(lastUpdated.toDate())
                            : 'Never';

                        String status;
                        PdfColor statusColor;
                        if (qty == 0) {
                          status = 'Out of Stock';
                          statusColor = pdfRed;
                        } else if (qty < 50) {
                          status = 'Low Stock';
                          statusColor = pdfOrange;
                        } else {
                          status = 'In Stock';
                          statusColor = pdfGreen;
                        }

                        final bgColor = idx.isEven
                            ? PdfColors.white
                            : const PdfColor.fromInt(0xFFF9F7FF);

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: bgColor),
                          children: [
                            _pdfTableCell(item['drugName'] ?? '',
                                bold: true),
                            _pdfTableCell(item['dosage'] ?? ''),
                            _pdfTableCell(item['srNumber'] ?? ''),
                            _pdfTableCell(qty.toString()),
                            _pdfStatusCell(status, statusColor),
                            _pdfTableCell(dateFormatted),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Container(height: 1, color: pdfPurple),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Prepared by: $_currentUserName  |  Administrator',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.Text('Page $currentPage of $totalPages',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey500)),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      // Save & share
      final bytes = await pdf.save();
      final directory = await _getWritableDirectory();
      final fileName =
          'MainStore_Certificate_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      setState(() => _isGeneratingPdf = false);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Main Store Inventory Certificate – $dateStr',
      );
      file.delete();
    } catch (e) {
      setState(() => _isGeneratingPdf = false);
      _showSnackBar('PDF generation failed: $e', false);
    }
  }

  // ── PDF helper widgets ──
  pw.Widget _pdfStatBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: PdfColor(color.red, color.green, color.blue, 0.08),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(
            color: PdfColor(color.red, color.green, color.blue, 0.4),
            width: 0.8,
          ),
        ),
        child: pw.Column(
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _pdfTableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: const PdfColor.fromInt(0xFF2D3748),
        ),
      ),
    );
  }

  pw.Widget _pdfStatusCell(String status, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: pw.BoxDecoration(
          color: PdfColor(color.red, color.green, color.blue, 0.12),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          status,
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // CSV EXPORT
  // ──────────────────────────────────────────────────────────────────
  Future<void> _exportToCSV() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating CSV...'),
          ],
        ),
      ),
    );

    try {
      final snapshot = await _stockCollection
          .orderBy('lastUpdated', descending: true)
          .get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        Navigator.pop(context);
        _showSnackBar('No data to export', false);
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add([
        'SR Number',
        'Drug Name',
        'Dosage',
        'Quantity',
        'Last Updated',
        'Document ID',
      ]);

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        rows.add([
          data['srNumber'] ?? '',
          data['drugName'] ?? '',
          data['dosage'] ?? '',
          data['quantity'] ?? 0,
          data['lastUpdated'] != null
              ? DateFormat('yyyy-MM-dd HH:mm')
                  .format((data['lastUpdated'] as Timestamp).toDate())
              : '',
          doc.id,
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await _getWritableDirectory();
      final file = File(
          '${directory.path}/main_store_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Main Store Stock Export');
      file.delete();
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Export failed: $e', false);
    }
  }

  void _showSnackBar(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor:
            isSuccess ? AppColors.successGreen : AppColors.disabledColor,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateQuantity(String stockId, int newQuantity) async {
    try {
      await _stockCollection.doc(stockId).update({
        'quantity': newQuantity,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Quantity updated', true);
    } catch (e) {
      _showSnackBar('Update failed: $e', false);
    }
  }

  Future<void> _addQuantity(
      String stockId, int currentQuantity, int addAmount) async {
    try {
      await _stockCollection.doc(stockId).update({
        'quantity': currentQuantity + addAmount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Increased by $addAmount', true);
    } catch (e) {
      _showSnackBar('Add failed: $e', false);
    }
  }

  Future<void> _createStockEntry({
    required String antibioticId,
    required int dosageIndex,
    required String srNumber,
    required String drugName,
    required String dosage,
    required int initialQuantity,
  }) async {
    try {
      await _stockCollection.add({
        'antibioticId': antibioticId,
        'dosageIndex': dosageIndex,
        'srNumber': srNumber,
        'drugName': drugName,
        'dosage': dosage,
        'quantity': initialQuantity,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Stock entry created', true);
    } catch (e) {
      _showSnackBar('Creation failed: $e', false);
    }
  }

  void _showDrugsByStatus(
      List<Map<String, dynamic>> allItems, String status, Color statusColor) {
    final filtered = allItems.where((item) {
      final qty = item['quantity'] as int;
      if (status == 'In Stock') return qty >= 50;
      if (status == 'Low Stock') return qty > 0 && qty < 50;
      if (status == 'Out of Stock') return qty == 0;
      return false;
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(status,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${filtered.length} items',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No $status drugs found.',
                            style: TextStyle(color: Colors.grey[600])),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, index) {
                          final item = filtered[index];
                          final qty = item['quantity'] as int;
                          final drugName = item['drugName'] ?? 'Unknown';
                          final dosage = item['dosage'] ?? '';
                          final srNumber = item['srNumber'] ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.1),
                              child: Icon(
                                status == 'In Stock'
                                    ? Icons.check
                                    : status == 'Low Stock'
                                        ? Icons.warning
                                        : Icons.cancel,
                                color: statusColor,
                              ),
                            ),
                            title: Text(drugName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle:
                                Text('Dosage: $dosage | SR: $srNumber'),
                            trailing: Text('Qty: $qty',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Header ----------
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.headerGradientStart,
            AppColors.headerGradientEnd
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.headerTextDark, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentUserName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Administrator',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.headerTextDark),
                  ),
                ],
              ),
              const Spacer(),
              _buildProfileAvatar(),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Manage Main Store',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryPurple,
            labelColor: AppColors.primaryPurple,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Stock Management', icon: Icon(Icons.inventory)),
              Tab(text: 'Analytics', icon: Icon(Icons.bar_chart)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_profileImageUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) {
          if (mounted) setState(() => _profileImageUrl = null);
        },
      );
    } else {
      return CircleAvatar(
        radius: 40,
        backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
        child: const Icon(Icons.person,
            color: AppColors.primaryPurple, size: 48),
      );
    }
  }

  // ---------- Stock Management Tab ----------
  Widget _buildStockManagementTab(List<Map<String, dynamic>> allItems) {
    return Column(
      children: [
        _buildSummaryCard(allItems),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchController,
            decoration: _inputDecoration(
              label: 'Search',
              hintText: 'Drug name or SR number...',
              prefixIcon: Icons.search,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: _searchNotifier,
            builder: (context, searchQuery, _) {
              final filteredItems = allItems.where((item) {
                if (searchQuery.isEmpty) return true;
                final name = (item['drugName'] as String).toLowerCase();
                final sr = (item['srNumber'] as String).toLowerCase();
                return name.contains(searchQuery) ||
                    sr.contains(searchQuery);
              }).toList();

              if (filteredItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('No items found.',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                key: const PageStorageKey('main_store_list'),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final srNumber = item['srNumber'];
                  final drugName = item['drugName'];
                  final dosage = item['dosage'];
                  final quantity = item['quantity'] as int;
                  final stockId = item['stockId'];
                  final key = item['key'];
                  final lastUpdated = item['lastUpdated'] as Timestamp?;

                  Color statusColor;
                  String statusText;
                  if (quantity == 0) {
                    statusColor = AppColors.disabledColor;
                    statusText = 'Out';
                  } else if (quantity < 50) {
                    statusColor = AppColors.warningOrange;
                    statusText = 'Low';
                  } else {
                    statusColor = AppColors.successGreen;
                    statusText = 'In';
                  }

                  return _buildStockItemCard(
                    item: item,
                    srNumber: srNumber,
                    drugName: drugName,
                    dosage: dosage,
                    quantity: quantity,
                    stockId: stockId,
                    key: key,
                    statusColor: statusColor,
                    statusText: statusText,
                    lastUpdated: lastUpdated,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------- Analytics Tab (with RepaintBoundary for charts) ----------
  Widget _buildAnalyticsTab(List<Map<String, dynamic>> allItems) {
    int inStock = 0, lowStock = 0, outOfStock = 0;
    Map<String, int> drugQuantityMap = {};

    for (var item in allItems) {
      final qty = item['quantity'] as int;
      final drug = item['drugName'] ?? 'Unknown';
      if (qty == 0) outOfStock++;
      else if (qty < 50) lowStock++;
      else inStock++;

      drugQuantityMap[drug] = (drugQuantityMap[drug] ?? 0) + qty;
    }

    final sortedDrugs = drugQuantityMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDrugs = sortedDrugs.take(10).toList();

    int totalItems = allItems.length;
    int totalQuantity =
        allItems.fold(0, (sum, item) => sum + (item['quantity'] as int));

    final List<_PieSection> pieSections = [];
    if (inStock > 0)
      pieSections.add(
          _PieSection(inStock.toDouble(), AppColors.successGreen, 'In Stock'));
    if (lowStock > 0)
      pieSections.add(_PieSection(
          lowStock.toDouble(), AppColors.warningOrange, 'Low Stock'));
    if (outOfStock > 0)
      pieSections.add(_PieSection(
          outOfStock.toDouble(), AppColors.disabledColor, 'Out of Stock'));
    if (pieSections.isEmpty)
      pieSections.add(_PieSection(1.0, Colors.grey, 'No Data'));

    return Stack(
      children: [
        // ── Scrollable content ──
        SingleChildScrollView(
          padding: const EdgeInsets.only(
              left: 16, right: 16, top: 16, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary header cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Items',
                      value: totalItems.toString(),
                      icon: Icons.inventory,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Stock',
                      value: totalQuantity.toString(),
                      icon: Icons.production_quantity_limits,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pie chart – wrapped with RepaintBoundary
              RepaintBoundary(
                key: _pieChartKey,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  shadowColor: AppColors.primaryPurple.withOpacity(0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('Stock Health',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Tap on a section to see details',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sections: pieSections.asMap().entries.map((entry) {
                                return PieChartSectionData(
                                  value: entry.value.value,
                                  color: entry.value.color,
                                  title:
                                      entry.value.value.toInt().toString(),
                                  radius: 80,
                                  titleStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                );
                              }).toList(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              pieTouchData: PieTouchData(
                                touchCallback:
                                    (FlTouchEvent event, pieTouchResponse) {
                                  if (event is FlTapUpEvent &&
                                      pieTouchResponse?.touchedSection !=
                                          null) {
                                    final idx = pieTouchResponse!
                                        .touchedSection!.touchedSectionIndex;
                                    if (idx < pieSections.length) {
                                      final status = pieSections[idx].status;
                                      Color statusColor;
                                      if (status == 'In Stock')
                                        statusColor = AppColors.successGreen;
                                      else if (status == 'Low Stock')
                                        statusColor = AppColors.warningOrange;
                                      else
                                        statusColor = AppColors.disabledColor;
                                      _showDrugsByStatus(
                                          allItems, status, statusColor);
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            if (inStock > 0)
                              _buildLegendChip(
                                  'In Stock', AppColors.successGreen),
                            if (lowStock > 0)
                              _buildLegendChip(
                                  'Low Stock (<50)', AppColors.warningOrange),
                            if (outOfStock > 0)
                              _buildLegendChip(
                                  'Out of Stock', AppColors.disabledColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Bar chart – wrapped with RepaintBoundary
              RepaintBoundary(
                key: _barChartKey,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  shadowColor: AppColors.primaryPurple.withOpacity(0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Top 10 Drugs by Quantity',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Total stock units per drug',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 320,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: topDrugs.isEmpty
                                  ? 10
                                  : topDrugs
                                          .map((e) => e.value.toDouble())
                                          .reduce((a, b) => a > b ? a : b) +
                                      10,
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) => Text(
                                        value.toInt().toString(),
                                        style:
                                            const TextStyle(fontSize: 11)),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 &&
                                          index < topDrugs.length) {
                                        String label =
                                            topDrugs[index].key;
                                        if (label.length > 8)
                                          label =
                                              '${label.substring(0, 6)}...';
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              top: 12),
                                          child: Text(label,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w500),
                                              textAlign:
                                                  TextAlign.center),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                              ),
                              barGroups: List.generate(
                                  topDrugs.length,
                                  (i) => BarChartGroupData(
                                        x: i,
                                        barRods: [
                                          BarChartRodData(
                                            toY: topDrugs[i]
                                                .value
                                                .toDouble(),
                                            color: AppColors.primaryPurple,
                                            width: 28,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            gradient: LinearGradient(colors: [
                                              AppColors.primaryPurple,
                                              AppColors.primaryPurple
                                                  .withOpacity(0.7)
                                            ]),
                                          )
                                        ],
                                      )),
                              gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                      color: Colors.grey.shade200,
                                      strokeWidth: 1)),
                              borderData: FlBorderData(show: false),
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod,
                                          rodIndex) =>
                                      BarTooltipItem(
                                          '${topDrugs[group.x].value}',
                                          const TextStyle(
                                              color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Filter & sort controls
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterStatus.value,
                          decoration: InputDecoration(
                            labelText: 'Filter',
                            labelStyle:
                                const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                          ),
                           style: const TextStyle(fontSize: 12, color: Colors.black87),
                          items: [
                            'All',
                            'In Stock',
                            'Low Stock',
                            'Out of Stock'
                          ]
                              .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status,
                                      style: const TextStyle(
                                          fontSize: 12))))
                              .toList(),
                          onChanged: (value) {
                            if (value != null)
                              _filterStatus.value = value;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _analyticsSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon:
                                const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    vertical: 8),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _sortColumnIndex,
                        builder: (context, colIndex, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _sortAscending,
                            builder: (context, ascending, _) {
                              return IconButton(
                                icon: Icon(colIndex == 0 && ascending
                                    ? Icons.sort_by_alpha
                                    : Icons.sort_by_alpha_outlined),
                                tooltip: colIndex == 0 && ascending
                                    ? 'Sort A-Z'
                                    : 'Sort Z-A',
                                onPressed: () {
                                  if (colIndex == 0) {
                                    _sortAscending.value = !ascending;
                                  } else {
                                    _sortColumnIndex.value = 0;
                                    _sortAscending.value = true;
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Table
              ValueListenableBuilder<String>(
                valueListenable: _filterStatus,
                builder: (context, filter, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, query, _) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _sortColumnIndex,
                        builder: (context, sortCol, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _sortAscending,
                            builder: (context, ascending, _) {
                              List<Map<String, dynamic>> filtered =
                                  allItems.where((item) {
                                final qty = item['quantity'] as int;
                                if (filter == 'In Stock' && qty < 50)
                                  return false;
                                if (filter == 'Low Stock' &&
                                    (qty == 0 || qty >= 50))
                                  return false;
                                if (filter == 'Out of Stock' && qty != 0)
                                  return false;
                                if (query.isNotEmpty) {
                                  final name =
                                      (item['drugName'] ?? '')
                                          .toLowerCase();
                                  final sr =
                                      (item['srNumber'] ?? '')
                                          .toLowerCase();
                                  if (!name.contains(
                                          query.toLowerCase()) &&
                                      !sr.contains(query.toLowerCase()))
                                    return false;
                                }
                                return true;
                              }).toList();

                              filtered.sort((a, b) {
                                if (sortCol == 0) {
                                  return ascending
                                      ? (a['drugName'] ?? '').compareTo(
                                          b['drugName'] ?? '')
                                      : (b['drugName'] ?? '').compareTo(
                                          a['drugName'] ?? '');
                                } else if (sortCol == 1) {
                                  final qA = a['quantity'] as int;
                                  final qB = b['quantity'] as int;
                                  return ascending
                                      ? qA.compareTo(qB)
                                      : qB.compareTo(qA);
                                } else {
                                  final dA = (a['lastUpdated']
                                              as Timestamp?)
                                          ?.toDate() ??
                                      DateTime(1970);
                                  final dB = (b['lastUpdated']
                                              as Timestamp?)
                                          ?.toDate() ??
                                      DateTime(1970);
                                  return ascending
                                      ? dA.compareTo(dB)
                                      : dB.compareTo(dA);
                                }
                              });

                              if (filtered.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      children: [
                                        Icon(Icons.inventory,
                                            size: 64,
                                            color: Colors.grey[400]),
                                        const SizedBox(height: 12),
                                        Text('No matching items',
                                            style: TextStyle(
                                                color:
                                                    Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20)),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor:
                                          MaterialStateProperty
                                              .resolveWith((states) =>
                                                  AppColors.primaryPurple
                                                      .withOpacity(0.1)),
                                      columnSpacing: 16,
                                      horizontalMargin: 12,
                                      dataRowMinHeight: 40,
                                      dataRowMaxHeight: 48,
                                      sortColumnIndex: sortCol,
                                      sortAscending: ascending,
                                      columns: [
                                        DataColumn(
                                          label: const Text('Drug Name',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          onSort: (colIndex, _) {
                                            _sortColumnIndex.value =
                                                colIndex;
                                            _sortAscending.value =
                                                !ascending;
                                          },
                                        ),
                                        const DataColumn(
                                            label: Text('Dosage',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight
                                                            .bold))),
                                        const DataColumn(
                                            label: Text('SR Number',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight
                                                            .bold))),
                                        DataColumn(
                                          label: const Text('Quantity',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          onSort: (colIndex, _) {
                                            _sortColumnIndex.value =
                                                colIndex;
                                            _sortAscending.value =
                                                !ascending;
                                          },
                                        ),
                                        const DataColumn(
                                            label: Text('Status',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight
                                                            .bold))),
                                        DataColumn(
                                          label: const Text(
                                              'Last Updated',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          onSort: (colIndex, _) {
                                            _sortColumnIndex.value =
                                                colIndex;
                                            _sortAscending.value =
                                                !ascending;
                                          },
                                        ),
                                      ],
                                      rows: filtered.map((item) {
                                        final qty =
                                            item['quantity'] as int;
                                        final drugName =
                                            item['drugName'] ?? '';
                                        final dosage =
                                            item['dosage'] ?? '';
                                        final srNumber =
                                            item['srNumber'] ?? '';
                                        final lastUpdated =
                                            item['lastUpdated']
                                                as Timestamp?;
                                        final dateStr = lastUpdated !=
                                                null
                                            ? DateFormat('dd MMM yyyy')
                                                .format(
                                                    lastUpdated.toDate())
                                            : 'Never';

                                        String status;
                                        Color statusColor;
                                        if (qty == 0) {
                                          status = 'Out';
                                          statusColor =
                                              AppColors.disabledColor;
                                        } else if (qty < 50) {
                                          status = 'Low';
                                          statusColor =
                                              AppColors.warningOrange;
                                        } else {
                                          status = 'In';
                                          statusColor =
                                              AppColors.successGreen;
                                        }

                                        return DataRow(
                                          cells: [
                                            DataCell(Text(drugName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight
                                                            .w500))),
                                            DataCell(Text(dosage)),
                                            DataCell(Text(srNumber)),
                                            DataCell(
                                                Text(qty.toString())),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration:
                                                    BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(12),
                                                ),
                                                child: Text(status,
                                                    style: TextStyle(
                                                        color:
                                                            statusColor,
                                                        fontWeight:
                                                            FontWeight
                                                                .w600,
                                                        fontSize: 11)),
                                              ),
                                            ),
                                            DataCell(Text(dateStr,
                                                style: const TextStyle(
                                                    fontSize: 12))),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // ── PDF Download Button (fixed at bottom) ──
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPdf
                    ? null
                    : () => _generateCertificatePdf(allItems),
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded,
                        size: 22, color: Colors.white),
                label: Text(
                  _isGeneratingPdf
                      ? 'Generating Certificate...'
                      : 'Download Stock Certificate (PDF)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  disabledBackgroundColor:
                      AppColors.primaryPurple.withOpacity(0.6),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----- Helper widgets (stat cards, legend, input, summary, stock item) -----
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildLegendChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700)),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefixIcon,
    String? hintText,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
          color: enabled ? AppColors.primaryPurple : Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade100,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.inputBorder, width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.inputBorder, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.primaryPurple, width: 2.0)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2.0)),
      prefixIcon: prefixIcon == null
          ? null
          : Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(
                          color: Colors.grey.shade300, width: 1.5))),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(prefixIcon,
                      color: AppColors.primaryPurple, size: 18)),
            ),
      suffixIcon: suffixIcon,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    );
  }

  Widget _buildSummaryCard(List<Map<String, dynamic>> allItems) {
    int total = allItems.length;
    int inStock = 0, lowStock = 0, outOfStock = 0;
    for (var item in allItems) {
      final qty = item['quantity'] as int;
      if (qty == 0) outOfStock++;
      else if (qty < 50) lowStock++;
      else inStock++;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF0F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildCompactStatCard(
                      total.toString(), 'Total', AppColors.primaryPurple)),
              Expanded(
                  child: _buildCompactStatCard(
                      inStock.toString(), 'In Stock', AppColors.successGreen)),
              Expanded(
                  child: _buildCompactStatCard(
                      lowStock.toString(), 'Low', AppColors.warningOrange)),
              Expanded(
                  child: _buildCompactStatCard(
                      outOfStock.toString(), 'Out', AppColors.disabledColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(String value, String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _infoChipCompact(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: AppColors.primaryPurple),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _buildStockItemCard({
    required Map<String, dynamic> item,
    required String srNumber,
    required String drugName,
    required String dosage,
    required int quantity,
    required String? stockId,
    required String key,
    required Color statusColor,
    required String statusText,
    required Timestamp? lastUpdated,
  }) {
    final controller = _getController(key);
    final formattedDate = lastUpdated != null
        ? DateFormat('dd MMM yyyy').format(lastUpdated.toDate())
        : 'Not updated';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF9F7FF)]),
        boxShadow: [
          BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 1),
              spreadRadius: -1)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(color: statusColor, width: 3))),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Text(drugName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: statusColor.withOpacity(0.2),
                              width: 0.5)),
                      child: Text(statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    _infoChipCompact(Icons.qr_code, 'SR: $srNumber'),
                    _infoChipCompact(Icons.medical_services_outlined,
                        'Dosage: $dosage'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.inventory,
                        size: 12, color: AppColors.primaryPurple),
                    const SizedBox(width: 3),
                    Text('Current: $quantity',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Qty',
                          labelStyle:
                              const TextStyle(fontSize: 11),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.inputBorder)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.inputBorder)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.primaryPurple)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (stockId == null)
                      ElevatedButton(
                        onPressed: () {
                          final newQty =
                              int.tryParse(controller.text);
                          if (newQty != null && newQty >= 0) {
                            _createStockEntry(
                              antibioticId: item['antibioticId'],
                              dosageIndex: item['dosageIndex'],
                              srNumber: srNumber,
                              drugName: drugName,
                              dosage: dosage,
                              initialQuantity: newQty,
                            );
                          } else {
                            _showSnackBar(
                                'Enter a valid quantity', false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: const Size(32, 28),
                        ),
                        child: const Text('Add',
                            style: TextStyle(fontSize: 10)),
                      )
                    else
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              final addQty =
                                  int.tryParse(controller.text);
                              if (addQty != null && addQty > 0) {
                                _addQuantity(
                                    stockId, quantity, addQty);
                              } else {
                                _showSnackBar(
                                    'Enter a positive number',
                                    false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              minimumSize: const Size(30, 26),
                            ),
                            child: const Text('Add',
                                style: TextStyle(fontSize: 9)),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: () {
                              final newQty =
                                  int.tryParse(controller.text);
                              if (newQty != null && newQty >= 0) {
                                _updateQuantity(stockId, newQty);
                              } else {
                                _showSnackBar(
                                    'Enter a valid quantity', false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              minimumSize: const Size(30, 26),
                            ),
                            child: const Text('Update',
                                style: TextStyle(fontSize: 9)),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 0.8, thickness: 0.5),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fingerprint,
                            size: 9, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                            stockId != null
                                ? 'ID: ${stockId.substring(0, 4)}...'
                                : 'ID: Not created',
                            style: const TextStyle(
                                fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.update,
                            size: 9, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                            stockId != null
                                ? formattedDate
                                : 'Not updated',
                            style: const TextStyle(
                                fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _antibioticsCollection.snapshots(),
                builder: (context, antibioticSnapshot) {
                  if (antibioticSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (antibioticSnapshot.hasError) {
                    return Center(
                        child:
                            Text('Error: ${antibioticSnapshot.error}'));
                  }
                  final antibioticDocs =
                      antibioticSnapshot.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: _stockCollection.snapshots(),
                    builder: (context, stockSnapshot) {
                      if (stockSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final Map<String, Map<String, dynamic>> stockMap =
                          {};
                      if (stockSnapshot.hasData) {
                        for (var doc in stockSnapshot.data!.docs) {
                          final data =
                              doc.data() as Map<String, dynamic>?;
                          if (data == null) continue;
                          final key = _itemKey(
                              data['antibioticId'] ?? '',
                              data['dosageIndex'] ?? 0);
                          stockMap[key] = {...data, 'stockId': doc.id};
                        }
                      }

                      List<Map<String, dynamic>> allItems = [];
                      for (var antibioticDoc in antibioticDocs) {
                        final antibioticData = antibioticDoc.data()
                            as Map<String, dynamic>?;
                        if (antibioticData == null) continue;
                        final antibioticId = antibioticDoc.id;
                        final drugName =
                            antibioticData['name'] ?? 'Unknown';
                        final dosages = antibioticData['dosages']
                                as List<dynamic>? ??
                            [];

                        for (int i = 0; i < dosages.length; i++) {
                          final dosageMap =
                              dosages[i] as Map<String, dynamic>?;
                          if (dosageMap == null) continue;
                          final srNumber =
                              dosageMap['srNumber'] ?? '';
                          final dosage = dosageMap['dosage'] ?? '';

                          final key = _itemKey(antibioticId, i);
                          final stockEntry = stockMap[key];
                          final quantity =
                              (stockEntry?['quantity'] ?? 0).toInt();
                          final stockId = stockEntry?['stockId'];
                          final lastUpdated =
                              stockEntry?['lastUpdated'] as Timestamp?;

                          allItems.add({
                            'antibioticId': antibioticId,
                            'dosageIndex': i,
                            'srNumber': srNumber,
                            'drugName': drugName,
                            'dosage': dosage,
                            'quantity': quantity,
                            'stockId': stockId,
                            'key': key,
                            'lastUpdated': lastUpdated,
                          });
                        }
                      }

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStockManagementTab(allItems),
                          _buildAnalyticsTab(allItems),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieSection {
  final double value;
  final Color color;
  final String status;
  _PieSection(this.value, this.color, this.status);
}