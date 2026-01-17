import 'package:equatable/equatable.dart';
import '../../domain/entities/ar_node.dart';

abstract class ArNavigationState extends Equatable {
  const ArNavigationState();
  
  @override
  List<Object> get props => [];
}

class ArNavigationInitial extends ArNavigationState {}

class ArNavigationLoading extends ArNavigationState {}

class ArGraphLoaded extends ArNavigationState {
  final List<ArNode> nodes;
  const ArGraphLoaded(this.nodes);
  
  @override
  List<Object> get props => [nodes];
}

class ArGraphSavedSuccess extends ArNavigationState {}

class ArNavigationError extends ArNavigationState {
  final String message;
  const ArNavigationError(this.message);

  @override
  List<Object> get props => [message];
}
