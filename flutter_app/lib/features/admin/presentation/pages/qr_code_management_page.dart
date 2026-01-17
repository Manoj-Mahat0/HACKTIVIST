import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../buildings/presentation/bloc/buildings_bloc.dart';
import '../../../buildings/domain/entities/building.dart';

/// QR Code Management Page for Administrators
/// Allows viewing, exporting, and printing QR codes for all navigation nodes
class QRCodeManagementPage extends StatefulWidget {
  const QRCodeManagementPage({super.key});

  @override
  State<QRCodeManagementPage> createState() => _QRCodeManagementPageState();
}

class _QRCodeManagementPageState extends State<QRCodeManagementPage>
    with SingleTickerProviderStateMixin {
  static const String _apiBaseUrl = 'https://be.google.knocknockindia.com';
  
  // State
  Building? _selectedBuilding;
  List<NavigationNodeData> _navigationNodes = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Export options
  String _selectedFormat = 'json';
  bool _includeQRImages = true;
  bool _includeCoordinates = true;
  bool _includeLandmarks = true;
  int _qrSize = 200; // QR code size in pixels

  // Filter options
  String _searchQuery = '';
  int? _selectedFloor;
  String? _selectedNodeType;
  
  // Tab controller
  late TabController _tabController;
  
  // Selected nodes for bulk export
  final Set<String> _selectedNodeIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<BuildingsBloc>().add(LoadBuildingsEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildBuildingSelector(),
          if (_selectedBuilding != null) ...[
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildQRCodesTab(),
                  _buildExportTab(),
                ],
              ),
            ),
          ] else
            Expanded(child: _buildEmptyState()),
        ],
      ),
      floatingActionButton: _selectedBuilding != null && _navigationNodes.isNotEmpty
          ? _buildFAB()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.backgroundDark,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QR Code Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'Export & Print Navigation QR Codes',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        if (_selectedBuilding != null)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadNavigationNodes(_selectedBuilding!.id),
            tooltip: 'Refresh',
          ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpDialog,
          tooltip: 'Help',
        ),
      ],
    );
  }

  Widget _buildBuildingSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
      ),
      child: BlocBuilder<BuildingsBloc, BuildingsState>(
        builder: (context, state) {
          if (state is BuildingsLoadingState) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Loading buildings...', 
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          
          if (state is BuildingsLoadedState) {
            final buildings = state.buildings;
            if (buildings.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No buildings available',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            
            return DropdownButtonFormField<Building>(
              value: _selectedBuilding,
              dropdownColor: AppColors.surfaceDark,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.business, color: AppColors.primaryOrange),
                hintText: 'Select a building to manage QR codes',
                hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              isExpanded: true,
              items: buildings.map((b) => DropdownMenuItem(
                value: b,
                child: Text(b.name, style: const TextStyle(color: AppColors.textPrimary)),
              )).toList(),
              onChanged: (building) {
                setState(() {
                  _selectedBuilding = building;
                  _navigationNodes = [];
                  _selectedNodeIds.clear();
                  _selectAll = false;
                });
                if (building != null) {
                  _loadNavigationNodes(building.id);
                }
              },
            );
          }
          
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Error loading buildings',
                style: TextStyle(color: AppColors.error)),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        tabs: const [
          Tab(
            icon: Icon(Icons.qr_code_2),
            text: 'QR Codes',
          ),
          Tab(
            icon: Icon(Icons.download),
            text: 'Export',
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodesTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryOrange),
            SizedBox(height: 16),
            Text('Loading navigation nodes...', 
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, 
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadNavigationNodes(_selectedBuilding!.id),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
      );
    }

    if (_navigationNodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No navigation nodes found',
              style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add nodes in Coordinate Collection first',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final filteredNodes = _getFilteredNodes();
    final floors = _navigationNodes.map((n) => n.floorNumber).toSet().toList()..sort();
    final nodeTypes = _navigationNodes.map((n) => n.nodeType).toSet().toList()..sort();

    return Column(
      children: [
        // Filter bar
        _buildFilterBar(floors, nodeTypes),
        // Select all checkbox
        _buildSelectAllBar(filteredNodes),
        // Nodes list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredNodes.length,
            itemBuilder: (context, index) {
              final node = filteredNodes[index];
              return _buildNodeCard(node);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(List<int> floors, List<String> nodeTypes) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Search
          TextField(
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search nodes...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          // Floor and Type filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _selectedFloor,
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Floor',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Floors')),
                    ...floors.map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f == 0 ? 'Ground' : 'Floor $f'),
                    )),
                  ],
                  onChanged: (value) => setState(() => _selectedFloor = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedNodeType,
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Types')),
                    ...nodeTypes.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.toUpperCase()),
                    )),
                  ],
                  onChanged: (value) => setState(() => _selectedNodeType = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllBar(List<NavigationNodeData> filteredNodes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: _selectAll,
            activeColor: AppColors.primaryOrange,
            onChanged: (value) {
              setState(() {
                _selectAll = value ?? false;
                if (_selectAll) {
                  _selectedNodeIds.addAll(filteredNodes.map((n) => n.id));
                } else {
                  _selectedNodeIds.clear();
                }
              });
            },
          ),
          Text(
            'Select All (${_selectedNodeIds.length}/${filteredNodes.length})',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const Spacer(),
          if (_selectedNodeIds.isNotEmpty)
            TextButton.icon(
              onPressed: _exportSelectedNodes,
              icon: const Icon(Icons.download, size: 18),
              label: Text('Export ${_selectedNodeIds.length}'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(NavigationNodeData node) {
    final isSelected = _selectedNodeIds.contains(node.id);
    final qrData = 'indoor-nav://${_selectedBuilding!.id}/${node.id}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: isSelected 
            ? Border.all(color: AppColors.primaryOrange, width: 2)
            : null,
      ),
      child: ExpansionTile(
        leading: Checkbox(
          value: isSelected,
          activeColor: AppColors.primaryOrange,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedNodeIds.add(node.id);
              } else {
                _selectedNodeIds.remove(node.id);
              }
              _selectAll = _selectedNodeIds.length == _navigationNodes.length;
            });
          },
        ),
        title: Text(
          node.label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            _buildNodeTypeBadge(node.nodeType),
            const SizedBox(width: 8),
            Text(
              node.floorNumber == 0 ? 'Ground Floor' : 'Floor ${node.floorNumber}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // QR Code Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        node.label,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        node.floorNumber == 0 ? 'Ground Floor' : 'Floor ${node.floorNumber}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Node Details
                _buildDetailSection(node, qrData),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                _buildActionButtons(node, qrData),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTypeBadge(String nodeType) {
    Color color;
    IconData icon;
    
    switch (nodeType.toLowerCase()) {
      case 'entrance':
        color = Colors.green;
        icon = Icons.door_front_door;
        break;
      case 'exit':
        color = Colors.red;
        icon = Icons.exit_to_app;
        break;
      case 'elevator':
        color = Colors.blue;
        icon = Icons.elevator;
        break;
      case 'stairs':
        color = Colors.orange;
        icon = Icons.stairs;
        break;
      case 'bathroom':
      case 'restroom':
        color = Colors.purple;
        icon = Icons.wc;
        break;
      case 'room':
        color = Colors.teal;
        icon = Icons.meeting_room;
        break;
      default:
        color = AppColors.primaryOrange;
        icon = Icons.location_on;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            nodeType.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(NavigationNodeData node, String qrData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Node ID', node.id),
          _buildDetailRow('QR Code Data', qrData),
          _buildDetailRow('Latitude', node.latitude.toStringAsFixed(7)),
          _buildDetailRow('Longitude', node.longitude.toStringAsFixed(7)),
          _buildDetailRow('Floor', node.floorNumber.toString()),
          if (node.landmarkDescription != null && node.landmarkDescription!.isNotEmpty)
            _buildDetailRow('Landmark', node.landmarkDescription!),
          _buildDetailRow('Accessible', node.isAccessible ? 'Yes' : 'No'),
          _buildDetailRow('Emergency Exit', node.isEmergencyExit ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(NavigationNodeData node, String qrData) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => _copyToClipboard(qrData),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy QR Data'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _shareNode(node, qrData),
          icon: const Icon(Icons.share, size: 16),
          label: const Text('Share'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _printSingleQR(node, qrData),
          icon: const Icon(Icons.print, size: 16),
          label: const Text('Print'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export Format Selection
          _buildExportFormatCard(),
          const SizedBox(height: 16),
          
          // Export Options
          _buildExportOptionsCard(),
          const SizedBox(height: 16),
          
          // QR Code Settings
          _buildQRSettingsCard(),
          const SizedBox(height: 16),
          
          // Export Summary
          _buildExportSummaryCard(),
          const SizedBox(height