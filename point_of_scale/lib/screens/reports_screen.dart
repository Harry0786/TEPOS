import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  Map<String, dynamic>? _currentReport;
  String _currentReportType = '';
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  DateTime? _lastRefreshTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Business Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Report Type Selection
          _buildReportTypeSelector(),
          const SizedBox(height: 16),

          // Date/Time Selectors (conditional)
          if (_currentReportType.isNotEmpty) _buildDateSelectors(),

          const SizedBox(height: 16),

          // Generate Report Button
          if (_currentReportType.isNotEmpty) _buildGenerateButton(),

          const SizedBox(height: 16),

          // Report Display
          Expanded(child: _buildReportDisplay()),
        ],
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Report Type',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildReportTypeChip('Today\'s Report', Icons.today),
              _buildReportTypeChip('Date Range Report', Icons.date_range),
              _buildReportTypeChip('Monthly Report', Icons.calendar_month),
              _buildReportTypeChip('Staff Performance', Icons.people),
              _buildReportTypeChip('Estimates Only', Icons.description),
              _buildReportTypeChip('Orders Only', Icons.receipt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeChip(String title, IconData icon) {
    final isSelected = _currentReportType == title;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : const Color(0xFF6B8E7F),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(color: isSelected ? Colors.white : Colors.grey),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentReportType = selected ? title : '';
          _currentReport = null; // Clear previous report
        });
      },
      backgroundColor: const Color(0xFF2A2A2A),
      selectedColor: const Color(0xFF6B8E7F),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildDateSelectors() {
    if (_currentReportType == 'Today\'s Report') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentReportType == 'Date Range Report'
                ? 'Select Date Range'
                : 'Select Month',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_currentReportType == 'Date Range Report') ...[
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    'Start Date',
                    _selectedStartDate,
                    (date) => setState(() => _selectedStartDate = date),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    'End Date',
                    _selectedEndDate,
                    (date) => setState(() => _selectedEndDate = date),
                  ),
                ),
              ],
            ),
          ] else if (_currentReportType == 'Monthly Report') ...[
            Row(children: [Expanded(child: _buildMonthYearSelector())]),
          ],
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    Function(DateTime?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF6B8E7F),
                      surface: Color(0xFF1A1A1A),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (selectedDate != null) {
              onChanged(selectedDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade600),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? DateFormat('MMM dd, yyyy').format(date)
                      : 'Select date',
                  style: TextStyle(
                    color: date != null ? Colors.white : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthYearSelector() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedMonth,
            decoration: const InputDecoration(
              labelText: 'Month',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white),
            items: List.generate(12, (index) {
              return DropdownMenuItem(
                value: index + 1,
                child: Text(
                  DateFormat('MMMM').format(DateTime(2024, index + 1)),
                ),
              );
            }),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMonth = value);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: const InputDecoration(
              labelText: 'Year',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white),
            items: List.generate(5, (index) {
              final year = DateTime.now().year - 2 + index;
              return DropdownMenuItem(
                value: year,
                child: Text(year.toString()),
              );
            }),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedYear = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    bool canGenerate = false;

    switch (_currentReportType) {
      case 'Today\'s Report':
        canGenerate = true;
        break;
      case 'Date Range Report':
        canGenerate = _selectedStartDate != null && _selectedEndDate != null;
        break;
      case 'Monthly Report':
        canGenerate = true;
        break;
      default:
        canGenerate = true;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: canGenerate ? _generateReport : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B8E7F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(_isLoading ? Icons.hourglass_empty : Icons.analytics),
            const SizedBox(width: 8),
            Text(_isLoading ? 'Generating...' : 'Generate Report'),
          ],
        ),
      ),
    );
  }

  Widget _buildReportDisplay() {
    if (_currentReport == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'Select a report type and generate to view results',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: const Color(0xFF6B8E7F)),
              const SizedBox(width: 8),
              Text(
                _currentReportType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _exportToPdf,
                icon: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFF6B8E7F),
                ),
                tooltip: 'Export to PDF',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: _buildReportContent())),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    if (_currentReport == null) return const SizedBox.shrink();

    final report = _currentReport!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards
        if (report['summary'] != null) ...[
          _buildSummaryCards(report['summary']),
          const SizedBox(height: 20),
        ],

        // Detailed Statistics
        if (report['statistics'] != null) ...[
          _buildStatisticsSection(report['statistics']),
          const SizedBox(height: 20),
        ],

        // Staff Performance
        if (report['staff_performance'] != null) ...[
          _buildStaffPerformanceSection(report['staff_performance']),
          const SizedBox(height: 20),
        ],

        // Recent Items
        if (report['recent_items'] != null) ...[
          _buildRecentItemsSection(report['recent_items']),
        ],
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
          'Total Sales',
          'Rs. ${summary['total_sales']?.toStringAsFixed(0) ?? '0'}',
          Icons.attach_money,
          const Color(0xFF4CAF50),
        ),
        _buildSummaryCard(
          'Total Orders',
          '${summary['total_orders'] ?? '0'}',
          Icons.receipt,
          const Color(0xFF2196F3),
        ),
        _buildSummaryCard(
          'Total Estimates',
          '${summary['total_estimates'] ?? '0'}',
          Icons.description,
          const Color(0xFFFF9800),
        ),
        _buildSummaryCard(
          'Completed Sales',
          '${summary['completed_sales'] ?? '0'}',
          Icons.check_circle,
          const Color(0xFF9C27B0),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(Map<String, dynamic> statistics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed Statistics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...statistics.entries.map(
          (entry) => _buildStatisticRow(entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildStatisticRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceSection(List<dynamic> staffPerformance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Staff Performance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...staffPerformance.map((staff) => _buildStaffCard(staff)),
      ],
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF6B8E7F),
            child: Text(
              staff['staff_name']?.toString().substring(0, 1).toUpperCase() ??
                  'S',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff['staff_name'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Sales: ${staff['total_sales'] ?? '0'} | Amount: Rs. ${staff['total_amount']?.toStringAsFixed(0) ?? '0'}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItemsSection(List<dynamic> recentItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Items',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...recentItems.take(5).map((item) => _buildRecentItemCard(item)),
      ],
    );
  }

  Widget _buildRecentItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            item['type'] == 'order' ? Icons.receipt : Icons.description,
            color: const Color(0xFF6B8E7F),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['customer_name'] ?? 'Unknown Customer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Rs. ${item['total']?.toStringAsFixed(0) ?? '0'} • ${item['status'] ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM dd').format(
              DateTime.parse(
                item['created_at'] ?? DateTime.now().toIso8601String(),
              ).toUtc().add(const Duration(hours: 5, minutes: 30)),
            ),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic>? report;

      switch (_currentReportType) {
        case 'Today\'s Report':
          report = await ApiService.fetchTodayReport();
          break;
        case 'Date Range Report':
          if (_selectedStartDate != null && _selectedEndDate != null) {
            final startDate = DateFormat(
              'yyyy-MM-dd',
            ).format(_selectedStartDate!);
            final endDate = DateFormat('yyyy-MM-dd').format(_selectedEndDate!);
            report = await ApiService.fetchDateRangeReport(startDate, endDate);
          }
          break;
        case 'Monthly Report':
          report = await ApiService.fetchMonthlyReport(
            _selectedYear,
            _selectedMonth,
          );
          break;
        case 'Staff Performance':
          report = await ApiService.fetchStaffPerformanceReport();
          break;
        case 'Estimates Only':
          report = await ApiService.fetchEstimatesOnlyReport();
          break;
        case 'Orders Only':
          report = await ApiService.fetchOrdersOnlyReport();
          break;
      }

      if (mounted) {
        setState(() {
          _currentReport = report;
          _isLoading = false;
        });

        if (report == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate report. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPdf() async {
    if (_currentReport == null) return;

    try {
      final pdfBytes = await PdfService.generateReportPdf(
        _currentReportType,
        _currentReport!,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report exported to PDF successfully!'),
            backgroundColor: Color(0xFF6B8E7F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
