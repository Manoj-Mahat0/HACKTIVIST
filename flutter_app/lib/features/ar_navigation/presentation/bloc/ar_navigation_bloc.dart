import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/ar_navigation_repository.dart';
import 'ar_navigation_event.dart';
import 'ar_navigation_state.dart';

class ArNavigationBloc extends Bloc<ArNavigationEvent, ArNavigationState> {
  final ArNavigationRepository repository;

  ArNavigationBloc({required this.repository}) : super(ArNavigationInitial()) {
    on<LoadGraphEvent>(_onLoadGraph);
    on<SaveGraphEvent>(_onSaveGraph);
  }

  Future<void> _onLoadGraph(LoadGraphEvent event, Emitter<ArNavigationState> emit) async {
    emit(ArNavigationLoading());
    try {
      final nodes = await repository.getBuildingGraph(event.buildingId);
      emit(ArGraphLoaded(nodes));
    } catch (e) {
      emit(ArNavigationError(e.toString()));
    }
  }

  Future<void> _onSaveGraph(SaveGraphEvent event, Emitter<ArNavigationState> emit) async {
    emit(ArNavigationLoading());
    try {
      await repository.saveBuildingGraph(event.buildingId, event.nodes);
      emit(ArGraphSavedSuccess());
      // Reload after save to ensure sync
      add(LoadGraphEvent(event.buildingId));
    } catch (e) {
      emit(ArNavigationError(e.toString()));
    }
  }
}
