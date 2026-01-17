import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/navigation/domain/usecases/get_navigation_usecase.dart';
import 'package:indoor_navigation/features/navigation/domain/usecases/get_ar_markers_usecase.dart';
import 'package:indoor_navigation/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:indoor_navigation/models/navigation_node.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

// Bloc
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final GetNavigationUseCase getNavigationUseCase;
  final GetArMarkersUseCase getArMarkersUseCase;
  final NavigationRepository? navigationRepository;

  NavigationBloc({
    required this.getNavigationUseCase,
    required this.getArMarkersUseCase,
    this.navigationRepository,
  }) : super(NavigationInitialState()) {
    on<StartNavigationEvent>(_onStartNavigation);
    on<LoadArMarkersEvent>(_onLoadArMarkers);
    on<StopNavigationEvent>(_onStopNavigation);
    on<LoadBuildingLocations>(_onLoadBuildingLocations);
    on<CalculateRoute>(_onCalculateRoute);
  }

  Future<void> _onStartNavigation(
    StartNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    emit(NavigationLoadingState());
    try {
      final navigationResponse = await getNavigationUseCase(event.request);
      final arMarkers = await getArMarkersUseCase(event.request.buildingId);
      emit(NavigationActiveState(
        navigationResponse: navigationResponse,
        arMarkers: arMarkers,
      ));
    } catch (e) {
      emit(NavigationErrorState(message: e.toString()));
    }
  }

  Future<void> _onLoadArMarkers(
    LoadArMarkersEvent event,
    Emitter<NavigationState> emit,
  ) async {
    try {
      final arMarkers = await getArMarkersUseCase(event.buildingId);
      emit(ArMarkersLoadedState(arMarkers: arMarkers));
    } catch (e) {
      emit(NavigationErrorState(message: e.toString()));
    }
  }

  Future<void> _onStopNavigation(
    StopNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    emit(NavigationInitialState());
  }

  Future<void> _onLoadBuildingLocations(
    LoadBuildingLocations event,
    Emitter<NavigationState> emit,
  ) async {
    emit(NavigationLoading());
    try {
      if (navigationRepository != null) {
        final locationsData = await navigationRepository!.getBuildingLocations(event.buildingId);
        print('📍 Raw locations data: $locationsData');
        
        final locations = <NavigationNode>[];
        for (int i = 0; i < locationsData.length; i++) {
          try {
            final data = locationsData[i];
            print('🔍 Processing location $i: $data');
            final node = NavigationNode.fromJson(
              id: data['id'] ?? '',
              buildingId: data['building_id'] ?? event.buildingId,
              floorId: data['floor_id'] ?? '',
              x: (data['x'] ?? data['latitude'] ?? 0.0).toDouble(),
              y: (data['y'] ?? data['longitude'] ?? 0.0).toDouble(),
              typeIndex: data['type_index'] ?? 0,
              connectedNodeIds: List<String>.from(data['connected_node_ids'] ?? []),
              distances: Map<String, double>.from(data['distances'] ?? {}),
              name: data['name'] ?? data['label'],
            );
            locations.add(node);
            print('✅ Successfully parsed location $i: ${node.name} (id: ${node.id})');
          } catch (e) {
            print('❌ Error parsing location $i: $e');
            print('📋 Raw data: ${locationsData[i]}');
            // Continue with other locations instead of failing completely
            continue;
          }
        }
        
        if (locations.isEmpty) {
          emit(NavigationError('No navigation points found. Please use Coordinate Collection to add navigation points first.'));
        } else if (locations.length == 1) {
          emit(NavigationError('Only one navigation point found. You need at least 2 connected points to navigate. Please add more points in Coordinate Collection.'));
        } else {
          // Check if any nodes have connections
          final hasConnections = locations.any((loc) => loc.connectedNodeIds.isNotEmpty);
          if (!hasConnections) {
            print('⚠️ Warning: No nodes have connections. Navigation may not work.');
          }
          emit(LocationsLoaded(locations));
        }
      } else {
        emit(NavigationError('Navigation repository not available'));
      }
    } catch (e) {
      print('💥 Error in _onLoadBuildingLocations: $e');
      emit(NavigationError('Failed to load locations: ${e.toString()}'));
    }
  }

  Future<void> _onCalculateRoute(
    CalculateRoute event,
    Emitter<NavigationState> emit,
  ) async {
    emit(NavigationLoading());
    try {
      if (navigationRepository != null) {
        print('🧭 Calculating route: ${event.startNodeId} → ${event.endNodeId}');
        print('   Options: accessible=${event.accessible}, avoidCrowds=${event.avoidCrowds}');
        
        final routeData = await navigationRepository!.calculateRoute(
          event.buildingId,
          event.startNodeId,
          event.endNodeId,
          accessible: event.accessible,
          avoidCrowds: event.avoidCrowds,
          stepLength: event.stepLength,
          walkingSpeed: event.walkingSpeed,
        );
        
        if (routeData.isEmpty) {
          emit(NavigationError('No route found. Make sure the nodes are connected with edges in Coordinate Collection.'));
          return;
        }
        
        print('✅ Route calculated with ${routeData.length} steps');
        final steps = routeData.map((data) => {
          'id': data['id'] ?? data['node_id'] ?? '',
          'name': data['name'] ?? data['label'] ?? '',
          'node_type': data['node_type'] ?? 'waypoint',
          'instruction': data['instruction'] ?? 'Continue to next point',
          'floor_number': data['floor_number'] ?? data['floor'],
          'distance': data['distance']?.toDouble() ?? data['steps_to_next']?.toDouble(),
          'image_url': data['image_url'],
          'direction': data['direction'],
        }).toList();
        print('🚨 About to emit RouteCalculated with ${steps.length} steps');
        emit(RouteCalculated(steps));
        print('🚨 RouteCalculated emitted successfully');
      } else {
        emit(NavigationError('Navigation repository not available'));
      }
    } catch (e) {
      print('❌ Route calculation error: $e');
      String errorMessage = e.toString();
      if (errorMessage.contains('No route found')) {
        errorMessage = 'No route found between these locations. The nodes may not be connected.';
      } else if (errorMessage.contains('not found')) {
        errorMessage = 'One of the selected locations was not found. Please try again.';
      }
      emit(NavigationError(errorMessage));
    }
  }
}
