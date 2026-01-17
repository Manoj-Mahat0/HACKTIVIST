import 'package:equatable/equatable.dart';

class CoordinateGPS extends Equatable {
  final double latitude;
  final double longitude;
  final int floorNumber;

  const CoordinateGPS({
    required this.latitude,
    required this.longitude,
    required this.floorNumber,
  });

  @override
  List<Object?> get props => [latitude, longitude, floorNumber];

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'floor_number': floorNumber,
    };
  }
}