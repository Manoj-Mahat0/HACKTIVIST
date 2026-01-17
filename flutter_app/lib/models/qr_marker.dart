import 'package:hive/hive.dart';

part 'qr_marker.g.dart';

@HiveType(typeId: 4)
class QRMarker extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String buildingId;

  @HiveField(2)
  final String floorId;

  @HiveField(3)
  final double x;

  @HiveField(4)
  final double y;

  @HiveField(5)
  final double orientationDegrees;

  @HiveField(6)
  final String qrData; // Encoded position data

  @HiveField(7)
  final String? description;

  QRMarker({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.x,
    required this.y,
    required this.orientationDegrees,
    required this.qrData,
    this.description,
  });

  QRMarker copyWith({
    String? id,
    String? buildingId,
    String? floorId,
    double? x,
    double? y,
    double? orientationDegrees,
    String? qrData,
    String? description,
  }) {
    return QRMarker(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      floorId: floorId ?? this.floorId,
      x: x ?? this.x,
      y: y ?? this.y,
      orientationDegrees: orientationDegrees ?? this.orientationDegrees,
      qrData: qrData ?? this.qrData,
      description: description ?? this.description,
    );
  }
}
