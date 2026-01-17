import React, { useState } from 'react';
import {
  Container,
  Paper,
  Typography,
  TextField,
  Button,
  Grid,
  Box,
  Alert,
  List,
  ListItem,
  ListItemText,
  IconButton,
  FormControl,
  InputLabel,
  Select,
  MenuItem
} from '@mui/material';
import { Delete as DeleteIcon, Add as AddIcon } from '@mui/icons-material';
import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000';

function CoordinateInput() {
  const [buildingId, setBuildingId] = useState('');
  const [coordinates, setCoordinates] = useState([]);
  const [newCoordinate, setNewCoordinate] = useState({ latitude: '', longitude: '', floor_number: '' });
  const [message, setMessage] = useState('');
  const [messageType, setMessageType] = useState('info');

  const addCoordinate = () => {
    if (newCoordinate.latitude && newCoordinate.longitude && newCoordinate.floor_number) {
      setCoordinates([
        ...coordinates,
        {
          latitude: parseFloat(newCoordinate.latitude),
          longitude: parseFloat(newCoordinate.longitude),
          floor_number: parseInt(newCoordinate.floor_number)
        }
      ]);
      setNewCoordinate({ latitude: '', longitude: '', floor_number: '' });
    }
  };

  const removeCoordinate = (index) => {
    setCoordinates(coordinates.filter((_, i) => i !== index));
  };

  const generate3DModel = async () => {
    if (!buildingId || coordinates.length === 0) {
      setMessage('Please select a building and add coordinates');
      setMessageType('error');
      return;
    }

    try {
      const response = await axios.post(
        `${API_BASE_URL}/admin/buildings/${buildingId}/generate-3d`,
        coordinates
      );
      
      setMessage(`3D model generated successfully! Created ${response.data.rooms_created} rooms and ${response.data.waypoints_created} waypoints.`);
      setMessageType('success');
      setCoordinates([]);
    } catch (error) {
      setMessage('Failed to generate 3D model: ' + (error.response?.data?.detail || error.message));
      setMessageType('error');
    }
  };

  const loadSampleCoordinates = () => {
    const sampleCoords = [
      { latitude: 40.7128, longitude: -74.0060, floor_number: 0 },
      { latitude: 40.7129, longitude: -74.0061, floor_number: 0 },
      { latitude: 40.7130, longitude: -74.0062, floor_number: 0 },
      { latitude: 40.7131, longitude: -74.0063, floor_number: 0 },
      { latitude: 40.7128, longitude: -74.0060, floor_number: 1 },
      { latitude: 40.7129, longitude: -74.0061, floor_number: 1 },
      { latitude: 40.7130, longitude: -74.0062, floor_number: 1 },
      { latitude: 40.7131, longitude: -74.0063, floor_number: 1 }
    ];
    setCoordinates(sampleCoords);
  };

  return (
    <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        3D Model Generator
      </Typography>
      
      <Paper sx={{ p: 3 }}>
        <Typography variant="h6" gutterBottom>
          Create 3D Building Structure from Coordinates
        </Typography>
        
        {message && (
          <Alert severity={messageType} sx={{ mb: 2 }}>
            {message}
          </Alert>
        )}

        <Grid container spacing={3}>
          <Grid item xs={12}>
            <FormControl fullWidth>
              <InputLabel>Building ID</InputLabel>
              <Select
                value={buildingId}
                label="Building ID"
                onChange={(e) => setBuildingId(e.target.value)}
              >
                <MenuItem value={1}>Building 1 - Sample Office</MenuItem>
                <MenuItem value={2}>Building 2 - Sample Mall</MenuItem>
                <MenuItem value={3}>Building 3 - Sample Hospital</MenuItem>
              </Select>
            </FormControl>
          </Grid>

          <Grid item xs={12}>
            <Typography variant="h6" gutterBottom>
              Add GPS Coordinates (Latitude, Longitude, Floor)
            </Typography>
            <Box display="flex" gap={2} alignItems="center" mb={2}>
              <TextField
                label="Latitude"
                type="number"
                value={newCoordinate.latitude}
                onChange={(e) => setNewCoordinate({ ...newCoordinate, latitude: e.target.value })}
                size="small"
                inputProps={{ step: "0.000001" }}
              />
              <TextField
                label="Longitude"
                type="number"
                value={newCoordinate.longitude}
                onChange={(e) => setNewCoordinate({ ...newCoordinate, longitude: e.target.value })}
                size="small"
                inputProps={{ step: "0.000001" }}
              />
              <TextField
                label="Floor"
                type="number"
                value={newCoordinate.floor_number}
                onChange={(e) => setNewCoordinate({ ...newCoordinate, floor_number: e.target.value })}
                size="small"
              />
              <Button
                variant="contained"
                startIcon={<AddIcon />}
                onClick={addCoordinate}
              >
                Add
              </Button>
            </Box>
            
            <Button
              variant="outlined"
              onClick={loadSampleCoordinates}
              sx={{ mb: 2 }}
            >
              Load Sample Coordinates
            </Button>
          </Grid>

          <Grid item xs={12}>
            <Typography variant="h6" gutterBottom>
              Coordinates List ({coordinates.length} points)
            </Typography>
            <Paper variant="outlined" sx={{ maxHeight: 300, overflow: 'auto' }}>
              <List>
                {coordinates.map((coord, index) => (
                  <ListItem
                    key={index}
                    secondaryAction={
                      <IconButton
                        edge="end"
                        onClick={() => removeCoordinate(index)}
                      >
                        <DeleteIcon />
                      </IconButton>
                    }
                  >
                    <ListItemText
                      primary={`Point ${index + 1}`}
                      secondary={`Lat: ${coord.latitude}, Lng: ${coord.longitude}, Floor: ${coord.floor_number}`}
                    />
                  </ListItem>
                ))}
                {coordinates.length === 0 && (
                  <ListItem>
                    <ListItemText primary="No coordinates added yet" />
                  </ListItem>
                )}
              </List>
            </Paper>
          </Grid>

          <Grid item xs={12}>
            <Button
              variant="contained"
              size="large"
              onClick={generate3DModel}
              disabled={!buildingId || coordinates.length === 0}
              fullWidth
            >
              Generate 3D Model with AI
            </Button>
          </Grid>
        </Grid>
      </Paper>
    </Container>
  );
}

export default CoordinateInput;