# AI Assistant for Indoor Navigation - Backend Implementation

## Overview
AI-powered auto-generation of labels and landmark descriptions using Groq API to reduce manual work and improve user experience.

## Features

### 1. Smart Label Generation
Automatically generates appropriate labels based on node type and optional details.

**Examples:**
- Room + "101" → "Room 101"
- Entrance → "Main Entrance"
- Cafe + "Starbucks" → "Café Starbucks"
- Office + "205" → "Office 205"

### 2. AI-Powered Landmark Descriptions
Uses Groq's Llama model to generate concise, practical 20-30 word descriptions for navigation.

**Example:**
```
Input: 
- Type: "room"
- Label: "Room 301"
- Context: "Computer Science Department"

Output:
"Third floor, Computer Science wing. Look for room number 301 on the left side of the corridor, near the water fountain and notice board."
```

## Backend Implementation

### Files Created

#### 1. `backend/services/groq_service.py`
Core service for Groq API integration.

**Key Methods:**
- `generate_landmark_description()` - AI-powered description generation
- `suggest_label()` - Smart label suggestions
- `_generate_fallback_description()` - Template-based fallback

**Features:**
- Uses `llama-3.3-70b-versatile` model (fast and accurate)
- 20-30 word limit for descriptions
- Fallback templates if API fails
- Configurable via environment variable

#### 2. `backend/routers/ai_assistant.py`
REST API endpoints for AI features.

**Endpoints:**

##### POST `/ai/generate-landmark-description`
Generate AI description for a location.

**Request:**
```json
{
  "node_type": "room",
  "label": "Room 301",
  "context": "Computer Science Department"
}
```

**Response:**
```json
{
  "description": "Third floor, Computer Science wing. Look for room number 301...",
  "success": true
}
```

##### POST `/ai/suggest-label`
Get smart label suggestion.

**Request:**
```json
{
  "node_type": "room",
  "number": "101",
  "name": null
}
```

**Response:**
```json
{
  "label": "Room 101",
  "success": true
}
```

##### GET `/ai/node-types`
Get list of available node types with metadata.

**Response:**
```json
{
  "node_types": [
    {
      "value": "room",
      "label": "Room",
      "icon": "meeting_room",
      "requires_number": true
    },
    ...
  ]
}
```

### 3. Updated Files

#### `backend/main.py`
- Added AI assistant router
- Registered `/ai` prefix

#### `backend/requirements.txt`
- Added `groq==0.4.2` dependency

## API Configuration

### Environment Variables
```bash
# Optional - defaults to provided key
GROQ_API_KEY=YOUR_API_KEY_HERE
```

### Groq API Details
- **Model**: `llama-3.3-70b-versatile`
- **Temperature**: 0.7 (balanced creativity)
- **Max Tokens**: 100 (for 20-30 word descriptions)
- **Streaming**: Disabled (for consistent responses)

## Node Types Supported

| Type | Label Template | Requires Number | Icon |
|------|---------------|-----------------|------|
| room | Room {number} | Yes | meeting_room |
| entrance | Main Entrance | No | door_front_door |
| exit | Emergency Exit | No | exit_to_app |
| elevator | Elevator {number} | No | elevator |
| stairs | Staircase {number} | No | stairs |
| bathroom | Restroom {number} | No | wc |
| cafe | Café {name} | No | restaurant |
| office | Office {number} | Yes | business |
| waypoint | Waypoint {number} | No | location_on |

## Usage Examples

### Example 1: Room with Number
```bash
curl -X POST "http://localhost:8000/ai/suggest-label" \
  -H "Content-Type: application/json" \
  -d '{
    "node_type": "room",
    "number": "205"
  }'

# Response: {"label": "Room 205", "success": true}
```

### Example 2: Generate Description
```bash
curl -X POST "http://localhost:8000/ai/generate-landmark-description" \
  -H "Content-Type: application/json" \
  -d '{
    "node_type": "elevator",
    "label": "Elevator A",
    "context": "Near main lobby"
  }'

# Response: 
# {
#   "description": "Located in the main lobby area. Look for elevator doors marked 'A' with call buttons. Accessible from the ground floor entrance.",
#   "success": true
# }
```

### Example 3: Cafe with Custom Name
```bash
curl -X POST "http://localhost:8000/ai/suggest-label" \
  -H "Content-Type: application/json" \
  -d '{
    "node_type": "cafe",
    "name": "Starbucks"
  }'

# Response: {"label": "Café Starbucks", "success": true}
```

## Error Handling

### API Failure
If Groq API fails, the service automatically falls back to template-based descriptions:

```python
# Fallback templates
templates = {
    "room": f"Located at {label}. Look for the room number on the door.",
    "entrance": f"Main entrance at {label}. Large doorway with signage.",
    # ... more templates
}
```

### Invalid Input
Returns HTTP 500 with error details:
```json
{
  "detail": "Failed to generate description: Invalid node type"
}
```

## Benefits

### For Users
✅ **Less Manual Work** - Auto-generated labels and descriptions
✅ **Consistent Quality** - AI ensures professional descriptions
✅ **Time Saving** - No need to write descriptions manually
✅ **Smart Suggestions** - Context-aware label generation

### For Developers
✅ **Easy Integration** - Simple REST API
✅ **Fallback Support** - Works even if API fails
✅ **Extensible** - Easy to add new node types
✅ **Well-Documented** - Clear API documentation

## Testing

### Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### Run Server
```bash
python main.py
```

### Test Endpoints
```bash
# Test label suggestion
curl -X POST "http://localhost:8000/ai/suggest-label" \
  -H "Content-Type: application/json" \
  -d '{"node_type": "room", "number": "101"}'

# Test description generation
curl -X POST "http://localhost:8000/ai/generate-landmark-description" \
  -H "Content-Type: application/json" \
  -d '{"node_type": "room", "label": "Room 101"}'

# Get node types
curl "http://localhost:8000/ai/node-types"
```

### View API Docs
Open browser: `http://localhost:8000/docs`

## Future Enhancements

### Planned Features
1. **Multi-language Support** - Generate descriptions in multiple languages
2. **Image Analysis** - Generate descriptions from landmark photos
3. **Voice Input** - Accept voice descriptions and convert to text
4. **Learning System** - Learn from user edits to improve suggestions
5. **Batch Processing** - Generate descriptions for multiple nodes at once

### Possible Improvements
- Cache frequently used descriptions
- Add user feedback mechanism
- Support custom templates per building
- Integration with building floor plans
- Accessibility-focused descriptions

## API Rate Limits

Groq API limits (as of implementation):
- **Free Tier**: 30 requests/minute
- **Recommended**: Add rate limiting middleware if needed

## Security Considerations

1. **API Key**: Store in environment variable, not in code
2. **Input Validation**: All inputs are validated via Pydantic models
3. **Error Handling**: Sensitive errors are not exposed to clients
4. **CORS**: Configured for all origins (adjust for production)

## Deployment Notes

### Production Checklist
- [ ] Set `GROQ_API_KEY` environment variable
- [ ] Configure CORS for specific origins
- [ ] Add rate limiting middleware
- [ ] Enable API request logging
- [ ] Set up monitoring for API failures
- [ ] Configure fallback templates for your building types

### Docker Deployment
```dockerfile
# Add to Dockerfile
ENV GROQ_API_KEY=your_key_here
```

### Environment Variables
```bash
# .env file
GROQ_API_KEY=YOUR_API_KEY_HERE
```

## Support

For issues or questions:
1. Check API documentation: `/docs`
2. Review error logs
3. Test with fallback templates
4. Verify Groq API key is valid

## License
Same as main project license.
