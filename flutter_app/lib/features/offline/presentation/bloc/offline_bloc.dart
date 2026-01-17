import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/offline_repository.dart';
import '../../../../models/building.dart';
import '../../../../models/offline_building.dart';
import '../../../../models/sync_log.dart';

// Events
abstract class OfflineEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAvailableBuildingsEvent extends OfflineEvent {}

class DownloadBuildingEvent extends OfflineEvent {
  final String buildingId;
  final String buildingName;

  DownloadBuildingEvent(this.buildingId, this.buildingName);

  @override
  List<Object?> get props => [buildingId, buildingName];
}

class DeleteBuildingEvent extends OfflineEvent {
  final String buildingId;

  DeleteBuildingEvent(this.buildingId);

  @override
  List<Object?> get props => [buildingId];
}

class LoadDownloadedBuildingsEvent extends OfflineEvent {}

class CreateOfflineBuildingEvent extends OfflineEvent {
  final String name;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final List<Map<String, double>> boundaryPoints;

  CreateOfflineBuildingEvent({
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

class LoadOfflineBuildingsEvent extends OfflineEvent {}

class SyncOfflineDataEvent extends OfflineEvent {}

class LoadSyncLogsEvent extends OfflineEvent {}

class DeleteOfflineBuildingEvent extends OfflineEvent {
  final String buildingId;

  DeleteOfflineBuildingEvent(this.buildingId);

  @override
  List<Object?> get props => [buildingId];
}

// States
abstract class OfflineState extends Equatable {
  @override
  List<Object?> get props => [];
}

class OfflineInitial extends OfflineState {}

class OfflineLoading extends OfflineState {}

class AvailableBuildingsLoaded extends OfflineState {
  final List<Map<String, dynamic>> buildings;

  AvailableBuildingsLoaded(this.buildings);

  @override
  List<Object?> get props => [buildings];
}

class DownloadedBuildingsLoaded extends OfflineState {
  final List<Building> buildings;

  DownloadedBuildingsLoaded(this.buildings);

  @override
  List<Object?> get props => [buildings];
}

class BuildingDownloading extends OfflineState {
  final String buildingId;
  final String buildingName;
  final double progress;

  BuildingDownloading(this.buildingId, this.buildingName, this.progress);

  @override
  List<Object?> get props => [buildingId, buildingName, progress];
}

class BuildingDownloaded extends OfflineState {
  final String buildingId;
  final String buildingName;

  BuildingDownloaded(this.buildingId, this.buildingName);

  @override
  List<Object?> get props => [buildingId, buildingName];
}

class BuildingDeleted extends OfflineState {
  final String buildingId;

  BuildingDeleted(this.buildingId);

  @override
  List<Object?> get props => [buildingId];
}

class OfflineError extends OfflineState {
  final String message;

  OfflineError(this.message);

  @override
  List<Object?> get props => [message];
}

class OfflineBuildingCreated extends OfflineState {
  final OfflineBuilding building;

  OfflineBuildingCreated(this.building);

  @override
  List<Object?> get props => [building];
}

class OfflineBuildingsLoaded extends OfflineState {
  final List<OfflineBuilding> buildings;

  OfflineBuildingsLoaded(this.buildings);

  @override
  List<Object?> get props => [buildings];
}

class SyncInProgress extends OfflineState {
  final String message;

  SyncInProgress(this.message);

  @override
  List<Object?> get props => [message];
}

class SyncCompleted extends OfflineState {
  final Map<String, dynamic> results;

  SyncCompleted(this.results);

  @override
  List<Object?> get props => [results];
}

class SyncLogsLoaded extends OfflineState {
  final List<SyncLog> logs;
  final Map<String, int> statistics;

  SyncLogsLoaded(this.logs, this.statistics);

  @override
  List<Object?> get props => [logs, statistics];
}

class OfflineBuildingDeleted extends OfflineState {
  final String buildingId;

  OfflineBuildingDeleted(this.buildingId);

  @override
  List<Object?> get props => [buildingId];
}

// BLoC
class OfflineBloc extends Bloc<OfflineEvent, OfflineState> {
  final OfflineRepository _repository;

  OfflineBloc(this._repository) : super(OfflineInitial()) {
    on<LoadAvailableBuildingsEvent>(_onLoadAvailableBuildings);
    on<DownloadBuildingEvent>(_onDownloadBuilding);
    on<DeleteBuildingEvent>(_onDeleteBuilding);
    on<LoadDownloadedBuildingsEvent>(_onLoadDownloadedBuildings);
    on<CreateOfflineBuildingEvent>(_onCreateOfflineBuilding);
    on<LoadOfflineBuildingsEvent>(_onLoadOfflineBuildings);
    on<SyncOfflineDataEvent>(_onSyncOfflineData);
    on<LoadSyncLogsEvent>(_onLoadSyncLogs);
    on<DeleteOfflineBuildingEvent>(_onDeleteOfflineBuilding);
  }

  Future<void> _onLoadAvailableBuildings(
    LoadAvailableBuildingsEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(OfflineLoading());
      final buildings = await _repository.getAvailableBuildings();
      emit(AvailableBuildingsLoaded(buildings));
    } catch (e) {
      emit(OfflineError(e.toString()));
    }
  }

  Future<void> _onDownloadBuilding(
    DownloadBuildingEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(BuildingDownloading(event.buildingId, event.buildingName, 0.0));

      await _repository.downloadBuilding(
        event.buildingId,
        onProgress: (progress) {
          emit(BuildingDownloading(event.buildingId, event.buildingName, progress));
        },
      );

      emit(BuildingDownloaded(event.buildingId, event.buildingName));
    } catch (e) {
      emit(OfflineError('Failed to download building: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteBuilding(
    DeleteBuildingEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(OfflineLoading());
      await _repository.deleteDownloadedBuilding(event.buildingId);
      emit(BuildingDeleted(event.buildingId));
    } catch (e) {
      emit(OfflineError(e.toString()));
    }
  }

  Future<void> _onLoadDownloadedBuildings(
    LoadDownloadedBuildingsEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(OfflineLoading());
      final buildings = await _repository.getDownloadedBuildings();
      emit(DownloadedBuildingsLoaded(buildings));
    } catch (e) {
      emit(OfflineError(e.toString()));
    }
  }

  Future<void> _onCreateOfflineBuilding(
    CreateOfflineBuildingEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(OfflineLoading());
      final building = await _repository.createOfflineBuilding(
        name: event.name,
        description: event.description,
        address: event.address,
        latitude: event.latitude,
        longitude: event.longitude,
        boundaryPoints: event.boundaryPoints,
      );
      emit(OfflineBuildingCreated(building));
    } catch (e) {
      emit(OfflineError('Failed to create offline building: ${e.toString()}'));
    }
  }

  Future<void> _onLoadOfflineBuildings(
    LoadOfflineBuildingsEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(OfflineLoading());
      final buildings = await _repository.getOfflineBuildings();
      emit(OfflineBuildingsLoaded(buildings));
    } catch (e) {
      emit(OfflineError(e.toString()));
    }
  }

