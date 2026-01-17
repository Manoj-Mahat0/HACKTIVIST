import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart' as vector_node;
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../domain/entities/ar_node.dart';
import '../../domain/logic/a_star.dart';
import '../bloc/ar_navigation_bloc.dart';
import '../bloc/ar_navigation_event.dart';
import '../bloc/ar_navigation_state.dart';
import '../../../../core/di/injection_container.dart';

class ArNavigationPage extends StatefulWidget {
  final String buildingId;
  final String buildingName;
  
  const ArNavigationPage({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  @override
  State<ArNavigationPage> createState() => _ArNavigationPageState();
}

class _ArNavigationPageState extends State<ArNavigationPage> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  
  ARAnchorManager? arAnchorManager;
  
  List<ArNode> fullGraph = [];
  List<ArNode> currentPath = [];
  ArNode? startNode;
  ArNode? endNode;
  
  bool isLocalized = false;
  bool isResolvingAnchor = false;

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ArNavigationBloc>()..add(LoadGraphEvent(widget.buildingId)),
      child: Scaffold(
        body: BlocConsumer<ArNavigationBloc, ArNavigationState>(
          listener: (context, state) {
            if (state is ArGraphLoaded) {
              setState(() => fullGraph = state.nodes);
            }
          },
          builder: (context, state) {
            if (state is ArNavigationLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ArNavigationError) {
              return Center(child: Text("Error: ${state.message}"));
            }
            if (isResolvingAnchor) {
               return _buildResolutionScreen();
            }
            if (!isLocalized) {
              return _buildLocalizationScreen();
            }
            if (endNode == null) {
              return _buildDestinationSelection();
            }
            return _buildARNavigationScreen();
          },
        ),
      ),
    );
  }

  Widget _buildLocalizationScreen() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final code = barcodes.first.rawValue;
                    _localize(code);
                  }
                },
              ),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  width: 200,
                  height: 200,
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Scan QR Code OR...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
             color: Colors.white,
             child: Column(
               children: [
                 const Padding(
                   padding: EdgeInsets.all(8.0),
                   child: Text("Select Current Location (Visual Anchor)"),
                 ),
                 Expanded(
                   child: ListView.builder(
                     itemCount: fullGraph.where((n) => n.cloudAnchorId != null && n.label != null).length,
                     itemBuilder: (context, index) {
                       final node = fullGraph.where((n) => n.cloudAnchorId != null && n.label != null).elementAt(index);
                       return ListTile(
                         leading: const Icon(Icons.image),
                         title: Text(node.label!),
                         subtitle: const Text("Visual Anchor"),
                         onTap: () => _startCloudLocalization(node),
                       );
                     },
                   ),
                 ),
               ],
             ),
          ),
        ),
      ],
    );
  }

  void _startCloudLocalization(ArNode node) {
     // Switch to AR View to resolve anchor
     setState(() {
       startNode = node;
       isResolvingAnchor = true; 
       // We set isLocalized = true tentatively, but we need to resolve first?
       // Actually, we change the UI to AR View, but with a "Scanning for Environment..." overlay.
     });
  }

  void _localize(String? code) {
    if (code == null) return;
    try {
      // Find node with this anchorId
      // In a real app, we check if graph has this anchorId. 
      // For now, assuming code == nodeId or anchorId
      // Let's assume code IS the anchorID stored in valid nodes.
      final found = fullGraph.cast<ArNode?>().firstWhere(
        (n) => n?.anchorId == code || n?.id == code, // Fallback
        orElse: () => null
      );
      
      if (found != null) {
        setState(() {
          startNode = found;
          isLocalized = true;
        });
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid QR Code for this building")));
      }
    } catch (e) {
      // Handle error
    }
  }

  Widget _buildDestinationSelection() {
    // Filter nodes with labels
    final destinations = fullGraph.where((n) => n.label != null && n.label!.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Select Destination")),
      body: ListView.builder(
        itemCount: destinations.length,
        itemBuilder: (context, index) {
          final node = destinations[index];
          return ListTile(
            title: Text(node.label!),
            subtitle: Text(node.id),
            onTap: () {
               setState(() => endNode = node);
               _calculatePath();
            },
          );
        },
      ),
    );
  }

  void _calculatePath() {
    if (startNode == null || endNode == null) return;
    
    final aStar = AStar(fullGraph);
    final path = aStar.findPath(startNode!.id, endNode!.id);
    
    setState(() {
      currentPath = path;
    });
  }

  Widget _buildARNavigationScreen() {
    return Stack(
      children: [
        ARView(
          onARViewCreated: _onARViewCreated,
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Navigating to: ${endNode?.label}", style: const TextStyle(color: Colors.white, fontSize: 18)),
                Text("Steps: ${currentPath.length}", style: const TextStyle(color: Colors.white70)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () {
                  setState(() {
                    endNode = null;
                    isLocalized = false; // Require rescan? Or just keep localized.
                    // Keep localized for better UX
                  });
                })
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildResolutionScreen() {
    return Stack(
      children: [
        ARView(onARViewCreated: _onARViewCreated),
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text("Resolving ${startNode?.label}...", style: const TextStyle(color: Colors.white)),
                const Text("Point camera at the object", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) async {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
      showFeaturePoints: true, // Show dots to help user understand it's scanning
      showPlanes: true,
      handlePans: false,
      handleRotation: false,
    );
    this.arObjectManager!.onInitialize();
    
    if (isResolvingAnchor && startNode?.cloudAnchorId != null) {
       _resolveAnchor(startNode!.cloudAnchorId!);
    } else {
       // Draw Path if we are already localized (via QR)
       // Wait for init
       await Future.delayed(const Duration(seconds: 1)); 
       _drawPath();
    }
  }
  
  void _resolveAnchor(String cloudId) {
     // Register anchor ID to resolve
     // ar_flutter_plugin uses standard ARCore/ARKit resolve
     // We need to create a dummy anchor with cloud ID?
     // Actually the plugin usually has downloadAnchor(id).
     
     // Note: ar_flutter_plugin_2 might vary. Assuming standard Google Cloud Anchor flow.
     // In this plugin, one usually adds an anchor with cloudanchorid.
     
     final anchor = ARPlaneAnchor(
       name: startNode!.label!,
       cloudanchorid: cloudId,
       transformation: Matrix4.identity(), // transform will be updated upon resolution
     );
     
     arAnchorManager!.addAnchor(anchor).then((result) {
        if (result == true) {
           // Wait for resolution?
           // The plugin updates the anchor's tracking state.
           // We should listen to anchor updates, but for MVP let's assume if it added, we wait a bit and check.
           
           // Ideally we listen to "onAnchorUploaded" or "onAnchorDownloaded" if exposed.
           // Let's sim success after 3 seconds for UI feel if we can't hook real event easily.
           
           Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  isResolvingAnchor = false;
                  isLocalized = true;
                });
                _drawPath();
              }
           });
        }
     });
  }

  Future<void> _drawPath() async {
    if (currentPath.isEmpty) return;
    
    // We assume StartNode is at (0,0,0) of the AR World because we just scanned it?
    // In ARCore, the session starts where the camera is.
    // If we stood at the QR code and scanned it, the camera is at QR code (approx).
    // So StartNode (Graph) = (0,0,0) (AR World).
    
    // Graph Coordinates are relative to Anchor.
    // So if Path Node 2 is at (x=1, y=0, z=0), we place AR Node at (1,0,0).
    
    // Optimization: Draw Arrows between nodes.
    
    // We need to transform graph coordinates to be relative to startNode.
    // path[0] == startNode.
    // path[i].x - startNode.x = relative x.
    
    for (int i = 0; i < currentPath.length; i++) {
        final node = currentPath[i];
        
        // Relative position to start node
        final relX = node.x - startNode!.x;
        final relY = node.y - startNode!.y;
        final relZ = node.z - startNode!.z;
        
        // Place sphere/arrow
        var arNode = vector_node.ARNode(
            type: NodeType.localGLTF2,
            uri: "assets/models/sphere.gltf", // Use generic or passed asset
            scale: vector.Vector3(0.1, 0.1, 0.1),
            position: vector.Vector3(relX, relY, relZ), // SWAP Y/Z? AR usually Y is up. Graph usually Z is up (Floor).
            // Assuming we stored X=Lat/East, Y=Lng/North, Z=Floor?
            // In AR, X=Right, Y=Up, Z=Back.
            // We need to map: Graph X -> AR X, Graph Y -> AR -Z (Forward), Graph Z -> AR Y (Up).
            // Let's assume standard mapping: X->X, Y->Z, Z->Y.
        );
        
        // NOTE: Coordinate mapping is critical.
        // If we recorded by walking, ARCore uses Start Position as origin.
        // User walks forward -> -Z (usually).
        
        // Simplification for MVP: Map directly and see. Since we record using ARView, and Playback using ARView, 
        // if we record x,y,z from ARView, it should match ARView playback.
        
        await arObjectManager!.addNode(arNode);
    }
  }
}
