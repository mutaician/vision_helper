import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../services/tts_service.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final TTSService _ttsService = TTSService();
  List<LogFile> _logFiles = [];
  bool _isLoading = true;
  String? _selectedLogContent;
  String? _selectedLogName;

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.txt') && f.path.contains('detections_')
    ).toList();
    
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    
    setState(() {
      _logFiles = files.map((f) => LogFile(
        file: f,
        name: f.path.split('/').last,
        date: f.lastModifiedSync(),
      )).toList();
      _isLoading = false;
    });
  }

  Future<void> _openLog(LogFile logFile) async {
    final content = await logFile.file.readAsString();
    setState(() {
      _selectedLogContent = content;
      _selectedLogName = logFile.name;
    });
  }

  Future<void> _deleteLog(LogFile logFile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Log?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${logFile.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await logFile.file.delete();
      _loadLogFiles();
      _ttsService.speak("Log deleted");
    }
  }

  Future<void> _readLogAloud() async {
    if (_selectedLogContent == null) return;
    
    // Extract summary section for reading
    final lines = _selectedLogContent!.split('\n');
    final summaryLines = <String>[];
    bool inSummary = false;
    
    for (final line in lines) {
      if (line.contains('SUMMARY:')) {
        inSummary = true;
        continue;
      }
      if (line.contains('DETAILED LOG:')) {
        break;
      }
      if (inSummary && line.trim().isNotEmpty) {
        summaryLines.add(line.replaceAll('  - ', '').replaceAll(': seen ', ', seen '));
      }
    }
    
    if (summaryLines.isNotEmpty) {
      await _ttsService.speak("Detection summary: ${summaryLines.join('. ')}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Detection History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedLogContent != null) {
              setState(() {
                _selectedLogContent = null;
                _selectedLogName = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_selectedLogContent != null)
            IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: _readLogAloud,
              tooltip: 'Read Aloud',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedLogContent != null
              ? _buildLogContent()
              : _buildLogList(),
    );
  }

  Widget _buildLogList() {
    if (_logFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No detection logs yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Use "Save Log" button to save detection history',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logFiles.length,
      itemBuilder: (context, index) {
        final logFile = _logFiles[index];
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description, color: Colors.blue, size: 28),
            ),
            title: Text(
              DateFormat('MMM dd, yyyy').format(logFile.date),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              DateFormat('hh:mm a').format(logFile.date),
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteLog(logFile),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: () => _openLog(logFile),
          ),
        );
      },
    );
  }

  Widget _buildLogContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.description, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedLogName ?? 'Log',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _selectedLogContent!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LogFile {
  final File file;
  final String name;
  final DateTime date;

  LogFile({required this.file, required this.name, required this.date});
}