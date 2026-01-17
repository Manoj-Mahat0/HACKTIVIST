import 'package:hive/hive.dart';

part 'room.g.dart';

@HiveType(typeId: 2)
class Room extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String floorId;

  @HiveField(2)
  final String buildingId;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String type; // office, bathroom, corridor, etc

  @HiveField(5)
  final double x; // Local X coordinate (meters)

  @HiveField(6)
  final double y; // Local Y coordinate (meters)

  @HiveField(7)
  final double width;

  @HiveField(8)
  final double height;

  @HiveField(9)
  final String? entranceNodeId; // Connected to nav graph

  Room({
    required this.id,
    required this.floorId,
    required this.buildingId,
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.entranceNodeId,
  });

  Room copyWith({
    String? id,
    String? floorId,
    String? buildingId,
    String? name,
    String? type,
    double? x,
    double? y,
    double? width,
    double? height,
    String? entranceNodeId,
  }) {
    return Room(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      buildingId: buildingId ?? this.buildingId,
      name: name ?? this.name,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      entranceNodeId: entranceNodeId ?? this.entranceNodeId,
    );
  }
}
