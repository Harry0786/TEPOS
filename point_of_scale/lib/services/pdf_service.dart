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
                      'Estimate $estimateNumber',
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
                    _buildDetailRow('Sale By', saleBy),
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
                            width: 70,
                            child: pw.Text(
                              'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
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
                      'Total Amount',
                      'Rs. ${total.toStringAsFixed(2)}',
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
                      'For any queries, please contact us.',
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
    final file = File('${output.path}/estimate_$estimateNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
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
                    _buildDetailRow('Sale By', saleBy),
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
                            width: 70,
                            child: pw.Text(
                              'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
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
                      'Total Paid',
                      'Rs. ${total.toStringAsFixed(2)}',
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
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.black,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isTotal ? 16 : 12,
            fontWeight: pw.FontWeight.bold,
            color:
                isDiscount
                    ? PdfColors.red
                    : (isTotal ? PdfColors.green : PdfColors.black),
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
