import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';
import 'package:indoor_navigation/features/buildings/domain/usecases/get_buildings_usecase.dart';
import 'package:indoor_navigation/features/buildings/domain/repositories/buildings_repository.dart';

// Events
abstract class BuildingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadBuildingsEvent extends BuildingsEvent {}

class CreateBuildingEvent extends BuildingsEvent {
  final String name;
  final String description;
  final String address;
  final double latitude;
  final double longitude;

  CreateBuildingEvent({
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [name, description, address, latitude, longitude];
}

class CreateBuildingWithBoundaryEvent extends BuildingsEvent {
  final String name;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final List<Map<String, double>> boundaryPoints;

  CreateBuildingWithBoundaryEvent({
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.boundaryPoints,
  });

  @override
  List<Object?> get props => [name, description, address, latitude, longitude, boundaryPoints];
}

class UpdateBuildingBoundaryEvent extends BuildingsEvent {
  final String buildingId;
  final double latitude;
  final double longitude;
  final List<Map<String, double>> boundaryPoints;

  UpdateBuildingBoundaryEvent({
    required this.buildingId,
    required this.latitude,
    required this.longitude,
    required this.boundaryPoints,
  });

  @override
  List<Object?> get props => [buildingId, latitude, longitude, boundaryPoints];
}

// States
abstract class BuildingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class BuildingsInitialState extends BuildingsState {}

class BuildingsLoadingState extends BuildingsState {}

class BuildingsLoadedState extends BuildingsState {
  final List<Building> buildings;

  BuildingsLoadedState({required this.buildings});

  @override
  List<Object?> get props => [buildings];
}

class BuildingsErrorState extends BuildingsState {
  final String message;

  BuildingsErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}

class BuildingCreatedState extends BuildingsState {
  final Building building;

  BuildingCreatedState({required this.building});

  @override
  List<Object?> get props => [building];
}

class BuildingUpdatedState extends BuildingsState {
  final Building building;

  BuildingUpdatedState({required this.building});

  @override
  List<Object?> get props => [building];
}

// Bloc
class BuildingsBloc extends Bloc<BuildingsEvent, BuildingsState> {
  final GetBuildingsUseCase getBuildingsUseCase;
  final BuildingsRepository buildingsRepository;

  BuildingsBloc(this.getBuildingsUseCase, this.buildingsRepository) : super(BuildingsInitialState()) {
    on<LoadBuildingsEvent>(_onLoadBuildings);
    on<CreateBuildingEvent>(_onCreateBuilding);
    on<CreateBuildingWithBoundaryEvent>(_onCreateBuildingWithBoundary);
    on<UpdateBuildingBoundaryEvent>(_onUpdateBuildingBoundary);
  }

  Future<void> _onLoadBuildings(
    LoadBuildingsEvent event,
    Emitter<BuildingsState> emit,
  ) async {
    emit(BuildingsLoadingState());
    try {
      final buildings = await getBuildingsUseCase();
      emit(BuildingsLoadedState(buildings: buildings));
    } catch (e) {
      emit(BuildingsErrorState(message: e.toString()));
    }
  }

  Future<void> _onCreateBuilding(
    CreateBuildingEvent event,
    Emitter<BuildingsState> emit,
  ) async {
    emit(BuildingsLoadingState());
    try {
      final building = await buildingsRepository.createBuilding(
        name: event.name,
        description: event.description,
        address: event.address,
        latitude: event.latitude,
        longitude: event.longitude,
      );
      emit(BuildingCreatedState(building: building));
      // Reload buildings after creation
      add(LoadBuildingsEvent());
    } catch (e) {
      emit(BuildingsErrorState(message: e.toString()));
    }
  }

  Future<void> _onCreateBuildingWithBoundary(
    CreateBuildingWithBoundaryEvent event,
    Emitter<BuildingsState> emit,
  ) async {
    emit(BuildingsLoadingState());
    try {
      final building = await buildingsRepository.createBuildingWithBoundary(
        name: event.name,
        description: event.description,
        address: event.address,
        latitude: event.latitude,
        longitude: event.longitude,
        boundaryPoints: event.boundaryPoints,
      );
      emit(BuildingCreatedState(building: building));
      // Reload buildings after creation
      add(LoadBuildingsEvent());
    } catch (e) {
      emit(BuildingsErrorState(message: e.toString()));
    }
  }

  Future<void> _onUpdateBuildingBoundary(
    UpdateBuildingBoundaryEvent event,
    Emitter<BuildingsState> emit,
  ) async {
    emit(BuildingsLoadingState());
    try {
      final building = await buildingsRepository.updateBuildingBoundary(
        buildingId: event.buildingId,
        latitude: event.latitude,
        longitude: event.longitude,
        boundaryPoints: event.boundaryPoints,
      );
      emit(BuildingUpdatedState(building: building));
      // Reload buildings after update
      add(LoadBuildingsEvent());
    } catch (e) {
      emit(BuildingsErrorState(message: e.toString()));
    }
  }
}