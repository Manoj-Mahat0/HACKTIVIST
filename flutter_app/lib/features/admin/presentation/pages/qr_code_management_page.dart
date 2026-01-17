import 'dart:convert';
// Removed unused imports
import 'package:flutter/material.dart';
// Removed unused rendering import
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
// Removed unused path_provider import
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
// Removed unused pdf import
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';
// Removed unused token_storage import
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
      body: SafeArea(
        child: Column(
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
      title: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [AppColors.primaryOrange, AppColors.primaryOrangeLight],
        ).createShader(bounds),
        child: const Text(
          'QR Code Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        if (_selectedBuilding != null)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadNavigationNodes(_selectedBuilding!.id),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceDark.withOpacity(0.7),
              foregroundColor: AppColors.primaryOrange,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: _showHelpDialog,
          tooltip: 'Help',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceDark.withOpacity(0.7),
            foregroundColor: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingSelector() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceDark,
            AppColors.cardDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _selectedBuilding != null 
              ? AppColors.primaryOrange.withOpacity(0.5) 
              : AppColors.textSecondary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BlocBuilder<BuildingsBloc, BuildingsState>(
        builder: (context, state) {
          if (state is BuildingsLoadingState) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Loading buildings...', 
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }
          
          if (state is BuildingsLoadedState) {
            final buildings = state.buildings;
            if (buildings.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No buildings available',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              );
            }
            
            return DropdownButtonFormField<Building>(
              value: _selectedBuilding,
              dropdownColor: AppColors.cardDark,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.business_rounded, 
                  color: _selectedBuilding != null 
                      ? AppColors.primaryOrange 
                      : AppColors.textSecondary,
                ),
                hintText: 'Select a building to manage QR codes',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              isExpanded: true,
              items: buildings.map((b) => DropdownMenuItem(
                value: b,
                child: Text(
                  b.name, 
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
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
            padding: EdgeInsets.all(20),
            child: Text(
              'Error loading buildings',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 16,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceDark.withOpacity(0.8),
            AppColors.cardDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryOrange, AppColors.primaryOrangeLight],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.qr_code_scanner_rounded, size: 20),
            text: 'QR Codes',
          ),
          Tab(
            icon: Icon(Icons.file_download_rounded, size: 20),
            text: 'Export',
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodesTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                  strokeWidth: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading navigation nodes...', 
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded, 
                  size: 40, 
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Error Loading Nodes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!, 
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadNavigationNodes(_selectedBuilding!.id),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_navigationNodes.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceDark,
                AppColors.cardDark,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded, 
                  size: 60, 
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Navigation Nodes Found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add nodes in Coordinate Collection first',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark,
            AppColors.surfaceDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Field
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.3),
                ),
              ),
              child: TextField(
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Search nodes...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded, 
                    color: AppColors.primaryOrange,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, 
                    vertical: 16,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const SizedBox(height: 16),
            // Filter Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.3),
                      ),
                    ),
                    child: DropdownButtonFormField<int?>(
                      value: _selectedFloor,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(
                        color: AppColors.textPrimary, 
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Floor',
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.layers_rounded,
                          color: AppColors.primaryOrange,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, 
                          vertical: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null, 
                          child: Text('All Floors')
                        ),
                        ...floors.map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            f == 0 ? 'Ground Floor' : 'Floor $f',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        )),
                      ],
                      onChanged: (value) => setState(() => _selectedFloor = value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.3),
                      ),
                    ),
                    child: DropdownButtonFormField<String?>(
                      value: _selectedNodeType,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(
                        color: AppColors.textPrimary, 
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.category_rounded,
                          color: AppColors.primaryOrange,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, 
                          vertical: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null, 
                          child: Text('All Types')
                        ),
                        ...nodeTypes.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        )),
                      ],
                      onChanged: (value) => setState(() => _selectedNodeType = value),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectAllBar(List<NavigationNodeData> filteredNodes) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _selectAll 
                  ? AppColors.primaryOrange.withOpacity(0.2) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectAll 
                    ? AppColors.primaryOrange 
                    : AppColors.textSecondary.withOpacity(0.3),
              ),
            ),
            child: Checkbox(
              value: _selectAll,
              activeColor: AppColors.primaryOrange,
              checkColor: Colors.white,
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
          ),
          const SizedBox(width: 12),
          Text(
            'Select All',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_selectedNodeIds.length}/${filteredNodes.length}',
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          if (_selectedNodeIds.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryOrange, AppColors.primaryOrangeLight],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: _exportSelectedNodes,
                icon: const Icon(
                  Icons.file_download_rounded, 
                  size: 18, 
                  color: Colors.white,
                ),
                label: Text(
                  'Export ${_selectedNodeIds.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(NavigationNodeData node) {
    final isSelected = _selectedNodeIds.contains(node.id);
    final qrData = 'indoor-nav://${_selectedBuilding!.id}/${node.id}';
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelected
              ? [AppColors.primaryOrange.withOpacity(0.1), AppColors.cardDark]
              : [AppColors.cardDark, AppColors.surfaceDark],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? AppColors.primaryOrange 
              : AppColors.textSecondary.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? AppColors.primaryOrange.withOpacity(0.2) 
                : Colors.black.withOpacity(0.1),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primaryOrange.withOpacity(0.3) 
                  : AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primaryOrange 
                    : AppColors.textSecondary.withOpacity(0.3),
              ),
            ),
            child: Checkbox(
              value: isSelected,
              activeColor: AppColors.primaryOrange,
              checkColor: Colors.white,
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
          ),
          title: Text(
            node.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _buildNodeTypeBadge(node.nodeType),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    node.floorNumber == 0 ? 'GROUND' : 'FLOOR ${node.floorNumber}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // QR Code Section Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'QR Code Preview',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // QR Code Display
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              node.label,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              node.floorNumber == 0 ? 'Ground Floor' : 'Floor ${node.floorNumber}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Node Details Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_rounded,
                                color: AppColors.primaryOrange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Node Details',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailSection(node, qrData),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    _buildActionButtons(node, qrData),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeTypeBadge(String nodeType) {
    Color color;
    IconData icon;
    
    switch (nodeType.toLowerCase()) {
      case 'entrance':
        color = const Color(0xFF4CAF50);
        icon = Icons.door_front_door_rounded;
        break;
      case 'exit':
        color = const Color(0xFFF44336);
        icon = Icons.exit_to_app_rounded;
        break;
      case 'elevator':
        color = const Color(0xFF2196F3);
        icon = Icons.elevator_rounded;
        break;
      case 'stairs':
        color = const Color(0xFFFF9800);
        icon = Icons.stairs_rounded;
        break;
      case 'bathroom':
      case 'restroom':
        color = const Color(0xFF9C27B0);
        icon = Icons.wc_rounded;
        break;
      case 'room':
        color = const Color(0xFF009688);
        icon = Icons.meeting_room_rounded;
        break;
      default:
        color = AppColors.primaryOrange;
        icon = Icons.location_on_rounded;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            nodeType.toUpperCase(),
            style: TextStyle(
              color: color, 
              fontSize: 11, 
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(NavigationNodeData node, String qrData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceDark.withOpacity(0.8),
            AppColors.cardDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            Icons.vpn_key_rounded, 
            'Node ID', 
            node.id,
            AppColors.primaryOrange
          ),
          _buildDetailRow(
            Icons.qr_code_rounded, 
            'QR Code Data', 
            qrData,
            const Color(0xFF4CAF50)
          ),
          _buildDetailRow(
            Icons.location_on_rounded, 
            'Latitude', 
            node.latitude.toStringAsFixed(7),
            const Color(0xFF2196F3)
          ),
          _buildDetailRow(
            Icons.location_on_rounded, 
            'Longitude', 
            node.longitude.toStringAsFixed(7),
            const Color(0xFF2196F3)
          ),
          _buildDetailRow(
            Icons.layers_rounded, 
            'Floor', 
            node.floorNumber.toString(),
            const Color(0xFFFF9800)
          ),
          if (node.landmarkDescription != null && node.landmarkDescription!.isNotEmpty)
            _buildDetailRow(
              Icons.place_rounded, 
              'Landmark', 
              node.landmarkDescription!,
              const Color(0xFF9C27B0)
            ),
          _buildDetailRow(
            node.isAccessible 
                ? Icons.check_circle_rounded 
                : Icons.cancel_rounded, 
            'Accessible', 
            node.isAccessible ? 'Yes' : 'No',
            node.isAccessible 
                ? const Color(0xFF4CAF50) 
                : const Color(0xFFF44336)
          ),
          _buildDetailRow(
            node.isEmergencyExit 
                ? Icons.emergency_rounded 
                : Icons.emergency_share_rounded, 
            'Emergency Exit', 
            node.isEmergencyExit ? 'Yes' : 'No',
            node.isEmergencyExit 
                ? const Color(0xFFF44336) 
                : const Color(0xFF607D8B)
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(NavigationNodeData node, String qrData) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.surfaceDark.withOpacity(0.8),
            AppColors.cardDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  color: AppColors.primaryOrange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy QR Data',
                    color: AppColors.primaryOrange,
                    onPressed: () => _copyToClipboard(qrData),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: const Color(0xFF4CAF50),
                    onPressed: () => _shareNode(node, qrData),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.print_rounded,
                    label: 'Print',
                    color: const Color(0xFF2196F3),
                    onPressed: () => _printSingleQR(node, qrData),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportTab() {
<<<<<<< HEAD
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
=======
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceDark,
              AppColors.cardDark,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.textSecondary.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryOrange, AppColors.primaryOrangeLight],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.file_download_rounded,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Export QR Codes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Use the QR Codes tab to select and export navigation nodes',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: AppColors.primaryOrange,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Select nodes in the QR Codes tab to enable export',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceDark,
              AppColors.cardDark,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.textSecondary.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_rounded,
                size: 60,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select a Building',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose a building from the dropdown above to manage its QR codes',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.primaryOrange,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Building selection is required to get started',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryOrange, AppColors.primaryOrangeLight],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _exportSelectedNodes(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(
          Icons.file_download_rounded,
          color: Colors.white,
        ),
        label: Text(
          'Export ${_selectedNodeIds.isEmpty ? "All" : _selectedNodeIds.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  List<NavigationNodeData> _getFilteredNodes() {
    return _navigationNodes.where((node) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!node.label.toLowerCase().contains(query) &&
            !node.id.toLowerCase().contains(query) &&
            !node.nodeType.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Floor filter
      if (_selectedFloor != null && node.floorNumber != _selectedFloor) {
        return false;
      }
      
      // Type filter
      if (_selectedNodeType != null && node.nodeType != _selectedNodeType) {
        return false;
      }
      
      return true;
    }).toList();
  }

  Future<void> _loadNavigationNodes(String buildingId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/admin/buildings/$buildingId/navigation-graph'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nodes = data['nodes'] as List;
        
        setState(() {
          _navigationNodes = nodes
              .map((n) => NavigationNodeData.fromJson(n))
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load navigation nodes: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading nodes: $e';
        _isLoading = false;
      });
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('QR Code Management Help', style: TextStyle(color: AppColors.textPrimary)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How to use:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. Select a building from the dropdown', style: TextStyle(color: AppColors.textSecondary)),
              Text('2. Browse and filter navigation nodes', style: TextStyle(color: AppColors.textSecondary)),
              Text('3. Select nodes to export or print', style: TextStyle(color: AppColors.textSecondary)),
              Text('4. Use the action buttons to copy, share, or print QR codes', style: TextStyle(color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('QR Code Format:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('indoor-nav://[building-id]/[node-id]', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'monospace')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppColors.primaryOrange)),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          backgroundColor: AppColors.primaryOrange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareNode(NavigationNodeData node, String qrData) async {
    try {
      await Share.share(
        'Navigation Node: ${node.label}\n'
        'Floor: ${node.floorNumber == 0 ? "Ground" : node.floorNumber}\n'
        'Type: ${node.nodeType}\n'
        'QR Code: $qrData',
        subject: 'Navigation Node - ${node.label}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _printSingleQR(NavigationNodeData node, String qrData) async {
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  data: qrData,
                  barcode: pw.Barcode.qrCode(),
                  width: 200,
                  height: 200,
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  node.label,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Floor: ${node.floorNumber == 0 ? "Ground" : node.floorNumber}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  'Type: ${node.nodeType}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportSelectedNodes() async {
    final nodesToExport = _selectedNodeIds.isEmpty
        ? _navigationNodes
        : _navigationNodes.where((n) => _selectedNodeIds.contains(n.id)).toList();

    if (nodesToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No nodes to export'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      
      for (var node in nodesToExport) {
        final qrData = 'indoor-nav://${_selectedBuilding!.id}/${node.id}';
        
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.BarcodeWidget(
                    data: qrData,
                    barcode: pw.Barcode.qrCode(),
                    width: 200,
                    height: 200,
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    node.label,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Floor: ${node.floorNumber == 0 ? "Ground" : node.floorNumber}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.Text(
                    'Type: ${node.nodeType}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${nodesToExport.length} QR codes'),
            backgroundColor: AppColors.primaryOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
>>>>>>> 969f15b (Add proximity detection system and update admin dashboard)
