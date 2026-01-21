import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class DetectionLogger {
  File? _logFile;
  final List<DetectionEntry> _sessionDetections = [];
  
  Future<void> initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    _logFile = File('${directory.path}/detections_$timestamp.txt');
  }

  void logDetection(String objectName, double confidence) {
    final entry = DetectionEntry(
      timestamp: DateTime.now(),
      objectName: objectName,
      confidence: confidence,
    );
    _sessionDetections.add(entry);
  }

  Future<String> saveLog() async {
    if (_logFile == null) await initialize();
    
    final buffer = StringBuffer();
    buffer.writeln("=== Detection Log ===");
    buffer.writeln("Session: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}");
    buffer.writeln("Total Detections: ${_sessionDetections.length}");
    buffer.writeln("=" * 50);
    buffer.writeln("");
    
    // Group by object type
    final grouped = <String, int>{};
    for (final entry in _sessionDetections) {
      grouped[entry.objectName] = (grouped[entry.objectName] ?? 0) + 1;
    }
    
    buffer.writeln("SUMMARY:");
    grouped.forEach((object, count) {
      buffer.writeln("  - $object: seen $count times");
    });
    buffer.writeln("");
    
    buffer.writeln("DETAILED LOG:");
    for (final entry in _sessionDetections) {
      buffer.writeln(
        "[${DateFormat('HH:mm:ss').format(entry.timestamp)}] "
        "${entry.objectName} (${(entry.confidence * 100).toStringAsFixed(1)}%)"
      );
    }
    
    await _logFile!.writeAsString(buffer.toString());
    return _logFile!.path;
  }

  List<DetectionEntry> get sessionDetections => _sessionDetections;
  
  void clearSession() {
    _sessionDetections.clear();
  }
}

class DetectionEntry {
  final DateTime timestamp;
  final String objectName;
  final double confidence;

  DetectionEntry({
    required this.timestamp,
    required this.objectName,
    required this.confidence,
  });
}