import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/offline/presentation/bloc/offline_bloc.dart';
import 'package:indoor_navigation/models/offline_building.dart';
import 'package:indoor_navigation/models/sync_log.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/features/offline/presentation/pages/offline_building_creation_page.dart';
import 'package:fluttertoast/fluttertoast.dart';

class OfflineBuildingManagementPage extends StatefulWidget {
  const OfflineBuildingManagementPage({super.key});

  @override
  State<OfflineBuildingManagementPage> createState() => _OfflineBuildingManagementPageState();
}

class _OfflineBuildingManagementPageState extends State<OfflineBuildingManagementPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    // Only load offline buildings and sync logs - no network calls
    try {
      context.read<OfflineBloc>().add(LoadOfflineBuildingsEvent());
      context.read<OfflineBloc>().add(LoadSyncLogsEvent());
    } catch (e) {
      // Handle any initialization errors gracefully
      Fluttertoast.showToast(
        msg: 'Loading offline data...',
        backgroundColor: Colors.blue.shade600,
      );
    }
  }

  String _formatArea(double area) {
    if (area < 1000) {
      return '${area.toStringAsFixed(0)} m²';
    } else {
      return '${(area / 1000).toStringAsFixed(1)} km²';
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
      appBar: AppBar(
        title: const Text('Offline Buildings'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              context.read<OfflineBloc>().add(SyncOfflineDataEvent());
            },
            tooltip: 'Sync Now',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Buildings'),
            Tab(icon: Icon(Icons.sync), text: 'Sync Logs'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuildingsTab(),
          _buildSyncLogsTab(),
          _buildStatisticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          AppNavigator.push(const OfflineBuildingCreationPage());
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Offline'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBuildingsTab() {
    return BlocBuilder<OfflineBloc, OfflineState>(
      builder: (context, state) {
        if (state is OfflineLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading offline buildings...'),
              ],
            ),
          );
        }

        if (state is OfflineError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading buildings',
                  style: TextStyle(fontSize: 18, color: Colors.red.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is OfflineBuildingsLoaded) {
          final buildings = state.buildings;
          
          if (buildings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No offline buildings',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create buildings offline when you don\'t have internet',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      AppNavigator.push(const OfflineBuildingCreationPage());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Building'),
                  ),
                ],
              ),
            );
          }

          // Calculate statistics
          final totalArea = buildings.fold<double>(0, (sum, building) => sum + building.area);
          final syncedCount = buildings.where((b) => b.isSynced).length;
          final pendingCount = buildings.length - syncedCount;

          return Column(
            children: [
              // Overview Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade600, Colors.orange.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Offline Buildings',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${buildings.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: Colors.white30,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Area',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatArea(totalArea),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sync Status Card
              if (pendingCount > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync_problem, color: Colors.amber.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pendingCount buildings pending sync',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            Text(
                              'Tap sync button to upload when online',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<OfflineBloc>().add(SyncOfflineDataEvent());
                        },
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Sync'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Buildings List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    context.read<OfflineBloc>().add(LoadOfflineBuildingsEvent());
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: buildings.length,
                    itemBuilder: (context, index) {
                      final building = buildings[index];
                      return _buildBuildingCard(building);
                    },
                  ),
                ),
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBuildingCard(OfflineBuilding building) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBuildingOptions(building),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: building.isSynced 
                          ? Colors.green.shade50 
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      building.isSynced ? Icons.cloud_done : Icons.cloud_off,
                      color: building.isSynced 
                          ? Colors.green.shade700 
                          : Colors.orange.shade700,
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (building.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            building.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: building.isSynced 
                          ? Colors.green.shade50 
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      building.isSynced ? 'Synced' : 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: building.isSynced 
                            ? Colors.green.shade700 
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Address',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      building.address,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.square_foot,
                    label: 'Area',
                    value: _formatArea(building.area),
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.location_on,
                    label: 'Points',
                    value: '${building.boundaryPoints.length}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.access_time,
                    label: 'Created',
                    value: _formatDateTime(building.createdAt),
                    color: Colors.purple,
                  ),
                ],
              ),
              if (building.syncError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sync failed: ${building.syncError}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncLogsTab() {
    return BlocBuilder<OfflineBloc, OfflineState>(
      builder: (context, state) {
        if (state is SyncLogsLoaded) {
          final logs = state.logs;
          
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No sync history',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sync logs will appear here after syncing offline data',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<OfflineBloc>().add(LoadSyncLogsEvent());
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _buildSyncLogCard(log);
              },
            ),
          );
        }

        if (state is SyncInProgress) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(state.message),
              ],
            ),
          );
        }

        if (state is SyncCompleted) {
          // Show sync results and reload logs
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<OfflineBloc>().add(LoadSyncLogsEvent());
            _showSyncResults(state.results);
          });
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildSyncLogCard(SyncLog log) {
    Color statusColor;
    IconData statusIcon;
    
    switch (log.status) {
      case SyncStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case SyncStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case SyncStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          log.itemName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${log.syncType.name.toUpperCase()} • ${_formatDateTime(log.timestamp)}'),
            if (log.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                log.errorMessage!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            log.status.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return BlocBuilder<OfflineBloc, OfflineState>(
      builder: (context, state) {
        if (state is SyncLogsLoaded) {
          final stats = state.statistics;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Statistics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Synced',
                        value: '${stats['total_synced'] ?? 0}',
                        icon: Icons.cloud_done,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Failed',
                        value: '${stats['total_failed'] ?? 0}',
                        icon: Icons.error,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Today Synced',
                        value: '${stats['today_synced'] ?? 0}',
                        icon: Icons.today,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Pending',
                        value: '${stats['pending_buildings'] ?? 0}',
                        icon: Icons.schedule,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.sync, color: Colors.blue.shade700),
                          ),
                          title: const Text('Sync All Offline Data'),
                          subtitle: const Text('Upload all pending buildings to server'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            context.read<OfflineBloc>().add(SyncOfflineDataEvent());
                          },
                        ),
                        
                        const Divider(),
                        
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add, color: Colors.orange.shade700),
                          ),
                          title: const Text('Create Offline Building'),
                          subtitle: const Text('Create new building without internet'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            AppNavigator.push(const OfflineBuildingCreationPage());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  void _showBuildingOptions(OfflineBuilding building) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: building.isSynced 
                        ? Colors.green.shade50 
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    building.isSynced ? Icons.cloud_done : Icons.cloud_off,
                    color: building.isSynced 
                        ? Colors.green.shade700 
                        : Colors.orange.shade700,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        building.isSynced ? 'Synced to server' : 'Offline building',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (!building.isSynced) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.sync, color: Colors.blue.shade700),
                ),
                title: const Text('Sync Now'),
                subtitle: const Text('Upload this building to server'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<OfflineBloc>().add(SyncOfflineDataEvent());
                },
              ),
              const SizedBox(height: 8),
            ],
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info, color: Colors.green.shade700),
              ),
              title: const Text('View Details'),
              subtitle: const Text('See building information'),
              onTap: () {
                Navigator.pop(context);
                _showBuildingDetails(building);
              },
            ),
            const SizedBox(height: 8),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete, color: Colors.red.shade700),
              ),
              title: const Text('Delete Building'),
              subtitle: const Text('Remove from offline storage'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteBuilding(building);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showBuildingDetails(OfflineBuilding building) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: building.isSynced 
                            ? Colors.green.shade50 
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        building.isSynced ? Icons.cloud_done : Icons.cloud_off,
                        color: building.isSynced 
                            ? Colors.green.shade700 
                            : Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        building.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailRow('Description', building.description.isNotEmpty ? building.description : 'No description'),
                _DetailRow('Address', building.address),
                _DetailRow('Area', _formatArea(building.area)),
                _DetailRow('Boundary Points', '${building.boundaryPoints.length} points'),
                _DetailRow('Coordinates', '${building.latitude.toStringAsFixed(6)}, ${building.longitude.toStringAsFixed(6)}'),
                _DetailRow('Created', _formatDateTime(building.createdAt)),
                _DetailRow('Status', building.isSynced ? 'Synced' : 'Pending sync'),
                if (building.syncedAt != null)
                  _DetailRow('Synced At', _formatDateTime(building.syncedAt!)),
                if (building.syncError != null)
                  _DetailRow('Sync Error', building.syncError!),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    if (!building.isSynced) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<OfflineBloc>().add(SyncOfflineDataEvent());
                        },
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteBuilding(OfflineBuilding building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${building.name}"?'),
            const SizedBox(height: 8),
            if (!building.isSynced)
              const Text(
                'This building has not been synced to the server and will be permanently lost.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
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
              Fluttertoast.showToast(
                msg: 'Building deleted',
                backgroundColor: Colors.red.shade600,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSyncResults(Map<String, dynamic> results) {
    final syncedCount = results['buildings_synced'] ?? 0;
    final failedCount = results['buildings_failed'] ?? 0;
    final errors = List<String>.from(results['errors'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              syncedCount > 0 ? Icons.check_circle : Icons.error,
              color: syncedCount > 0 ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Sync Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (syncedCount > 0) ...[
              Text('✅ $syncedCount buildings synced successfully'),
              const SizedBox(height: 8),
            ],
            if (failedCount > 0) ...[
              Text('❌ $failedCount buildings failed to sync'),
              const SizedBox(height: 8),
            ],
            if (errors.isNotEmpty) ...[
              const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...errors.map((error) => Text('• $error', style: const TextStyle(fontSize: 12))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}