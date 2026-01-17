import 'package:hive/hive.dart';

part 'offline_building.g.dart';

@HiveType(typeId: 5)
class OfflineBuilding extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String address;

  @HiveField(4)
  final double latitude;

  @HiveField(5)
  final double longitude;

  @HiveField(6)
  final List<Map<String, double>> boundaryPoints;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final bool isSynced;

  @HiveField(9)
  final DateTime? syncedAt;

  @HiveField(10)
  final String? syncError;

  OfflineBuilding({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.boundaryPoints,
    required this.createdAt,
    this.isSynced = false,
    this.syncedAt,
    this.syncError,
  });

  OfflineBuilding copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    List<Map<String, double>>? boundaryPoints,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? syncedAt,
    String? syncError,
  }) {
    return OfflineBuilding(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      syncError: syncError ?? this.syncError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'boundary_points': boundaryPoints,
    };
  }

  double get area {
    if (boundaryPoints.length < 3) return 0;
    
    double area = 0;
    for (int i = 0; i < boundaryPoints.length; i++) {
      int j = (i + 1) % boundaryPoints.length;
      final point1 = boundaryPoints[i];
      final point2 = boundaryPoints[j];
      
      area += (point1['lat']!) * (point2['lng']!);
      area -= (point2['lat']!) * (point1['lng']!);
    }
    return (area.abs() / 2) * 111000 * 111000; // Convert to square meters
  }
}