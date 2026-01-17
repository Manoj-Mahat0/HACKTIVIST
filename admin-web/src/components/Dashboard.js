import React, { useState, useEffect } from 'react';
import {
  Container,
  Grid,
  Card,
  CardContent,
  Typography,
  Box,
  Paper
} from '@mui/material';
import {
  Business as BuildingIcon,
  Layers as FloorIcon,
  Room as RoomIcon,
  Navigation as WaypointIcon
} from '@mui/icons-material';
import axios from 'axios';

const API_BASE_URL = 'http://localhost:8000';

function Dashboard() {
  const [analytics, setAnalytics] = useState({
    total_buildings: 0,
    total_floors: 0,
    total_rooms: 0,
    total_waypoints: 0,
    buildings: []
  });

  useEffect(() => {
    fetchAnalytics();
  }, []);

  const fetchAnalytics = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/admin/analytics/buildings`);
      setAnalytics(response.data);
    } catch (error) {
      console.error('Failed to fetch analytics:', error);
    }
  };

  const StatCard = ({ title, value, icon, color }) => (
    <Card sx={{ height: '100%' }}>
      <CardContent>
        <Box display="flex" alignItems="center" justifyContent="space-between">
          <Box>
            <Typography color="textSecondary" gutterBottom variant="overline">
              {title}
            </Typography>
            <Typography variant="h4" component="h2">
              {value}
            </Typography>
          </Box>
          <Box sx={{ color: color }}>
            {icon}
          </Box>
        </Box>
      </CardContent>
    </Card>
  );

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        Indoor Navigation Admin Dashboard
      </Typography>
      
      <Grid container spacing={3}>
        {/* Statistics Cards */}
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Buildings"
            value={analytics.total_buildings}
            icon={<BuildingIcon fontSize="large" />}
            color="primary.main"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Floors"
            value={analytics.total_floors}
            icon={<FloorIcon fontSize="large" />}
            color="secondary.main"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Rooms"
            value={analytics.total_rooms}
            icon={<RoomIcon fontSize="large" />}
            color="success.main"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Total Waypoints"
            value={analytics.total_waypoints}
            icon={<WaypointIcon fontSize="large" />}
            color="warning.main"
          />
        </Grid>

        {/* Recent Buildings */}
        <Grid item xs={12}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Recent Buildings
            </Typography>
            {analytics.buildings.length > 0 ? (
              analytics.buildings.slice(0, 5).map((building) => (
                <Box key={building.id} sx={{ mb: 2, p: 2, border: '1px solid #e0e0e0', borderRadius: 1 }}>
                  <Typography variant="subtitle1" fontWeight="bold">
                    {building.name}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    {building.address}
                  </Typography>
                  <Typography variant="caption" color="textSecondary">
                    Created: {new Date(building.created_at).toLocaleDateString()}
                  </Typography>
                </Box>
              ))
            ) : (
              <Typography variant="body2" color="textSecondary">
                No buildings created yet.
              </Typography>
            )}
          </Paper>
        </Grid>
      </Grid>
    </Container>
  );
}

export default Dashboard;