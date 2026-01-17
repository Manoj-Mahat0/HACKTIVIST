import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../di/injection_container.dart';

class ConnectivityStatusWidget extends StatefulWidget {
  final bool showDetails;
  final EdgeInsets? padding;

  const ConnectivityStatusWidget({
    super.key,
    this.showDetails = false,
    this.padding,
  });

  @override
  State<ConnectivityStatusWidget> createState() => _ConnectivityStatusWidgetState();
}

class _ConnectivityStatusWidgetState extends State<ConnectivityStatusWidget> {
  late final ConnectivityService _connectivityService;
  late final ApiService _apiService;
  late final OfflineSyncService _offlineSyncService;
  
  ConnectivityStatus _currentStatus = ConnectivityStatus.offline;
  Map<String, dynamic> _serviceStatus = {};
  Map<String, dynamic> _syncStats = {};

  @override
  void initState() {
    super.initState();
    _connectivityService = getIt<ConnectivityService>();
    _apiService = getIt<ApiService>();
    _offlineSyncService = getIt<OfflineSyncService>();
    
    _currentStatus = _connectivityService.currentStatus;
    _updateStatus();
    
    // Listen to connectivity changes
    _connectivityService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
        _updateStatus();
      }
    });
    
    // Listen to sync status changes
    _offlineSyncService.syncStatusStream.listen((status) {
      if (mounted) {
        _updateSyncStats();
      }
    });
  }

  Future<void> _updateStatus() async {
    try {
      final serviceStatus = await _apiService.getServiceStatus();
      final syncStats = _offlineSyncService.getStats();
      
      if (mounted) {
        setState(() {
          _serviceStatus = serviceStatus;
          _syncStats = syncStats;
        });
      }
    } catch (e) {
      print('Failed to update status: $e');
    }
  }

  Future<void> _updateSyncStats() async {
    try {
      final syncStats = _offlineSyncService.getStats();
      if (mounted) {
        setState(() {
          _syncStats = syncStats;
        });
      }
    } catch (e) {
      print('Failed to update sync stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showDetails) {
      return _buildCompactStatus();
    }
    
    return _buildDetailedStatus();
  }

  Widget _buildCompactStatus() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (_currentStatus) {
      case ConnectivityStatus.online:
        statusColor = Colors.green;
        statusIcon = Icons.cloud_done;
        statusText = 'Online';
        break;
      case ConnectivityStatus.limited:
        statusColor = Colors.orange;
        statusIcon = Icons.cloud_off;
        statusText = 'Limited';
        break;
      case ConnectivityStatus.offline:
        statusColor = Colors.red;
        statusIcon = Icons.cloud_off;
        statusText = 'Offline';
        break;
    }

    final pendingCount = _syncStats['total_pending'] ?? 0;
    
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (pendingCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedStatus() {
    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.network_check,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Connection Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _updateStatus,
                tooltip: 'Refresh Status',
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Connectivity Status
          _StatusRow(
            icon: _getConnectivityIcon(),
            label: 'Network',
            value: _currentStatus.name.toUpperCase(),
            color: _getConnectivityColor(),
          ),
          
          // Backend Status
          _StatusRow(
            icon: Icons.dns,
            label: 'Backend',
            value: (_serviceStatus['backend_available'] == true) ? 'AVAILABLE' : 'UNAVAILABLE',
            color: (_serviceStatus['backend_available'] == true) ? Colors.green : Colors.red,
          ),
          
          // Sync Status
          if (_syncStats.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(Icons.sync, color: Colors.purple.shade700, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Sync Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            _StatusRow(
              icon: Icons.pending_actions,
              label: 'Pending',
              value: '${_syncStats['total_pending'] ?? 0}',
              color: (_syncStats['total_pending'] ?? 0) > 0 ? Colors.orange : Colors.green,
            ),
            
            _StatusRow(
              icon: Icons.sync_alt,
              label: 'Syncing',
              value: (_syncStats['is_syncing'] == true) ? 'YES' : 'NO',
              color: (_syncStats['is_syncing'] == true) ? Colors.blue : Colors.grey,
            ),
            
            if ((_syncStats['total_pending'] ?? 0) > 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _offlineSyncService.syncNow();
                    _updateSyncStats();
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _getConnectivityIcon() {
    switch (_currentStatus) {
      case ConnectivityStatus.online:
        return Icons.wifi;
      case ConnectivityStatus.limited:
        return Icons.wifi_off;
      case ConnectivityStatus.offline:
        return Icons.wifi_off;
    }
  }

  Color _getConnectivityColor() {
    switch (_currentStatus) {
      case ConnectivityStatus.online:
        return Colors.green;
      case ConnectivityStatus.limited:
        return Colors.orange;
      case ConnectivityStatus.offline:
        return Colors.red;
    }
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}