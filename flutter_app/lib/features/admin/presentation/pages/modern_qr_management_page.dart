import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/di/injection_container.dart';

/// Modern QR Code Management Page
/// Allows admins to view, generate, and export QR codes for navigation nodes
class ModernQRManagementPage extends StatefulWidget {
  const ModernQRManagementPage({super.key});

  @override
  State<ModernQRManagementPage> createState() => _ModernQRManagementPageState();
}

class _ModernQRManagementPageState extends State<ModernQRManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _buildings = [];
  String? _selectedBuildingId;
  String? _selectedBuildingName;
  List<Map<String, dynamic>> _qrMarkers = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBuildings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.dio.get('/buildings/');
      
      if (response.statusCode == 200) {
        setState(() {
          _buildings = List<Map<String, dynamic>>.from(response.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load buildings: $e');
    }
  }

  Future<void> _loadQRMarkers(String buildingId) async {
    setState(() => _isLoading = true);
    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.dio.get('/indoor/buildings/$buildingId/indoor-graph');
      
      if (response.statusCode == 200) {
        final data = response.data;
        final nodes = List<Map<String, dynamic>>.from(data['nodes'] ?? []);
        
        setState(() {
          _qrMarkers = nodes.map((node) {
            return {
              'id': node['id'],
              'label': node['label'] ?? 'Node',
              'qr_code': node['qr_code'] ?? 'indoor-nav://$buildingId/${node['id']}',
              'floor_number': node['floor_number'] ?? 0,
              'node_type': node['node_type'] ?? 'waypoint',
              'latitude': node['latitude'],
              'longitude': node['longitude'],
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load QR markers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBuildingSelection(),
                  _buildQRGallery(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryOrange.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QR Code Manager',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _selectedBuildingName ?? 'Select a building',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.qr_code_2,
              color: AppColors.primaryOrange,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primaryOrange,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            icon: Icon(Icons.business, size: 20),
            text: 'Buildings',
          ),
          Tab(
            icon: Icon(Icons.qr_code_scanner, size: 20),
            text: 'QR Codes',
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingSelection() {
    if (_isLoading && _buildings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_buildings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.business_outlined,
        title: 'No Buildings',
        subtitle: 'Create a building first to generate QR codes',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _buildings.length,
      itemBuilder: (context, index) {
        final building = _buildings[index];
        final isSelected = building['id'] == _selectedBuildingId;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryOrange.withOpacity(0.1) : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primaryOrange : AppColors.surfaceDark,
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedBuildingId = building['id'];
                  _selectedBuildingName = building['name'];
                });
                _loadQRMarkers(building['id']);
                _tabController.animateTo(1);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryOrange.withOpacity(0.3),
                            AppColors.primaryOrange.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.business,
                        color: AppColors.primaryOrange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            building['name'] ?? 'Unknown',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            building['address'] ?? 'No address',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    else
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQRGallery() {
    if (_selectedBuildingId == null) {
      return _buildEmptyState(
        icon: Icons.qr_code_scanner,
        title: 'Select a Building',
        subtitle: 'Choose a building from the Buildings tab to view QR codes',
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_qrMarkers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.qr_code_2,
        title: 'No QR Codes',
        subtitle: 'Add navigation nodes to generate QR codes',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_qrMarkers.length} QR Codes',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportAllQRCodes,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _qrMarkers.length,
            itemBuilder: (context, index) {
              return _buildQRCard(_qrMarkers[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQRCard(Map<String, dynamic> marker) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // QR Code
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: marker['qr_code'],
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
          ),
          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  marker['label'],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _getNodeIcon(marker['node_type']),
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Floor ${marker['floor_number']}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showQRDetails(marker),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(color: AppColors.primaryOrange),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('View', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _downloadQRCode(marker),
                      icon: const Icon(Icons.download, size: 18),
                      color: AppColors.primaryOrange,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNodeIcon(String nodeType) {
    switch (nodeType.toLowerCase()) {
      case 'entrance':
        return Icons.door_front_door;
      case 'exit':
        return Icons.exit_to_app;
      case 'elevator':
        return Icons.elevator;
      case 'stairs':
        return Icons.stairs;
      case 'room':
        return Icons.meeting_room;
      default:
        return Icons.location_on;
    }
  }

  void _showQRDetails(Map<String, dynamic> marker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            marker['label'],
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: marker['qr_code'],
                          version: QrVersions.auto,
                          size: 250,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildInfoRow('Node Type', marker['node_type']),
                    _buildInfoRow('Floor', 'Floor ${marker['floor_number']}'),
                    _buildInfoRow('Coordinates', '${marker['latitude']?.toStringAsFixed(6)}, ${marker['longitude']?.toStringAsFixed(6)}'),
                    _buildInfoRow('QR Data', marker['qr_code']),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: marker['qr_code']));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('QR data copied to clipboard'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceDark,
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _downloadQRCode(marker);
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Download'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQRCode(Map<String, dynamic> marker) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating QR code...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Generate QR code image
      final qrValidationResult = QrValidator.validate(
        data: marker['qr_code'],
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );

        final picData = await painter.toImageData(1024);
        if (picData != null) {
          final buffer = picData.buffer.asUint8List();
          
          // Save to temporary directory
          final tempDir = await getTemporaryDirectory();
          final fileName = 'QR_${marker['label'].toString().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(buffer);
          
          // Share the file (user can save to gallery from share menu)
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'QR Code for ${marker['label']}\nData: ${marker['qr_code']}',
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('QR code ready: ${marker['label']}'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Failed to download QR code: $e');
    }
  }

  Future<void> _exportAllQRCodes() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Export All QR Codes',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Export ${_qrMarkers.length} QR codes for $_selectedBuildingName?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performBulkExport();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkExport() async {
    try {
      int successCount = 0;
      List<XFile> qrFiles = [];

      // Show progress
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generating ${_qrMarkers.length} QR codes...'),
          duration: Duration(seconds: _qrMarkers.length + 2),
        ),
      );

      final tempDir = await getTemporaryDirectory();

      // Generate all QR codes
      for (var marker in _qrMarkers) {
        try {
          final qrValidationResult = QrValidator.validate(
            data: marker['qr_code'],
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
          );

          if (qrValidationResult.status == QrValidationStatus.valid) {
            final qrCode = qrValidationResult.qrCode!;
            final painter = QrPainter.withQr(
              qr: qrCode,
              color: const Color(0xFF000000),
              emptyColor: const Color(0xFFFFFFFF),
              gapless: true,
            );

            final picData = await painter.toImageData(1024);
            if (picData != null) {
              final buffer = picData.buffer.asUint8List();
              
              // Save to temp directory
              final fileName = 'QR_${marker['label'].toString().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
              final file = File('${tempDir.path}/$fileName');
              await file.writeAsBytes(buffer);
              
              qrFiles.add(XFile(file.path));
              successCount++;
            }
          }
          
          // Small delay
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          // Continue with next QR code
        }
      }

      if (qrFiles.isNotEmpty) {
        // Share all QR codes
        await Share.shareXFiles(
          qrFiles,
          text: 'QR Codes for $_selectedBuildingName\nTotal: ${qrFiles.length} codes',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated $successCount QR codes'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        _showError('No QR codes were generated');
      }
    } catch (e) {
      _showError('Failed to export QR codes: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
