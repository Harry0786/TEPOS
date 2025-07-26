import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<File> generateEstimatePdf({
    required String estimateNumber,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String saleBy,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required bool isPercentageDiscount,
    required double total,
    required DateTime createdAt,
  }) async {
    final pdf = pw.Document();
    
    // Items per page calculation (optimized for 15 items per page)
    const int itemsPerPage = 15;
    final int totalPages = (items.length / itemsPerPage).ceil();
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage > items.length) 
          ? items.length 
          : startIndex + itemsPerPage;
      final pageItems = items.sublist(startIndex, endIndex);
      final isLastPage = pageIndex == totalPages - 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15),
          build: (pw.Context context) {
            return pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildCompactHeader(estimateNumber, createdAt, saleBy),
                  pw.Container(height: 1, color: PdfColors.grey400),
                  
                  // Customer details (vertical, bold, larger)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Customer: $customerName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        if (customerPhone.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('Phone: $customerPhone', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                        if (customerAddress.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('Address: $customerAddress', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                  pw.Container(height: 1, color: PdfColors.grey400),
                  
                  // Items and summary in expanded area
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Column(
                        children: [
                          // Items table header
                          _buildItemsTableHeader(large: true),
                          
                          // Items list for this page
                          pw.Expanded(
                            child: pw.Column(
                              children: [
                                ...pageItems.map((item) => _buildCompactItemRow(item, large: true)),
                                pw.Spacer(),
                              ],
                            ),
                          ),
                          
                          // Summary (only on last page)
                          if (isLastPage) ...[
                            _buildCompactSummary(subtotal, discountAmount, isPercentageDiscount, total, large: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Page number (only if multiple pages)
                  if (totalPages > 1) ...[
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(
                        alignment: pw.Alignment.bottomCenter,
                        child: pw.Text(
                          'Page ${pageIndex + 1} of $totalPages',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    }

    // Save PDF to temporary directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/estimate_$estimateNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Compact header for first page
  static pw.Widget _buildCompactHeader(String estimateNumber, DateTime createdAt, String saleBy) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: pw.Column(
        children: [
          // Company name and address centered
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'TIRUPATI ELECTRICALS',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                'Daulatganj, Gwalior',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 16), // 2 line space after company address
            ],
          ),
          // Estimate details and Made By in row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Estimate No. $estimateNumber',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                ],
              ),
              pw.Text(
                'Made By: $saleBy',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Items table header
  static pw.Widget _buildItemsTableHeader({bool large = false}) {
    final double fontSize = large ? 12 : 8;
    final double paddingV = large ? 10 : 6;
    final double paddingH = large ? 12 : 8;
    final double spacing = large ? 6 : 2;
    
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: paddingV, horizontal: paddingH),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              'Product',
              style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: spacing),
          pw.Container(
            width: large ? 60 : 40,
            child: pw.Text(
              'Rate',
              style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: spacing),
          pw.Container(
            width: large ? 40 : 25,
            child: pw.Text(
              'Qty',
              style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: spacing),
          pw.Container(
            width: large ? 50 : 30,
            child: pw.Text(
              'Disc%',
              style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: spacing),
          pw.Container(
            width: large ? 80 : 50,
            child: pw.Text(
              'Amount',
              style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  // Compact item row
  static pw.Widget _buildCompactItemRow(Map<String, dynamic> item, {bool large = false}) {
    final itemAmount = (item['price'] * item['quantity']) * (1 - ((item['discount'] ?? 0) / 100));
    final double fontSize = large ? 11 : 7;
    final double paddingV = large ? 8 : 3;
    final double paddingH = large ? 12 : 8;
    final double spacing = large ? 6 : 2;
    
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: paddingV, horizontal: paddingH),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.25),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              item['name'],
              style: pw.TextStyle(fontSize: fontSize),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: spacing),
          pw.Container(
            width: large ? 60 : 40,
            child: pw.Text(
              'Rs.${item['price'].toStringAsFixed(0)}',
              style: pw.TextStyle(fontSize: fontSize),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: spacing),
          pw.Container(
            width: large ? 40 : 25,
            child: pw.Text(
              '${item['quantity']}',
              style: pw.TextStyle(fontSize: fontSize),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: spacing),
          pw.Container(
            width: large ? 50 : 30,
            child: pw.Text(
              '${(item['discount'] ?? 0).toStringAsFixed(0)}%',
              style: pw.TextStyle(fontSize: fontSize, color: PdfColors.black),
              textAlign: pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: spacing),
          pw.Container(
            width: large ? 80 : 50,
            child: pw.Text(
              'Rs.${itemAmount.toStringAsFixed(0)}',
              style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  // Compact summary
  static pw.Widget _buildCompactSummary(double subtotal, double discountAmount, bool isPercentageDiscount, double total, {bool large = false}) {
    final calculatedDiscount = isPercentageDiscount 
        ? (subtotal * discountAmount / 100) 
        : discountAmount;
    final double fontSize = large ? 12 : 9;
    final double spacing = large ? 8 : 6;
        
    return pw.Container(
      padding: pw.EdgeInsets.all(large ? 12 : 8),
      child: pw.Column(
        children: [
          pw.Container(height: 1, color: PdfColors.grey400),
          pw.SizedBox(height: spacing),
          _buildSummaryRow('Subtotal', 'Rs.${subtotal.toStringAsFixed(2)}', fontSize: fontSize),
          if (discountAmount > 0) ...[
            pw.SizedBox(height: spacing / 2),
            _buildSummaryRow(
              'Discount (${isPercentageDiscount ? "${discountAmount.toStringAsFixed(0)}%" : "Rs.${discountAmount.toStringAsFixed(2)}"})',
              '- Rs.${calculatedDiscount.toStringAsFixed(2)}',
              isDiscount: true,
              fontSize: fontSize,
            ),
          ],
          pw.SizedBox(height: spacing / 2),
          pw.Container(height: 1, color: PdfColors.grey400),
          pw.SizedBox(height: spacing / 2),
          _buildSummaryRow('Total Amount', 'Rs.${total.toStringAsFixed(2)}', isTotal: true, fontSize: fontSize),
        ],
      ),
    );
  }

  static Future<File> generateSalePdf({
    required String saleNumber,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String saleBy,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required bool isPercentageDiscount,
    required double total,
    required DateTime createdAt,
    double? amountPaid,
  }) async {
    final pdf = pw.Document();

    // Add page to PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TIRUPATI ELECTRICALS',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Sale Bill $saleNumber',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Sale By positioned on the right above customer details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Container()), // Empty space on left
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Text(
                      'Sale By: $saleBy',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Customer Details
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Customer Details',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildDetailRow('Name', customerName),
                    _buildDetailRow('Phone', customerPhone),
                    _buildDetailRow('Address', customerAddress),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Items Table
              pw.Text(
                'Items',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 10),

              // Table Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'Product',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Container(
                      width: 60,
                      child: pw.Text(
                        'Rate',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Container(
                      width: 40,
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Container(
                      width: 50,
                      child: pw.Text(
                        'Disc. %',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Container(
                      width: 70,
                      child: pw.Text(
                        'Amount',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              // Items
              ...items
                  .map(
                    (item) => pw.Container(
                      margin: const pw.EdgeInsets.only(top: 4),
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey300,
                          width: 0.5,
                        ),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              item['name'],
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.black,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Container(
                            width: 60,
                            child: pw.Text(
                              'Rs. ${item['price'].toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.grey700,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Container(
                            width: 40,
                            child: pw.Text(
                              '${item['quantity']}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.black,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Container(
                            width: 50,
                            child: pw.Text(
                              '${(item['discount'] ?? 0).toStringAsFixed(1)}%',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.redAccent,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Container(
                            width: 70,
                            child: pw.Text(
                              'Rs. ${((item['price'] * item['quantity']) * (1 - ((item['discount'] ?? 0) / 100))).toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),

              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _buildSummaryRow(
                      'Subtotal',
                      'Rs. ${subtotal.toStringAsFixed(2)}',
                    ),
                    if (discountAmount > 0) ...[
                      pw.SizedBox(height: 8),
                      _buildSummaryRow(
                        'Discount (${isPercentageDiscount ? "${discountAmount.toStringAsFixed(0)}%" : "Rs. ${discountAmount.toStringAsFixed(2)}"})',
                        '- Rs. ${(isPercentageDiscount ? (subtotal * discountAmount / 100) : discountAmount).toStringAsFixed(2)}',
                        isDiscount: true,
                      ),
                    ],
                    pw.SizedBox(height: 8),
                    pw.Divider(color: PdfColors.grey400),
                    pw.SizedBox(height: 8),
                    _buildSummaryRow(
                      'Total',
                      'Rs. ${total.toStringAsFixed(2)}',
                    ),
                    pw.SizedBox(height: 8),
                    _buildSummaryRow(
                      'Amount Paid',
                      'Rs. ${(amountPaid ?? total).toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Payment received. For any queries, please contact us.',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to temporary directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/sale_$saleNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 80,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isDiscount = false,
    bool isTotal = false,
    double fontSize = 12,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isTotal ? fontSize + 2 : fontSize,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.black,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isTotal ? fontSize + 4 : fontSize,
            fontWeight: isDiscount ? pw.FontWeight.normal : pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  // Report PDF Generation
  static Future<Uint8List> generateReportPdf(
    String reportType,
    Map<String, dynamic> reportData,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TIRUPATI ELECTRICALS',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      reportType,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary Section
              if (reportData['summary'] != null) ...[
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildReportSummaryTable(reportData['summary']),
                pw.SizedBox(height: 20),
              ],

              // Statistics Section
              if (reportData['statistics'] != null) ...[
                pw.Text(
                  'Statistics',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildReportStatisticsTable(reportData['statistics']),
                pw.SizedBox(height: 20),
              ],

              // Staff Performance Section
              if (reportData['staff_performance'] != null) ...[
                pw.Text(
                  'Staff Performance',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildReportStaffTable(reportData['staff_performance']),
                pw.SizedBox(height: 20),
              ],

              // Recent Items Section
              if (reportData['recent_items'] != null) ...[
                pw.Text(
                  'Recent Items',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 10),
                _buildReportRecentItemsTable(reportData['recent_items']),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildReportSummaryTable(Map<String, dynamic> summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          _buildReportSummaryRow(
            'Total Sales',
            'Rs. ${summary['total_sales']?.toStringAsFixed(0) ?? '0'}',
          ),
          _buildReportSummaryRow(
            'Total Orders',
            '${summary['total_orders'] ?? '0'}',
          ),
          _buildReportSummaryRow(
            'Total Estimates',
            '${summary['total_estimates'] ?? '0'}',
          ),
          _buildReportSummaryRow(
            'Completed Sales',
            '${summary['completed_sales'] ?? '0'}',
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportStatisticsTable(
    Map<String, dynamic> statistics,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children:
            statistics.entries
                .map(
                  (entry) => _buildReportSummaryRow(
                    entry.key.replaceAll('_', ' ').toUpperCase(),
                    entry.value.toString(),
                  ),
                )
                .toList(),
      ),
    );
  }

  static pw.Widget _buildReportStaffTable(List<dynamic> staffPerformance) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Staff',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Sales',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Amount',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Staff rows
          ...staffPerformance
              .map(
                (staff) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          staff['staff_name'] ?? 'Unknown',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          '${staff['total_sales'] ?? '0'}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          'Rs. ${(staff['total_amount'] ?? 0.0).toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  static pw.Widget _buildReportRecentItemsTable(List<dynamic> recentItems) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Customer',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Amount',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Status',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'Date',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Item rows
          ...recentItems
              .take(10)
              .map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          item['customer_name'] ?? 'Unknown',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          'Rs. ${(item['total'] ?? 0.0).toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          item['status'] ?? 'Unknown',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          DateFormat('MM/dd').format(
                            DateTime.parse(
                              item['created_at'] ??
                                  DateTime.now().toIso8601String(),
                            ).toUtc().add(
                              const Duration(hours: 5, minutes: 30),
                            ),
                          ),
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}
