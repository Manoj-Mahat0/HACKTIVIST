import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isBusy = false;

  Future<String?> processImage(InputImage inputImage) async {
    if (_isBusy) return null;
    _isBusy = true;

    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Heuristic: Return the most prominent block or line
      // For now, let's return the largest block of text found
      if (recognizedText.blocks.isEmpty) return null;

      String? bestText;
      double maxArea = 0;

      for (TextBlock block in recognizedText.blocks) {
        final area = block.boundingBox.width * block.boundingBox.height;
        if (area > maxArea) {
          maxArea = area;
          bestText = block.text;
        }
      }
      return bestText;
    } catch (e) {
      debugPrint('OCR Error: $e');
      return null;
    } finally {
      _isBusy = false;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
