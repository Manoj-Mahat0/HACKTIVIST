import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/offline_bloc.dart';

class OfflineDownloadsPage extends StatefulWidget {
  const OfflineDownloadsPage({super.key});

  @override
  _OfflineDownloadsPageState createState() => _OfflineDownloadsPageState();
}

class _OfflineDownloadsPageState extends State<OfflineDownloadsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load data
    context.read<OfflineBloc>().add(LoadAvailableBuildingsEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Downloads'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available', icon: Icon(Icons.cloud_download)),
            Tab(text: 'Downloaded', icon: Icon(Icons.offline_pin)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableTab(),
          _buildDownloadedTab(),
        ],
      ),
    );
  }

  Widget _buildAvailableTab() {
    return BlocConsumer<OfflineBloc, OfflineState>(
      listener: (context, state) {
        if (state is BuildingDownloaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${state.buildingName} downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload available buildings
          context.read<OfflineBloc>().add(LoadAvailableBuildingsEvent());
        } else if (state is OfflineError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is OfflineLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is BuildingDownloading) {
          return _buildDownloadingView(state);
        }

        if (state is AvailableBuildingsLoaded) {
          if (state.buildings.isEmpty) {
            return _buildEmptyState('No buildings available for download');
          }
          return _buildAvailableBuildingsList(state.buildings);
        }

        return _buildEmptyState('Tap refresh to load buildings');
      },
    );
  }

  Widget _buildDownloadedTab() {
    return BlocConsumer<OfflineBloc, OfflineState>(
      listener: (context, state) {
        if (state is BuildingDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Building deleted successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          // Reload downloaded buildings
          context.read<OfflineBloc>().add(LoadDownloadedBuildingsEvent());
        }
      },
      builder: (context, state) {
        if (state is OfflineLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DownloadedBuildingsLoaded) {
          if (state.buildings.isEmpty) {
            return _buildEmptyState('No downloaded buildings');
          }
          return _buildDownloadedBuildingsList(state.buildings);
        }

        // Load downloaded buildings on first render
        Future.microtask(() {
          if (state is! DownloadedBuildingsLoaded) {
            context.read<OfflineBloc>().add(LoadDownloadedBuildingsEvent());
          }
        });

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildDownloadingView(BuildingDownloading state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_download, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              'Downloading ${state.buildingName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: state.progress,
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            Text(
              '${(state.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableBuildingsList(List<Map<String, dynamic>> buildings) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<OfflineBloc>().add(LoadAvailableBuildingsEvent());
      },
      child: ListView.builder(
        itemCount: buildings.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final building = buildings[index];
          return _buildAvailableBuildingCard(building);
        },
      ),
    );
  }

  Widget _buildAvailableBuildingCard(Map<String, dynamic> building) {
    final isReady = building['is_ready_for_offline'] ?? false;
    final sizeKb = building['estimated_size_kb'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        building['address'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isReady)
                  Chip(
                    label: const Text('Not Ready', style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.orange[100],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.layers, '${building['floors_count']} floors'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.room, '${building['rooms_count']} rooms'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.navigation, '${building['waypoints_count']} points'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Size: ~${sizeKb}KB',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                ElevatedButton.icon(
                  onPressed: isReady
                      ? () {
                          context.read<OfflineBloc>().add(
                                DownloadBuildingEvent(
                                  building['id'],
                                  building['name'],
                                ),
                              );
                        }
                      : null,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadedBuildingsList(List buildings) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<OfflineBloc>().add(LoadDownloadedBuildingsEvent());
      },
      child: ListView.builder(
        itemCount: buildings.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final building = buildings[index];
          return _buildDownloadedBuildingCard(building);
        },
      ),
    );
  }

  Widget _buildDownloadedBuildingCard(building) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.offline_pin, color: Colors.green),
                const SizedBox(width: 8),
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
                      const SizedBox(height: 4),
                      Text(
                        building.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Downloaded: ${_formatDate(building.downloadedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _showDeleteConfirmation(building.id, building.name);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, building.id);
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.blue[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<OfflineBloc>().add(LoadAvailableBuildingsEvent());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String buildingId, String buildingName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building'),
        content: Text('Are you sure you want to delete "$buildingName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<OfflineBloc>().add(DeleteBuildingEvent(buildingId));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
