import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../models/qr_marker.dart';
import '../../../../core/database/local_database.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';

class QRExportPage extends StatefulWidget {
  final String buildingId;
  final String buildingName;

  const QRExportPage({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  @override
  State<QRExportPage> createState() => _QRExportPageState();
}

class _QRExportPageState extends State<QRExportPage> {
  List<QRMarker> _qrMarkers = [];
  bool _isLoading = true;
  String _selectedFormat = 'json';
  bool _includeImages = true;

  @override
  void initState() {
    super.initState();
    _loadQRMarkers();
  }

  Future<void> _loadQRMarkers() async {
    try {
      final database = getIt<LocalDatabase>();
      // Get all QR markers for this building
      final allMarkers = await database.getAllQRMarkers();
      final buildingMarkers = allMarkers
          .where((marker) => marker.buildingId == widget.buildingId)
          .toList();
      
      setState(() {
        _qrMarkers = buildingMarkers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading QR markers: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text('QR Code Export - ${widget.buildingName}'),
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQRMarkers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildExportOptions(),
                _buildQRMarkersList(),
              ],
            ),
      floatingActionButton: _qrMarkers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _exportQRMarkers,
              backgroundColor: AppColors.primaryOrange,
              icon: const Icon(Icons.download),
              label: const Text('Export All'),
            )
          : null,
    );
  }

  Widget _buildExportOptions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Options',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Format:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedFormat,
                dropdownColor: AppColors.surfaceDark,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'json', child: Text('JSON')),
                  DropdownMenuItem(value: 'csv', child: Text('CSV')),
                  DropdownMenuItem(value: 'pdf', child: Text('PDF Report')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFormat = value!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text('Include QR Code Images', 
                style: TextStyle(color: AppColors.textPrimary)),
            value: _includeImages,
            onChanged: (value) {
              setState(() {
                _includeImages = value!;
              });
            },
            activeColor: AppColors.primaryOrange,
          ),
          const SizedBox(height: 8),
          Text(
            '${_qrMarkers.length} QR markers found',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQRMarkersList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _qrMarkers.length,
        itemBuilder: (context, index) {
          final marker = _qrMarkers[index];
          return _buildQRMarkerCard(marker);
        },
      ),
    );
  }

  Widget _buildQRMarkerCard(QRMarker marker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          marker.description ?? 'QR Marker ${marker.id.substring(0, 8)}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          'Floor: ${marker.floorId} • Position: (${marker.x.toStringAsFixed(2)}, ${marker.y.toStringAsFixed(2)})',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_includeImages) ...[
                  Center(
                    child: QrImageView(
                      data: marker.qrData,
                      version: QrVersions.auto,
                      size: 150.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildInfoRow('ID', marker.id),
                _buildInfoRow('Building ID', marker.buildingId),
                _buildInfoRow('Floor ID', marker.floorId),
                _buildInfoRow('X Coordinate', marker.x.toString()),
                _buildInfoRow('Y Coordinate', marker.y.toString()),
                _buildInfoRow('Orientation', '${marker.orientationDegrees}°'),
                _buildInfoRow('QR Data', marker.qrData),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(marker.qrData),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy QR Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _shareQRMarker(marker),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _shareQRMarker(QRMarker marker) async {
    final data = {
      'id': marker.id,
      'building_id': marker.buildingId,
      'floor_id': marker.floorId,
      'x': marker.x,
      'y': marker.y,
      'orientation': marker.orientationDegrees,
      'qr_data': marker.qrData,
      'description': marker.description,
    };
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await Share.share(jsonString, subject: 'QR Marker Data');
  }

  Future<void> _exportQRMarkers() async {
    try {
      String content;
      String fileName;
      
      switch (_selectedFormat) {
        case 'json':
          content = _generateJSON();
          fileName = '${widget.buildingName}_qr_markers.json';
          break;
        case 'csv':
          content = _generateCSV();
          fileName = '${widget.buildingName}_qr_markers.csv';
          break;
        case 'pdf':
          await _generatePDF();
          return;
        default:
          content = _generateJSON();
          fileName = '${widget.buildingName}_qr_markers.json';
      }

      // Save to device
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);

      // Share the file
      await Share.shareXFiles([XFile(file.path)], 
          subject: 'QR Markers Export - ${widget.buildingName}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_qrMarkers.length} QR markers to $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  String _generateJSON() {
    final exportData = {
      'building_id': widget.buildingId,
      'building_name': widget.buildingName,
      'exported_at': DateTime.now().toIso8601String(),
      'total_markers': _qrMarkers.length,
      'qr_markers': _qrMarkers.map((marker) => {
        'id': marker.id,
        'building_id': marker.buildingId,
        'floor_id': marker.floorId,
        'x': marker.x,
        'y': marker.y,
        'orientation_degrees': marker.orientationDegrees,
        'qr_data': marker.qrData,
        'description': marker.description,
      }).toList(),
    };
    
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  String _generateCSV() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Building ID,Floor ID,X,Y,Orientation,QR Data,Description');
    
    for (final marker in _qrMarkers) {
      buffer.writeln([
        marker.id,
        marker.buildingId,
        marker.floorId,
        marker.x,
        marker.y,
        marker.orientationDegrees,
        '"${marker.qrData}"',
        '"${marker.description ?? ''}"',
      ].join(','));
    }
    
    return buffer.toString();
  }

  Future<void> _generatePDF() async {
    // TODO: Implement PDF generation with QR code images
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF export coming soon!')),
    );
  }
}