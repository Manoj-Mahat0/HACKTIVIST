import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:indoor_navigation/features/admin/domain/entities/coordinate_gps.dart';
import 'package:indoor_navigation/features/admin/domain/entities/analytics.dart';
import 'package:indoor_navigation/features/admin/domain/usecases/generate_3d_model_usecase.dart';
import 'package:indoor_navigation/features/admin/domain/usecases/get_analytics_usecase.dart';
import 'package:indoor_navigation/features/admin/domain/usecases/get_building_structure_usecase.dart';
import 'package:indoor_navigation/features/admin/presentation/widgets/building_3d_preview_dialog.dart';

// Events
abstract class AdminEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAnalyticsEvent extends AdminEvent {}

class Generate3DModelEvent extends AdminEvent {
  final String buildingId;
  final List<CoordinateGPS> coordinates;

  Generate3DModelEvent({
    required this.buildingId,
    required this.coordinates,
  });

  @override
  List<Object?> get props => [buildingId, coordinates];
}

class LoadBuildingStructureEvent extends AdminEvent {
  final String buildingId;

  LoadBuildingStructureEvent({required this.buildingId});

  @override
  List<Object?> get props => [buildingId];
}

// States
abstract class AdminState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminInitialState extends AdminState {}

class AdminLoadingState extends AdminState {}

class AnalyticsLoadedState extends AdminState {
  final Analytics analytics;

  AnalyticsLoadedState({required this.analytics});

  @override
  List<Object?> get props => [analytics];
}

class Model3DGeneratedState extends AdminState {
  final Map<String, dynamic> result;

  Model3DGeneratedState({required this.result});

  @override
  List<Object?> get props => [result];
}

class BuildingStructureLoadedState extends AdminState {
  final List<FloorData> floors;

  BuildingStructureLoadedState({required this.floors});

  @override
  List<Object?> get props => [floors];
}

class AdminErrorState extends AdminState {
  final String message;

  AdminErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}

// Bloc
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final Generate3DModelUseCase generate3DModelUseCase;
  final GetAnalyticsUseCase getAnalyticsUseCase;
  final GetBuildingStructureUseCase getBuildingStructureUseCase;

  AdminBloc({
    required this.generate3DModelUseCase,
    required this.getAnalyticsUseCase,
    required this.getBuildingStructureUseCase,
  }) : super(AdminInitialState()) {
    on<LoadAnalyticsEvent>(_onLoadAnalytics);
    on<Generate3DModelEvent>(_onGenerate3DModel);
    on<LoadBuildingStructureEvent>(_onLoadBuildingStructure);
  }

  Future<void> _onLoadAnalytics(
    LoadAnalyticsEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoadingState());
    try {
      final analytics = await getAnalyticsUseCase();
      emit(AnalyticsLoadedState(analytics: analytics));
    } catch (e) {
      emit(AdminErrorState(message: e.toString()));
    }
  }

  Future<void> _onGenerate3DModel(
    Generate3DModelEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoadingState());
    try {
      final result = await generate3DModelUseCase(event.buildingId, event.coordinates);
      emit(Model3DGeneratedState(result: result));
    } catch (e) {
      emit(AdminErrorState(message: e.toString()));
    }
  }

  Future<void> _onLoadBuildingStructure(
    LoadBuildingStructureEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoadingState());
    try {
      final data = await getBuildingStructureUseCase(event.buildingId);
      
      // Parse floors, rooms, and waypoints into FloorData list
      final floors = <FloorData>[];
      final roomsData = data['rooms'] as List;
      final waypointsData = data['waypoints'] as List;
      
      // Group by floor
      final roomGroups = <int, List<RoomModel>>{};
      final waypointGroups = <int, List<dynamic>>{}; // Using dynamic for intermediate storage
      
      // Process rooms
      for (var r in roomsData) {
        final floorNum = (r['coordinates']['floor'] as num).toInt();
        if (!roomGroups.containsKey(floorNum)) roomGroups[floorNum] = [];
        
        // Convert to RoomModel for 3D viewer
        roomGroups[floorNum]!.add(RoomModel(
          id: r['id']?.toString() ?? '',
          name: r['name'] ?? 'Room',
          type: r['room_type'] ?? 'office',
          x: (r['coordinates']['lat'] as num).toDouble() / 100.0, // Normalize to 0-1
          y: (r['coordinates']['lng'] as num).toDouble() / 100.0, // Normalize to 0-1
          width: (r['coordinates']['width'] as num).toDouble() / 100.0, // Normalize to 0-1
          depth: (r['coordinates']['length'] as num).toDouble() / 100.0, // Normalize to 0-1
          height: 3.0, // Default room height
        ));
      }

      // We need to know available floors from the structure if rooms are empty
      // But assuming the API returns valid structure, we can iterate known floors
      final availableFloors = roomGroups.keys.toList()..sort();
      
      for (var floorNum in availableFloors) {
        floors.add(FloorData(
          floorNumber: floorNum,
          name: 'Floor $floorNum',
          rooms: roomGroups[floorNum] ?? [],
          walls: [], // Walls not used in new 3D viewer
        ));
      }
      
      emit(BuildingStructureLoadedState(floors: floors));
    } catch (e) {
      emit(AdminErrorState(message: e.toString()));
    }
  }
}