import React, { useState, useEffect } from 'react';
import {
  Container,
  Paper,
  Typography,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Grid,
  Card,
  CardContent,
  CardActions,
  Box,
  Alert
} from '@mui/material';
import { Add as AddIcon, Edit as EditIcon, Delete as DeleteIcon } from '@mui/icons-material';
import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000';

function BuildingManager() {
  const [buildings, setBuildings] = useState([]);
  const [open, setOpen] = useState(false);
  const [editingBuilding, setEditingBuilding] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    address: '',
    latitude: '',
    longitude: ''
  });
  const [message, setMessage] = useState('');
  const [messageType, setMessageType] = useState('info');

  useEffect(() => {
    fetchBuildings();
  }, []);

  const fetchBuildings = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/buildings/`);
      setBuildings(response.data);
    } catch (error) {
      setMessage('Failed to fetch buildings: ' + error.message);
      setMessageType('error');
    }
  };

  const handleSubmit = async () => {
    try {
      if (editingBuilding) {
        // Update existing building
        await axios.put(`${API_BASE_URL}/buildings/${editingBuilding.id}`, formData);
        setMessage('Building updated successfully!');
      } else {
        // Create new building
        await axios.post(`${API_BASE_URL}/buildings/`, formData);
        setMessage('Building created successfully!');
      }
      setMessageType('success');
      setOpen(false);
      resetForm();
      fetchBuildings();
    } catch (error) {
      setMessage('Failed to save building: ' + (error.response?.data?.detail || error.message));
      setMessageType('error');
    }
  };

  const handleEdit = (building) => {
    setEditingBuilding(building);
    setFormData({
      name: building.name,
      description: building.description || '',
      address: building.address,
      latitude: building.latitude.toString(),
      longitude: building.longitude.toString()
    });
    setOpen(true);
  };

  const handleDelete = async (buildingId) => {
    if (window.confirm('Are you sure you want to delete this building?')) {
      try {
        await axios.delete(`${API_BASE_URL}/buildings/${buildingId}`);
        setMessage('Building deleted successfully!');
        setMessageType('success');
        fetchBuildings();
      } catch (error) {
        setMessage('Failed to delete building: ' + error.message);
        setMessageType('error');
      }
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      description: '',
      address: '',
      latitude: '',
      longitude: ''
    });
    setEditingBuilding(null);
  };

  const handleClose = () => {
    setOpen(false);
    resetForm();
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" component="h1">
          Building Management
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => setOpen(true)}
        >
          Add Building
        </Button>
      </Box>

      {message && (
        <Alert severity={messageType} sx={{ mb: 2 }}>
          {message}
        </Alert>
      )}

      <Grid container spacing={3}>
        {buildings.map((building) => (
          <Grid item xs={12} md={6} lg={4} key={building.id}>
            <Card>
              <CardContent>
                <Typography variant="h6" component="h2" gutterBottom>
                  {building.name}
                </Typography>
                <Typography variant="body2" color="textSecondary" gutterBottom>
                  {building.address}
                </Typography>
                <Typography variant="body2">
                  {building.description || 'No description'}
                </Typography>
                <Typography variant="caption" display="block" sx={{ mt: 1 }}>
                  Coordinates: {building.latitude}, {building.longitude}
                </Typography>
              </CardContent>
              <CardActions>
                <Button
                  size="small"
                  startIcon={<EditIcon />}
                  onClick={() => handleEdit(building)}
                >
                  Edit
                </Button>
                <Button
                  size="small"
                  color="error"
                  startIcon={<DeleteIcon />}
                  onClick={() => handleDelete(building.id)}
                >
                  Delete
                </Button>
              </CardActions>
            </Card>
          </Grid>
        ))}
      </Grid>

      {buildings.length === 0 && (
        <Paper sx={{ p: 4, textAlign: 'center', mt: 3 }}>
          <Typography variant="h6" color="textSecondary">
            No buildings found
          </Typography>
          <Typography variant="body2" color="textSecondary" sx={{ mt: 1 }}>
            Click "Add Building" to create your first building
          </Typography>
        </Paper>
      )}

      {/* Add/Edit Dialog */}
      <Dialog open={open} onClose={handleClose} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingBuilding ? 'Edit Building' : 'Add New Building'}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Building Name"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Address"
                value={formData.address}
                onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Description"
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                multiline
                rows={3}
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth
                label="Latitude"
                type="number"
                value={formData.latitude}
                onChange={(e) => setFormData({ ...formData, latitude: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                fullWidth
                label="Longitude"
                type="number"
                value={formData.longitude}
                onChange={(e) => setFormData({ ...formData, longitude: e.target.value })}
                required
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose}>Cancel</Button>
          <Button onClick={handleSubmit} variant="contained">
            {editingBuilding ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

export default BuildingManager;