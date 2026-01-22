import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tts_service.dart';
import '../services/detection_logger.dart';
import 'log_viewer_screen.dart';

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

  void _navigateToLogViewer() {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const LogViewerScreen()),
  );
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

  Future<void> _describeScene() async {
  // Placeholder for Gemini Nano integration
  await _ttsService.speak(
    "Scene description feature coming soon. "
    "Currently I can see ${_currentDetections.length} objects: "
    "${_currentDetections.map((d) => d.className).toSet().join(', ')}"
  );
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
    body: SafeArea(
      child: Column(
        children: [
          // ===== TOP BAR =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Vision Helper",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // Detection count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_currentDetections.length} objects",
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Settings/Log button
                    IconButton(
                      onPressed: () => _navigateToLogViewer(),
                      icon: const Icon(Icons.history, color: Colors.white, size: 28),
                      tooltip: 'View Detection History',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // ===== CAMERA VIEW (constrained, not fullscreen) =====
          Expanded(
            flex: 3,  // Takes 3/5 of available space
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: YOLOView(
                modelPath: 'yolov8s-worldv2_float32',
                task: YOLOTask.detect,
                onResult: _onDetectionResult,
              ),
            ),
          ),
          
          // ===== DETECTION RESULTS PANEL =====
          Expanded(
            flex: 2,  // Takes 2/5 of available space
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Detected Objects:",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _currentDetections.isEmpty
                        ? const Center(
                            child: Text(
                              "Point camera at objects...",
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _currentDetections.length,
                            itemBuilder: (context, index) {
                              final detection = _currentDetections[index];
                              final confidence = (detection.confidence * 100).toInt();
                              return _DetectionTile(
                                objectName: detection.className,
                                confidence: confidence,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          
          // ===== CONTROL BUTTONS =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Speech Toggle
                _ControlButton(
                  icon: _isSpeechEnabled ? Icons.volume_up : Icons.volume_off,
                  label: _isSpeechEnabled ? "Sound ON" : "Sound OFF",
                  color: _isSpeechEnabled ? Colors.green : Colors.red,
                  onPressed: () {
                    setState(() => _isSpeechEnabled = !_isSpeechEnabled);
                    _ttsService.speak(
                      _isSpeechEnabled 
                        ? "Voice announcements enabled" 
                        : "Voice announcements disabled"
                    );
                  },
                ),
                // Save Log
                _ControlButton(
                  icon: Icons.save_alt,
                  label: "Save Log",
                  color: Colors.blue,
                  onPressed: _saveDetectionLog,
                ),
                // Describe Scene (New feature - placeholder for now)
                _ControlButton(
                  icon: Icons.description,
                  label: "Describe",
                  color: Colors.purple,
                  onPressed: () => _describeScene(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
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

class _DetectionTile extends StatelessWidget {
  final String objectName;
  final int confidence;

  const _DetectionTile({
    required this.objectName,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getConfidenceColor(confidence).withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          // Confidence bar
          Container(
            width: 50,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.grey[800],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: confidence / 100,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _getConfidenceColor(confidence),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Object name
          Expanded(
            child: Text(
              objectName.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Percentage
          Text(
            "$confidence%",
            style: TextStyle(
              color: _getConfidenceColor(confidence),
              fontSize: 16,
              fontWeight: FontWeight.bold,
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