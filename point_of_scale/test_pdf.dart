import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

void main() async {
  print('Testing PDF Generation...');

  try {
    // Create a simple test PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
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
              pw.SizedBox(height: 20),
              pw.Text(
                'Test Estimate #001',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Customer: Test Customer'),
              pw.Text('Phone: 9876543210'),
              pw.Text('Address: Test Address'),
              pw.SizedBox(height: 20),
              pw.Text('Items:'),
              pw.Text('1. Test Product - Rs. 100 x 2 = Rs. 200'),
              pw.SizedBox(height: 20),
              pw.Text('Total: Rs. 200'),
            ],
          );
        },
      ),
    );

    // Save PDF to temporary directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/test_estimate.pdf');
    await file.writeAsBytes(await pdf.save());

    print('✅ PDF generated successfully!');
    print('📄 File saved at: ${file.path}');
    print('📏 File size: ${await file.length()} bytes');
  } catch (e) {
    print('❌ Error generating PDF: $e');
  }
}