  Future<void> _onSyncOfflineData(
    SyncOfflineDataEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(SyncInProgress('Checking connectivity...'));
      
      final isOnline = await _repository.isOnline();
      if (!isOnline) {
        emit(OfflineError('No internet connection. Please check your network and try again.'));
        return;
      }

      emit(SyncInProgress('Syncing offline data...'));
      final results = await _repository.syncAllOfflineData();
      emit(SyncCompleted(results));
    } catch (e) {
      emit(OfflineError('Sync failed: ${e.toString()}'));
    }
  }

  Future<void> _onLoadSyncLogs(
    LoadSyncLogsEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(OfflineLoading());
      final logs = await _repository.getSyncLogs();
      final statistics = await _repository.getSyncStatistics();
      emit(SyncLogsLoaded(logs, statistics));
    } catch (e) {
      emit(OfflineError(e.toString()));
    }
  }

  Future<void> _onDeleteOfflineBuilding(
    DeleteOfflineBuildingEvent event,
    Emitter<OfflineState> emit,
  ) async {
    try {
      emit(OfflineLoading());
      await _repository.deleteOfflineBuilding(event.buildingId);
      emit(OfflineBuildingDeleted(event.buildingId));
    } catch (e) {
      emit(OfflineError(e.toString()));
    }
  }
}
