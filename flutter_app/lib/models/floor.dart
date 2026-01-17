import 'package:hive/hive.dart';

part 'floor.g.dart';

@HiveType(typeId: 1)
class Floor extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String buildingId;

  @HiveField(2)
  final int floorNumber;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String? floorPlanImagePath; // Local file path

  @HiveField(5)
  final double width; // meters

  @HiveField(6)
  final double height; // meters

  @HiveField(7)
  final double originX; // Local coordinate origin

  @HiveField(8)
  final double originY;

  Floor({
    required this.id,
    required this.buildingId,
    required this.floorNumber,
    required this.name,
    this.floorPlanImagePath,
    required this.width,
    required this.height,
    required this.originX,
    required this.originY,
  });

  Floor copyWith({
    String? id,
    String? buildingId,
    int? floorNumber,
    String? name,
    String? floorPlanImagePath,
    double? width,
    double? height,
    double? originX,
    double? originY,
  }) {
    return Floor(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      floorNumber: floorNumber ?? this.floorNumber,
      name: name ?? this.name,
      floorPlanImagePath: floorPlanImagePath ?? this.floorPlanImagePath,
      width: width ?? this.width,
      height: height ?? this.height,
      originX: originX ?? this.originX,
      originY: originY ?? this.originY,
    );
  }
}
