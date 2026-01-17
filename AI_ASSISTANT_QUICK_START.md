# AI Assistant Quick Start Guide

## 🚀 What's New?

AI-powered auto-generation for indoor navigation labels and descriptions using Groq API!

## ✨ Features

### 1. Smart Label Generation
- **Room** + number → "Room 101"
- **Cafe** + name → "Café Starbucks"  
- **Office** + number → "Office 205"
- **Entrance** → "Main Entrance"

### 2. AI Landmark Descriptions
Automatically generates 20-30 word navigation descriptions:

**Example:**
> "Third floor, Computer Science wing. Look for room number 301 on the left side of the corridor, near the water fountain."

## 📦 Installation

### 1. Install Dependencies
```bash
cd backend
pip install groq==0.4.2
```

Or install all:
```bash
pip install -r requirements.txt
```

### 2. Set API Key (Optional)
```bash
# Already configured with default key
# To use your own key:
export GROQ_API_KEY=your_key_here
```

### 3. Start Server
```bash
python main.py
```

## 🧪 Test It

### Quick Test
```bash
cd backend
python test_ai_assistant.py
```

### Manual API Test
```bash
# Test label suggestion
curl -X POST "http://localhost:8000/ai/suggest-label" \
  -H "Content-Type: application/json" \
  -d '{"node_type": "room", "number": "101"}'

# Test description generation  
curl -X POST "http://localhost:8000/ai/generate-landmark-description" \
  -H "Content-Type: application/json" \
  -d '{"node_type": "room", "label": "Room 101", "context": "CS Department"}'
```

## 📚 API Endpoints

### 1. Generate Label
**POST** `/ai/suggest-label`

```json
{
  "node_type": "room",
  "number": "101",
  "name": null
}
```

Response:
```json
{
  "label": "Room 101",
  "success": true
}
```

### 2. Generate Description
**POST** `/ai/generate-landmark-description`

```json
{
  "node_type": "room",
  "label": "Room 101",
  "context": "Computer Science Department"
}
```

Response:
```json
{
  "description": "Third floor, Computer Science wing. Look for room number 301...",
  "success": true
}
```

### 3. Get Node Types
**GET** `/ai/node-types`

Returns list of available node types with icons and metadata.

## 🎯 Node Types

| Type | Example Label | Needs Number? |
|------|--------------|---------------|
| room | Room 101 | ✅ Yes |
| entrance | Main Entrance | ❌ No |
| exit | Emergency Exit | ❌ No |
| elevator | Elevator A | ❌ No |
| stairs | Staircase 2 | ❌ No |
| bathroom | Restroom 1 | ❌ No |
| cafe | Café Starbucks | ❌ No |
| office | Office 205 | ✅ Yes |
| waypoint | Waypoint 5 | ❌ No |

## 🔧 How It Works

### Label Generation
1. Select node type from dropdown
2. Enter number/name if needed
3. API suggests appropriate label
4. User can edit or accept

### Description Generation
1. User provides node type and label
2. Optional: Add context (e.g., "near library")
3. AI generates 20-30 word description
4. User can edit or regenerate

### Fallback System
If Groq API fails, uses template-based descriptions:
- "Located at {label}. Look for the room number on the door."
- Always works, even without internet

## 📖 API Documentation

View full interactive docs:
```
http://localhost:8000/docs
```

## 🎨 Usage Workflow

### For Room:
1. Select "Room" from dropdown
2. Enter room number: "101"
3. Label auto-generated: "Room 101"
4. Click "Generate Description"
5. AI creates: "First floor, main corridor. Look for room 101 on the right..."
6. Edit if needed or accept

### For Cafe:
1. Select "Café" from dropdown
2. Enter name: "Starbucks"
3. Label auto-generated: "Café Starbucks"
4. Add context: "Near library entrance"
5. AI creates: "Ground floor, adjacent to library. Look for Starbucks signage..."

## ⚡ Benefits

### Less Manual Work
- ✅ Auto-generated labels
- ✅ AI-written descriptions
- ✅ Smart suggestions
- ✅ Context-aware

### Better Quality
- ✅ Consistent formatting
- ✅ Professional descriptions
- ✅ Navigation-focused
- ✅ 20-30 word limit

### User-Friendly
- ✅ Dropdown selection
- ✅ One-click generation
- ✅ Editable results
- ✅ Fast response

## 🐛 Troubleshooting

### API Not Working?
1. Check server is running: `http://localhost:8000/health`
2. Verify Groq API key is set
3. Check internet connection
4. Review logs for errors

### Descriptions Too Long/Short?
- AI targets 20-30 words
- Edit manually if needed
- Provide better context for improved results

### Wrong Label Format?
- Check node type is correct
- Verify number/name input
- Use custom name if needed

## 📝 Files Created

```
backend/
├── services/
│   └── groq_service.py          # Core AI service
├── routers/
│   └── ai_assistant.py          # API endpoints
├── test_ai_assistant.py         # Test script
└── requirements.txt             # Updated with groq

Updated:
└── main.py                      # Added AI router
```

## 🚀 Next Steps

1. **Install**: `pip install -r requirements.txt`
2. **Test**: `python test_ai_assistant.py`
3. **Run**: `python main.py`
4. **Use**: Call API endpoints from Flutter app

## 💡 Tips

- Add context for better descriptions
- Use specific node types
- Edit AI suggestions as needed
- Fallback templates always work
- Test with different inputs

## 🔐 Security

- API key stored in environment variable
- Input validation via Pydantic
- Error messages sanitized
- CORS configured

## 📞 Support

- API Docs: `http://localhost:8000/docs`
- Test Script: `python test_ai_assistant.py`
- Check logs for errors
- Verify API key is valid

---

**Ready to use!** 🎉

The backend is fully implemented and ready for Flutter integration.
