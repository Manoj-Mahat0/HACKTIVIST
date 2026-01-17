from fastapi import APIRouter, Depends, HTTPException
from typing import List, Dict, Any
from models import User, Building, Floor, Room, Waypoint, ARMarker
from schemas import BuildingCreate
from auth_utils import get_current_user
from bson import ObjectId
from datetime import datetime

router = APIRouter()

@router.get("/buildings/{building_id}/download")
async def download_building_for_offline(
    building_id: str,
    client_version: int = 0,
    current_user: User = Depends(get_current_user)
):

    """
    Download complete building data for offline navigation.
    Returns all floors, rooms, waypoints, and AR markers.
    """
    try:
        # Get building
        building = await Building.get(building_id)
        if not building:
            raise HTTPException(status_code=404, detail="Building not found")
            
        # Check version
        if building.version <= client_version:
            return {"status": "not_modified", "version": building.version, "message": "Building is up to date"}
        
        # Get all floors for this building
        floors = await Floor.find(Floor.building_id == ObjectId(building_id)).to_list()
        
        # Get all rooms for this building
        rooms = []
        waypoints = []
        markers = []
        
        for floor in floors:
            # Get rooms for this floor
            floor_rooms = await Room.find(Room.floor_id == floor.id).to_list()
            rooms.extend(floor_rooms)
            
            # Get waypoints for this floor
            floor_waypoints = await Waypoint.find(Waypoint.floor_id == floor.id).to_list()
            waypoints.extend(floor_waypoints)
            
            # Get AR markers for this floor
            floor_markers = await ARMarker.find(ARMarker.floor_id == floor.id).to_list()
            markers.extend(floor_markers)
        
        # Convert navigation nodes from waypoints
        navigation_nodes = []
        for idx, waypoint in enumerate(waypoints):
            # Create navigation node with connections
            connected_nodes = []
            distances = {}
            
            # Connect to nearby waypoints on same floor (within 15 meters)
            for other_idx, other_waypoint in enumerate(waypoints):
                if other_idx != idx and waypoint.floor_id == other_waypoint.floor_id:
                    # Calculate distance
                    dx = waypoint.latitude - other_waypoint.latitude
                    dy = waypoint.longitude - other_waypoint.longitude
                    distance = (dx**2 + dy**2)**0.5 * 111000  # Convert to meters
                    
                    if distance < 15:  # Within 15 meters
                        connected_nodes.append(str(other_waypoint.id))
                        # Basic weighted graph: Weight = Distance for now
                        # Future: Add multipliers for stairs/elevators
                        distances[str(other_waypoint.id)] = {
                            "distance": distance,
                            "weight": distance
                        }
            
            navigation_nodes.append({
                "id": str(waypoint.id),
                "building_id": building_id,
                "floor_id": str(waypoint.floor_id),
                "x": waypoint.latitude,
                "y": waypoint.longitude,
                "type": waypoint.waypoint_type or "corridor",
                "connected_node_ids": connected_nodes,
                "distances": distances,
                "name": waypoint.name,
            })
        
        # Prepare response
        response = {
            "building": {
                "id": str(building.id),
                "name": building.name,
                "description": building.description,
                "address": building.address,
                "latitude": building.latitude,
                "longitude": building.longitude,
                "downloaded_at": datetime.utcnow().isoformat(),
                "version": building.version,
            },
            "floors": [
                {
                    "id": str(floor.id),
                    "building_id": building_id,
                    "floor_number": floor.floor_number,
                    "name": floor.name,
                    "width": 50.0,  # Default width in meters
                    "height": 40.0,  # Default height in meters
                    "origin_x": 0.0,
                    "origin_y": 0.0,
                }
                for floor in floors
            ],
            "rooms": [
                {
                    "id": str(room.id),
                    "floor_id": str(room.floor_id),
                    "building_id": building_id,
                    "name": room.name,
                    "type": room.room_type,
                    "x": room.coordinates.get("lat", 0),
                    "y": room.coordinates.get("lng", 0),
                    "width": room.coordinates.get("width", 5.0),
                    "height": room.coordinates.get("length", 4.0),
                    "entrance_node_id": None,  # Will be set during navigation graph creation
                }
                for room in rooms
            ],
            "navigation_nodes": navigation_nodes,
            "qr_markers": [
                {
                    "id": str(marker.id),
                    "building_id": building_id,
                    "floor_id": str(marker.floor_id),
                    "x": marker.latitude,
                    "y": marker.longitude,
                    "orientation_degrees": 0.0,
                    "qr_data": marker.marker_data,
                    "description": marker.description,
                }
                for marker in markers
            ],
            "metadata": {
                "total_floors": len(floors),
                "total_rooms": len(rooms),
                "total_waypoints": len(waypoints),
                "total_markers": len(markers),
                "download_timestamp": building.created_at.isoformat(),
            }
        }
        
        return response
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error downloading building data: {str(e)}")


