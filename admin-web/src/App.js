import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { AuthProvider } from './context/AuthContext';
import Dashboard from './components/Dashboard';
import BuildingManager from './components/BuildingManager';
import CoordinateInput from './components/CoordinateInput';
import Navigation from './components/Navigation';
import Login from './components/Login';
import PrivateRoute from './components/PrivateRoute';

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
  },
});

function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <AuthProvider>
          <div className="App">
            <Navigation />
            <Routes>
              <Route path="/login" element={<Login />} />
              <Route
                path="/"
                element={
                  <PrivateRoute>
                    <Dashboard />
                  </PrivateRoute>
                }
              />
              <Route
                path="/buildings"
                element={
                  <PrivateRoute>
                    <BuildingManager />
                  </PrivateRoute>
                }
              />
              <Route
                path="/coordinates"
                element={
                  <PrivateRoute>
                    <CoordinateInput />
                  </PrivateRoute>
                }
              />
            </Routes>
          </div>
        </AuthProvider>
      </Router>
    </ThemeProvider>
  );
}

export default App;