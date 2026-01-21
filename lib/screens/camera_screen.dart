import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tts_service.dart';
import '../services/detection_logger.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final TTSService _ttsService = TTSService();
  final DetectionLogger _logger = DetectionLogger();
  
  bool _hasPermission = false;
  bool _isLoading = true;
  bool _isSpeechEnabled = true;
  List<YOLOResult> _currentDetections = [];
  String _lastAnnouncedObject = "";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkPermissions();
    await _ttsService.initialize();
    await _logger.initialize();
    
    // Welcome message
    await _ttsService.speak("Vision Helper is ready. Point your camera at objects.");
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
    
    if (!status.isGranted) {
      await _ttsService.speak("Camera permission is needed to help you see objects");
    }
  }

  void _onDetectionResult(List<YOLOResult> results) {
    setState(() {
      _currentDetections = results;
    });
    
    // Announce the most confident detection
    if (results.isNotEmpty && _isSpeechEnabled) {
      // Sort by confidence and get the best one
      final bestResult = results.reduce((a, b) => 
        a.confidence > b.confidence ? a : b
      );
      
      // Log all detections
      for (final result in results) {
        _logger.logDetection(result.className, result.confidence);
      }
      
      // Announce if it's a new object or high confidence
      if (bestResult.className != _lastAnnouncedObject || 
          bestResult.confidence > 0.8) {
        _ttsService.announceObject(bestResult.className, bestResult.confidence);
        _lastAnnouncedObject = bestResult.className;
      }
    }
  }

  Future<void> _saveDetectionLog() async {
    final path = await _logger.saveLog();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log saved to: $path'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green,
        ),
      );
      await _ttsService.speak("Detection log saved");
    }
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Loading Vision Helper...",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "Camera Permission Needed",
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  "This app needs camera access to help identify objects around you.",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _checkPermissions,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40, 
                      vertical: 20,
                    ),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    "Grant Permission",
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // YOLO Camera View - THE MAIN COMPONENT
          YOLOView(
            modelPath: 'yolo11n',  // Matches the .tflite filename
            task: YOLOTask.detect,
            onResult: _onDetectionResult,
          ),
          
          // Top Info Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Vision Helper",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Detection count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, 
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_currentDetections.length} objects",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Detection List (Bottom Panel)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentDetections.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _currentDetections.length,
                        itemBuilder: (context, index) {
                          final detection = _currentDetections[index];
                          final confidence = (detection.confidence * 100).toInt();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                // Confidence indicator
                                Container(
                                  width: 60,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.grey[800],
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: detection.confidence,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: _getConfidenceColor(confidence),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    detection.className.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  "$confidence%",
                                  style: TextStyle(
                                    color: _getConfidenceColor(confidence),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  
                  // Control Buttons
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      top: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Toggle Speech Button
                        _ControlButton(
                          icon: _isSpeechEnabled 
                            ? Icons.volume_up 
                            : Icons.volume_off,
                          label: _isSpeechEnabled ? "Sound ON" : "Sound OFF",
                          color: _isSpeechEnabled ? Colors.green : Colors.red,
                          onPressed: () {
                            setState(() {
                              _isSpeechEnabled = !_isSpeechEnabled;
                            });
                            _ttsService.speak(
                              _isSpeechEnabled 
                                ? "Voice announcements enabled" 
                                : "Voice announcements disabled"
                            );
                          },
                        ),
                        
                        // Save Log Button
                        _ControlButton(
                          icon: Icons.save,
                          label: "Save Log",
                          color: Colors.blue,
                          onPressed: _saveDetectionLog,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.yellow;
    if (confidence >= 40) return Colors.orange;
    return Colors.red;
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}