@router.get("/buildings")
async def get_available_buildings_for_offline(
    current_user: User = Depends(get_current_user)
):
    """
    Get list of buildings available for offline download.
    Returns basic building info and download size estimate.
    """
    try:
        buildings = await Building.find_all().to_list()
        
        result = []
        for building in buildings:
            # Count resources
            floors = await Floor.find(Floor.building_id == building.id).to_list()
            
            total_rooms = 0
            total_waypoints = 0
            total_markers = 0
            
            for floor in floors:
                rooms = await Room.find(Room.floor_id == floor.id).to_list()
                waypoints = await Waypoint.find(Waypoint.floor_id == floor.id).to_list()
                markers = await ARMarker.find(ARMarker.floor_id == floor.id).to_list()
                
                total_rooms += len(rooms)
                total_waypoints += len(waypoints)
                total_markers += len(markers)
            
            # Estimate download size (rough estimate)
            estimated_size_kb = (
                len(floors) * 2 +  # Floor data
                total_rooms * 1 +  # Room data
                total_waypoints * 1 +  # Waypoint data
                total_markers * 2  # Marker data
            )
            
            result.append({
                "id": str(building.id),
                "name": building.name,
                "address": building.address,
                "description": building.description,
                "floors_count": len(floors),
                "rooms_count": total_rooms,
                "waypoints_count": total_waypoints,
                "markers_count": total_markers,
                "estimated_size_kb": estimated_size_kb,
                "version": getattr(building, 'version', 1),
                "is_ready_for_offline": total_waypoints > 0,  # Has navigation data
            })
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching buildings: {str(e)}")


@router.post("/buildings/{building_id}/qr-markers")
async def create_qr_marker(
    building_id: str,
    marker_data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Create QR marker for offline navigation calibration.
    Admin only.
    """
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        # Create AR marker with QR code data
        marker = ARMarker(
            floor_id=ObjectId(marker_data["floor_id"]),
            latitude=marker_data["x"],
            longitude=marker_data["y"],
            floor_number=marker_data["floor"],
            marker_type="qr_code",
            marker_data=marker_data["qr_data"],
            description=marker_data.get("description", "QR calibration marker"),
        )
        await marker.save()
        
        return {
            "id": str(marker.id),
            "message": "QR marker created successfully",
            "marker": {
                "id": str(marker.id),
                "floor_id": str(marker.floor_id),
                "x": marker.latitude,
                "y": marker.longitude,
                "floor": marker.floor_number,
                "qr_data": marker.marker_data,
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating QR marker: {str(e)}")


@router.delete("/buildings/{building_id}/qr-markers/{marker_id}")
async def delete_qr_marker(
    building_id: str,
    marker_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Delete QR marker.
    Admin only.
    """
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        marker = await ARMarker.get(marker_id)
        if not marker:
            raise HTTPException(status_code=404, detail="Marker not found")
        
        await marker.delete()
        
        return {"message": "QR marker deleted successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting QR marker: {str(e)}")


@router.post("/sync/buildings")
async def sync_offline_building(
    building_data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Sync an offline-created building to the server.
    This endpoint allows any authenticated user to sync buildings they created offline.
    """
    try:
        # Validate required fields
        required_fields = ['name', 'address', 'latitude', 'longitude']
        for field in required_fields:
            if field not in building_data:
                raise HTTPException(status_code=400, detail=f"Missing required field: {field}")
        
        # Create building
        db_building = Building(
            name=building_data['name'],
            description=building_data.get('description', ''),
            address=building_data['address'],
            latitude=building_data['latitude'],
            longitude=building_data['longitude'],
            boundary_points=building_data.get('boundary_points', []),
            created_by=current_user.id,
            created_at=datetime.utcnow(),
        )
        await db_building.insert()
        
        return {
            "success": True,
            "message": "Building synced successfully",
            "id": str(db_building.id),
            "building": {
                "id": str(db_building.id),
                "name": db_building.name,
                "address": db_building.address,
                "latitude": db_building.latitude,
                "longitude": db_building.longitude,
                "created_at": db_building.created_at.isoformat(),
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error syncing building: {str(e)}")


@router.post("/sync/batch")
async def sync_batch_offline_data(
    sync_data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Batch sync multiple offline items.
    Accepts buildings, coordinates, waypoints, etc.
    """
    results = {
        "buildings_synced": 0,
        "buildings_failed": 0,
        "errors": [],
        "synced_items": []
    }
    
    try:
        # Sync buildings
        buildings = sync_data.get('buildings', [])
        for building_data in buildings:
            try:
                db_building = Building(
                    name=building_data['name'],
                    description=building_data.get('description', ''),
                    address=building_data['address'],
                    latitude=building_data['latitude'],
                    longitude=building_data['longitude'],
                    boundary_points=building_data.get('boundary_points', []),
                    created_by=current_user.id,
                    created_at=datetime.utcnow(),
                )
                await db_building.insert()
                results['buildings_synced'] += 1
                results['synced_items'].append({
                    'type': 'building',
                    'local_id': building_data.get('local_id'),
                    'server_id': str(db_building.id),
                    'name': db_building.name,
                })
            except Exception as e:
                results['buildings_failed'] += 1
                results['errors'].append(f"Building '{building_data.get('name', 'unknown')}': {str(e)}")
        
        return results
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Batch sync failed: {str(e)}")
