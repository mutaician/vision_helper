import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  DateTime? _lastSpoken;
  String? _lastObject;
  
  // Cooldown to prevent repeating same object
  static const int speakCooldownMs = 3000;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(1);  // Slower for elderly users
    await _flutterTts.setVolume(1.0);       // Maximum volume
    await _flutterTts.setPitch(1.0);
    
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    
    // Prevent repeating same object too quickly
    final now = DateTime.now();
    if (_lastObject == text && 
        _lastSpoken != null &&
        now.difference(_lastSpoken!).inMilliseconds < speakCooldownMs) {
      return;
    }
    
    _lastObject = text;
    _lastSpoken = now;
    
    await _flutterTts.speak(text);
  }

  Future<void> announceObject(String objectName, double confidence) async {
    // Only announce if confidence is high enough
    if (confidence > 0.6) {
      final percent = (confidence * 100).toInt();
      await speak("$objectName detected, $percent percent sure");
    }
  }
  
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void dispose() {
    _flutterTts.stop();
  }
}