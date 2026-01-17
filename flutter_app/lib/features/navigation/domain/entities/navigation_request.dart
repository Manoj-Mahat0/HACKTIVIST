import 'package:equatable/equatable.dart';

class NavigationRequest extends Equatable {
  final String buildingId;
  final double startLatitude;
  final double startLongitude;
  final int startFloor;
  final String destinationRoomName;

  const NavigationRequest({
    required this.buildingId,
    required this.startLatitude,
    required this.startLongitude,
    required this.startFloor,
    required this.destinationRoomName,
  });

  @override
  List<Object?> get props => [
    buildingId,
    startLatitude,
    startLongitude,
    startFloor,
    destinationRoomName,
  ];

  Map<String, dynamic> toJson() {
    return {
      'building_id': buildingId,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'start_floor': startFloor,
      'destination_room_name': destinationRoomName,
    };
  }
}