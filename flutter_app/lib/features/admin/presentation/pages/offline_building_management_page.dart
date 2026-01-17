import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/offline/presentation/bloc/offline_bloc.dart';
import 'package:indoor_navigation/models/offline_building.dart';
import 'package:indoor_navigation/core/services/connectivity_service.dart';
import 'package:indoor_navigation/core/services/offline_sync_service.dart';
import 'package:indoor_navigation/core/widgets/connectivity_indicator.dart';
import 'package:indoor_navigation/core/di/injection_container.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/features/offline/presentation/pages/offline_building_creation_page.dart';
import 'package:indoor_navigation/features/offline/data/repositories/offline_repository.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';

class OfflineBuildingManagementPage extends StatefulWidget {
  const OfflineBuildingManagementPage({super.key});

  @override
  State<OfflineBuildingManagementPage> createState() => _OfflineBuildingManagementPageState();
}

class _OfflineBuildingManagementPageState extends State<OfflineBuildingManagementPage>
    with SingleTickerProviderStateMixin {
  late final ConnectivityService _connectivityService;
  late final OfflineSyncService _syncService;
  late final OfflineRepository _offlineRepository;
  late TabController _tabController;
  StreamSubscription<Map<String, dynamic>>? _syncStatusSubscription;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivityService = getIt<ConnectivityService>();
    _syncService = getIt<OfflineSyncService>();
    _offlineRepository = getIt<OfflineRepository>();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load offline buildings
    _loadData();
    
    // Listen to auto-sync status
    _syncStatusSubscription = _offlineRepository.syncStatusStream.listen((status) {
      if (status['type'] == 'auto_sync_completed') {
        final results = status['results'] as Map<String, dynamic>?;
        final synced = results?['buildings_synced'] ?? 0;
        if (synced > 0) {
          Fluttertoast.showToast(
            msg: '✅ Auto-synced $synced building(s)!',
            backgroundColor: Colors.green,
          );
        }
        _loadData(); // Refresh the list
      } else if (status['type'] == 'auto_sync_started') {
        Fluttertoast.showToast(
          msg: '🔄 Auto-syncing ${status['pending_count']} building(s)...',
          backgroundColor: AppColors.primaryOrange,
        );
      }
    });
    
    // Listen to connectivity changes to trigger sync
    _connectivitySubscription = _connectivityService.statusStream.listen((status) {
      if (status == ConnectivityStatus.online) {
        // Trigger sync when coming online
        Future.delayed(const Duration(seconds: 2), () {
          context.read<OfflineBloc>().add(SyncOfflineDataEvent());
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _syncStatusSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _loadData() {
    context.read<OfflineBloc>().add(LoadOfflineBuildingsEvent());
    context.read<OfflineBloc>().add(LoadSyncLogsEvent());
  }

  String _formatArea(double area) {
    if (area < 1000) {
      return '${area.toStringAsFixed(0)} m²';
    } else {
      return '${(area / 1000).toStringAsFixed(2)} km²';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Offline Buildings'),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const ConnectivityIndicator(showLabel: true),
          const SizedBox(width: 8),
          StreamBuilder<Map<String, dynamic>>(
            stream: _syncService.syncStatusStream,
            builder: (context, snapshot) {
              final stats = _syncService.getStats();
              final pendingCount = stats['total_pending'] ?? 0;
              
              if (pendingCount > 0 && _connectivityService.isOnline) {
                return IconButton(
                  icon: Badge(
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.cloud_upload),
                  ),
                  onPressed: () => _syncService.syncNow(),
                  tooltip: 'Sync Now',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Buildings'),
            Tab(icon: Icon(Icons.history), text: 'Sync History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuildingsTab(),
          _buildSyncHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          AppNavigator.push(const OfflineBuildingCreationPage());
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Create Building'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBuildingsTab() {
    return BlocConsumer<OfflineBloc, OfflineState>(
      listener: (context, state) {
        if (state is OfflineBuildingCreated) {
          Fluttertoast.showToast(
            msg: 'Building "${state.building.name}" created!',
            backgroundColor: Colors.green,
          );
          _loadData();
        } else if (state is SyncCompleted) {
          final synced = state.results['buildings_synced'] ?? 0;
          Fluttertoast.showToast(
            msg: '$synced buildings synced successfully!',
            backgroundColor: Colors.green,
          );
          _loadData();
        } else if (state is OfflineError) {
          Fluttertoast.showToast(
            msg: state.message,
            backgroundColor: Colors.red,
          );
        } else if (state is OfflineBuildingDeleted) {
          Fluttertoast.showToast(
            msg: 'Building deleted',
            backgroundColor: Colors.orange,
          );
          _loadData();
        }
      },
      builder: (context, state) {
        if (state is OfflineLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'Loading offline buildings...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        if (state is OfflineBuildingsLoaded) {
          return _buildBuildingsList(state.buildings);
        }

        // Default empty state
        return _buildEmptyState();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Offline Buildings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create buildings even without internet.\nThey will sync automatically when online.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              AppNavigator.push(const OfflineBuildingCreationPage());
            },
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Create Your First Building'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingsList(List<OfflineBuilding> buildings) {
    if (buildings.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate statistics
    final totalArea = buildings.fold<double>(0, (sum, b) => sum + b.area);
    final syncedCount = buildings.where((b) => b.isSynced).length;
    final pendingCount = buildings.length - syncedCount;

    return Column(
      children: [
        // Stats Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.deepOrange.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _StatItem(
                icon: Icons.business,
                value: '${buildings.length}',
                label: 'Buildings',
              ),
              Container(width: 1, height: 50, color: Colors.white30),
              _StatItem(
                icon: Icons.square_foot,
                value: _formatArea(totalArea),
                label: 'Total Area',
              ),
              Container(width: 1, height: 50, color: Colors.white30),
              _StatItem(
                icon: pendingCount > 0 ? Icons.cloud_upload : Icons.cloud_done,
                value: pendingCount > 0 ? '$pendingCount' : '✓',
                label: pendingCount > 0 ? 'Pending' : 'All Synced',
              ),
            ],
          ),
        ),

        // Sync Banner
        if (pendingCount > 0 && _connectivityService.isOnline)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryOrange),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload, color: AppColors.primaryOrange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$pendingCount buildings ready to sync',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.read<OfflineBloc>().add(SyncOfflineDataEvent());
                  },
                  child: const Text('SYNC NOW'),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Buildings List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadData(),
            color: Colors.orange,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: buildings.length,
              itemBuilder: (context, index) {
                return _BuildingCard(
                  building: buildings[index],
                  onDelete: () => _confirmDelete(buildings[index]),
                  onSync: () {
                    context.read<OfflineBloc>().add(SyncOfflineDataEvent());
                  },
                  formatArea: _formatArea,
                  formatDateTime: _formatDateTime,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(OfflineBuilding building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Delete Building?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${building.name}"?',
              style: const TextStyle(color: Colors.white70),
            ),
            if (!building.isSynced) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This building has NOT been synced and will be permanently lost!',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<OfflineBloc>().add(DeleteOfflineBuildingEvent(building.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncHistoryTab() {
    return BlocBuilder<OfflineBloc, OfflineState>(
      builder: (context, state) {
        if (state is SyncLogsLoaded) {
          final logs = state.logs;
          final stats = state.statistics;

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    'No Sync History',
                    style: TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sync logs will appear here after syncing',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Stats Cards
              Container(
                margin: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.check_circle,
                        value: '${stats['total_synced'] ?? 0}',
                        label: 'Synced',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.error,
                        value: '${stats['total_failed'] ?? 0}',
                        label: 'Failed',
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.pending,
                        value: '${stats['pending_buildings'] ?? 0}',
                        label: 'Pending',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),

              // Logs List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _SyncLogCard(log: log, formatDateTime: _formatDateTime);
                  },
                ),
              ),
            ],
          );
        }

        if (state is SyncInProgress) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        return const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final OfflineBuilding building;
  final VoidCallback onDelete;
  final VoidCallback onSync;
  final String Function(double) formatArea;
  final String Function(DateTime) formatDateTime;

  const _BuildingCard({
    required this.building,
    required this.onDelete,
    required this.onSync,
    required this.formatArea,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: building.isSynced 
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: building.isSynced 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: building.isSynced ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    building.isSynced ? Icons.cloud_done : Icons.cloud_off,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (building.description.isNotEmpty)
                        Text(
                          building.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: building.isSynced ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    building.isSynced ? 'Synced' : 'Pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Address
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white.withValues(alpha: 0.5), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        building.address,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats Row
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.square_foot,
                      label: formatArea(building.area),
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.location_on,
                      label: '${building.boundaryPoints.length} points',
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.access_time,
                      label: formatDateTime(building.createdAt),
                      color: Colors.teal,
                    ),
                  ],
                ),

                // Error Message
                if (building.syncError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            building.syncError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                if (!building.isSynced)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSync,
                      icon: const Icon(Icons.cloud_upload, size: 18),
                      label: const Text('Sync'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryOrange,
                        side: const BorderSide(color: AppColors.primaryOrange),
                      ),
                    ),
                  ),
                if (!building.isSynced) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncLogCard extends StatelessWidget {
  final dynamic log;
  final String Function(DateTime) formatDateTime;

  const _SyncLogCard({
    required this.log,
    required this.formatDateTime,
  });

  String _getEnumName(dynamic enumValue) {
    return enumValue.toString().split('.').last;
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    final statusName = _getEnumName(log.status);

    switch (statusName) {
      case 'success':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    final syncTypeName = _getEnumName(log.syncType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.itemName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${syncTypeName.toUpperCase()} • ${formatDateTime(log.timestamp)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                if (log.errorMessage != null)
                  Text(
                    log.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusName.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}