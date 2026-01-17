import 'package:equatable/equatable.dart';
import '../../domain/entities/ar_node.dart';

abstract class ArNavigationEvent extends Equatable {
  const ArNavigationEvent();

  @override
  List<Object> get props => [];
}

class LoadGraphEvent extends ArNavigationEvent {
  final String buildingId;
  const LoadGraphEvent(this.buildingId);
}

class SaveGraphEvent extends ArNavigationEvent {
  final String buildingId;
  final List<ArNode> nodes;
  const SaveGraphEvent(this.buildingId, this.nodes);
}
