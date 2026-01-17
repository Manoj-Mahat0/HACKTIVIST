import 'dart:convert';
import 'pdr_engine.dart';
import '../database/local_database.dart';

class QRPositionReset {
  final PDREngine _pdrEngine;
  final LocalDatabase _database;

  QRPositionReset(this._pdrEngine, this._database);

  Future<bool> processQRCode(String qrData) async {
    try {
      // Parse QR code data
      final Map<String, dynamic> data = jsonDecode(qrData);

      // Validate required fields
      if (!data.containsKey('marker_id') ||
          !data.containsKey('floor') ||
          !data.containsKey('x') ||
          !data.containsKey('y') ||
          !data.containsKey('orientation')) {
        return false;
      }

      // Validate QR marker exists in database
      final marker = await _database.getQRMarker(data['marker_id']);
      if (marker == null) return false;

      // Reset PDR engine position
      _pdrEngine.resetPosition(
        data['x'].toDouble(),
        data['y'].toDouble(),
        data['floor'].toInt(),
        data['orientation'].toDouble(),
      );

      return true;
    } catch (e) {
      print('Invalid QR code: $e');
      return false;
    }
  }

  // Generate QR code data for admin
  static String generateQRData({
    required String markerId,
    required String buildingId,
    required int floor,
    required double x,
    required double y,
    required double orientation,
  }) {
    return jsonEncode({
      'marker_id': markerId,
      'building_id': buildingId,
      'floor': floor,
      'x': x,
      'y': y,
      'orientation': orientation,
    });
  }
}
