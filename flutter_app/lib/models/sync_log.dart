import 'package:hive/hive.dart';

part 'sync_log.g.dart';

enum SyncType {
  building,
  coordinate,
  waypoint,
}

enum SyncStatus {
  success,
  failed,
  pending,
}

@HiveType(typeId: 6)
class SyncLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int syncTypeIndex; // SyncType enum index

  @HiveField(2)
  final String itemId;

  @HiveField(3)
  final String itemName;

  @HiveField(4)
  final int statusIndex; // SyncStatus enum index

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final String? errorMessage;

  @HiveField(7)
  final Map<String, dynamic>? metadata;

  SyncLog({
    required this.id,
    required this.syncTypeIndex,
    required this.itemId,
    required this.itemName,
    required this.statusIndex,
    required this.timestamp,
    this.errorMessage,
    this.metadata,
  });

  SyncLog.withEnums({
    required this.id,
    required SyncType syncType,
    required this.itemId,
    required this.itemName,
    required SyncStatus status,
    required this.timestamp,
    this.errorMessage,
    this.metadata,
  }) : syncTypeIndex = syncType.index,
       statusIndex = status.index;

  SyncType get syncType => SyncType.values[syncTypeIndex];
  SyncStatus get status => SyncStatus.values[statusIndex];

  SyncLog copyWith({
    String? id,
    SyncType? syncType,
    String? itemId,
    String? itemName,
    SyncStatus? status,
    DateTime? timestamp,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return SyncLog(
      id: id ?? this.id,
      syncTypeIndex: syncType?.index ?? syncTypeIndex,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      statusIndex: status?.index ?? statusIndex,
      timestamp: timestamp ?? this.timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
    );
  }
}