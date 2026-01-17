import 'package:hive/hive.dart';

part 'building.g.dart';

@HiveType(typeId: 0)
class Building extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String address;

  @HiveField(3)
  final DateTime downloadedAt;

  @HiveField(4)
  final int version;

  @HiveField(5)
  final List<Map<String, double>> boundaryPoints;

  Building({
    required this.id,
    required this.name,
    required this.address,
    required this.downloadedAt,
    required this.version,
    this.boundaryPoints = const [],
  });

  Building copyWith({
    String? id,
    String? name,
    String? address,
    DateTime? downloadedAt,
    int? version,
    List<Map<String, double>>? boundaryPoints,
  }) {
    return Building(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      version: version ?? this.version,
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
    );
  }
}
