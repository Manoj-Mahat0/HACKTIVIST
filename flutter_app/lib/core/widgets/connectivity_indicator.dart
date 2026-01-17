import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../di/injection_container.dart';

class ConnectivityIndicator extends StatefulWidget {
  final bool showLabel;
  final double size;

  const ConnectivityIndicator({
    super.key,
    this.showLabel = false,
    this.size = 12.0,
  });

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  late final ConnectivityService _connectivityService;
  ConnectivityStatus _currentStatus = ConnectivityStatus.offline;

  @override
  void initState() {
    super.initState();
    _connectivityService = getIt<ConnectivityService>();
    _currentStatus = _connectivityService.currentStatus;
    
    // Listen to connectivity changes
    _connectivityService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _currentStatus == ConnectivityStatus.online;
    final statusText = _currentStatus.name.toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.showLabel ? 8.0 : 4.0,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: isOnline 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline 
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? Colors.green : Colors.red).withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late final ConnectivityService _connectivityService;
  ConnectivityStatus _currentStatus = ConnectivityStatus.offline;

  @override
  void initState() {
    super.initState();
    _connectivityService = getIt<ConnectivityService>();
    _currentStatus = _connectivityService.currentStatus;
    
    // Listen to connectivity changes
    _connectivityService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _currentStatus == ConnectivityStatus.online;

    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline. Some features may be limited.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }
}