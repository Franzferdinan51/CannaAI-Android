// Live Vision camera service for CannaAI Android
// Real-time camera analysis with multiple modes

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/comprehensive/data_models.dart';
import 'comprehensive_api_service.dart';
import 'comprehensive_ai_assistant_service.dart';

class LiveVisionService {
  static final LiveVisionService _instance = LiveVisionService._internal();
  factory LiveVisionService() => _instance;
  LiveVisionService._internal();

  final Logger _logger = Logger();
  final APIService _apiService = APIService();
  final AIAssistantService _aiService = AIAssistantService();

  // Camera controllers
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;

  // Live vision state
  bool _isStreaming = false;
  String? _currentSessionId;
  LiveVisionMode _currentMode = LiveVisionMode.standard;
  AnalysisType _analysisType = AnalysisType.health;

  // Image analysis
  final Map<String, StreamController<LiveVisionEvent>> _eventControllers = {};
  Timer? _analysisTimer;
  Duration _analysisInterval = const Duration(seconds: 5);

  // Camera settings
  ResolutionPreset _resolution = ResolutionPreset.high;
  FlashMode _flashMode = FlashMode.off;
  double _zoomLevel = 1.0;
  Point<double>? _focusPoint;

  // Recording
  bool _isRecording = false;
  List<String> _capturedImages = [];
  List<String> _analysisResults = [];

  // Microscope mode
  bool _microscopeMode = false;
  double _magnification = 1.0;

  // ==================== INITIALIZATION ====================

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeCameras();
      await _initializeEventControllers();
      _isInitialized = true;
      _logger.i('Live Vision Service initialized');
    } catch (e) {
      _logger.e('Failed to initialize Live Vision Service: $e');
    }
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Prefer back camera
        _selectedCameraIndex = _cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
        if (_selectedCameraIndex == -1) {
          _selectedCameraIndex = 0;
        }
      }
    } catch (e) {
      _logger.e('Failed to initialize cameras: $e');
    }
  }

  Future<void> _initializeEventControllers() async {
    _eventControllers['live_vision'] = StreamController<LiveVisionEvent>.broadcast();
    _eventControllers['analysis'] = StreamController<LiveVisionEvent>.broadcast();
    _eventControllers['recording'] = StreamController<LiveVisionEvent>.broadcast();
  }

  // ==================== CAMERA MANAGEMENT ====================

  Future<void> startCamera() async {
    try {
      if (_cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      final camera = _cameras[_selectedCameraIndex];
      _cameraController = CameraController(
        camera,
        _resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      _emitEvent(LiveVisionEvent.cameraInitialized());
      _logger.i('Camera started: ${camera.name}');
    } catch (e) {
      _logger.e('Failed to start camera: $e');
      _emitEvent(LiveVisionEvent.error('Failed to start camera: $e'));
    }
  }

  Future<void> stopCamera() async {
    try {
      await _cameraController?.dispose();
      _cameraController = null;
      _emitEvent(LiveVisionEvent.cameraStopped());
      _logger.i('Camera stopped');
    } catch (e) {
      _logger.e('Failed to stop camera: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      await stopCamera();
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      await startCamera();
      _emitEvent(LiveVisionEvent.cameraSwitched(_cameras[_selectedCameraIndex].name));
    } catch (e) {
      _logger.e('Failed to switch camera: $e');
    }
  }

  // ==================== LIVE VISION SESSIONS ====================

  Future<String?> startLiveVision({
    LiveVisionMode mode = LiveVisionMode.standard,
    AnalysisType analysisType = AnalysisType.health,
    String? roomId,
    String? plantId,
  }) async {
    try {
      if (_isStreaming) {
        await stopLiveVision();
      }

      // Start camera if not already started
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        await startCamera();
      }

      // Create session on server
      _currentSessionId = await _apiService.startLiveVision(roomId ?? '');

      if (_currentSessionId == null) {
        _currentSessionId = _generateLocalSessionId();
      }

      _currentMode = mode;
      _analysisType = analysisType;

      // Start streaming
      await _cameraController!.startImageStream();
      _isStreaming = true;

      // Start periodic analysis
      _startPeriodicAnalysis();

      _emitEvent(LiveVisionEvent.sessionStarted(_currentSessionId!, mode, analysisType));
      _logger.i('Live Vision started: Mode=$mode, Analysis=$analysisType');

      return _currentSessionId;
    } catch (e) {
      _logger.e('Failed to start live vision: $e');
      _emitEvent(LiveVisionEvent.error('Failed to start live vision: $e'));
      return null;
    }
  }

  Future<void> stopLiveVision() async {
    try {
      if (!_isStreaming) return;

      // Stop analysis timer
      _analysisTimer?.cancel();
      _analysisTimer = null;

      // Stop image stream
      await _cameraController?.stopImageStream();

      // Stop session on server
      if (_currentSessionId != null) {
        await _apiService.stopLiveVision(_currentSessionId!);
      }

      _isStreaming = false;
      _currentSessionId = null;

      _emitEvent(LiveVisionEvent.sessionStopped());
      _logger.i('Live Vision stopped');
    } catch (e) {
      _logger.e('Failed to stop live vision: $e');
    }
  }

  String _generateLocalSessionId() {
    return 'local_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ==================== CAMERA CONTROLS ====================

  Future<void> setResolution(ResolutionPreset resolution) async {
    try {
      _resolution = resolution;
      if (_cameraController != null) {
        await stopCamera();
        await startCamera();
      }
    } catch (e) {
      _logger.e('Failed to set resolution: $e');
    }
  }

  Future<void> setFlashMode(FlashMode flashMode) async {
    try {
      _flashMode = flashMode;
      await _cameraController?.setFlashMode(flashMode);
      _emitEvent(LiveVisionEvent.flashChanged(flashMode));
    } catch (e) {
      _logger.e('Failed to set flash mode: $e');
    }
  }

  Future<void> setZoom(double zoom) async {
    try {
      final maxZoom = await _cameraController?.getMaxZoomLevel() ?? 1.0;
      _zoomLevel = zoom.clamp(1.0, maxZoom);
      await _cameraController?.setZoomLevel(_zoomLevel);
      _emitEvent(LiveVisionEvent.zoomChanged(_zoomLevel));
    } catch (e) {
      _logger.e('Failed to set zoom: $e');
    }
  }

  Future<void> setFocusPoint(Point<double> point) async {
    try {
      _focusPoint = point;
      await _cameraController?.setFocusPoint(point);
      _emitEvent(LiveVisionEvent.focusChanged(point));
    } catch (e) {
      _logger.e('Failed to set focus point: $e');
    }
  }

  Future<void> setMode(LiveVisionMode mode) async {
    try {
      _currentMode = mode;

      // Adjust camera settings for mode
      switch (mode) {
        case LiveVisionMode.microscope:
          _magnification = 4.0;
          await setZoom(4.0);
          break;
        case LiveVisionMode.standard:
          _magnification = 1.0;
          await setZoom(1.0);
          break;
        case LiveVisionMode.wide:
          _magnification = 0.5;
          await setZoom(0.5);
          break;
      }

      _emitEvent(LiveVisionEvent.modeChanged(mode));
    } catch (e) {
      _logger.e('Failed to set mode: $e');
    }
  }

  // ==================== IMAGE CAPTURE & ANALYSIS ====================

  Future<String?> captureImage({bool analyze = true}) async {
    try {
      if (_cameraController == null) {
        throw Exception('Camera not initialized');
      }

      final XFile imageFile = await _cameraController!.takePicture();
      _capturedImages.add(imageFile.path);

      _emitEvent(LiveVisionEvent.imageCaptured(imageFile.path));

      if (analyze) {
        await _analyzeImage(File(imageFile.path));
      }

      return imageFile.path;
    } catch (e) {
      _logger.e('Failed to capture image: $e');
      _emitEvent(LiveVisionEvent.error('Failed to capture image: $e'));
      return null;
    }
  }

  Future<AnalysisResult?> _analyzeImage(File imageFile) async {
    try {
      _emitEvent(LiveVisionEvent.analysisStarted());

      // Analyze with AI service
      final result = await _aiService.analyzeImage(
        imageFile,
        type: _analysisType,
      );

      if (result != null) {
        _analysisResults.add(result.id);
        _emitEvent(LiveVisionEvent.analysisCompleted(result));
      } else {
        _emitEvent(LiveVisionEvent.analysisFailed('Analysis returned null'));
      }

      return result;
    } catch (e) {
      _logger.e('Failed to analyze image: $e');
      _emitEvent(LiveVisionEvent.analysisFailed('Analysis failed: $e'));
      return null;
    }
  }

  void _startPeriodicAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(_analysisInterval, (_) {
      if (_isStreaming) {
        _performPeriodicAnalysis();
      }
    });
  }

  Future<void> _performPeriodicAnalysis() async {
    try {
      if (_cameraController != null) {
        // Capture image from stream
        final imageStream = _cameraController!.startImageStream();

        // Process first frame from stream
        await for (final image in imageStream) {
          final bytes = await image.readAsBytes();
          final file = await _saveFrameAsFile(bytes);

          if (file != null) {
            await _analyzeImage(file);
          }
          break; // Only analyze first frame per interval
        }
      }
    } catch (e) {
      _logger.e('Failed to perform periodic analysis: $e');
    }
  }

  Future<File?> _saveFrameAsFile(Uint8List bytes) async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'frame_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(directory.path, fileName);

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      _logger.e('Failed to save frame as file: $e');
      return null;
    }
  }

  // ==================== RECORDING ====================

  Future<void> startRecording() async {
    try {
      if (_isRecording) return;

      if (_cameraController == null) {
        throw Exception('Camera not initialized');
      }

      await _cameraController!.startVideoRecording();
      _isRecording = true;

      _emitEvent(LiveVisionEvent.recordingStarted());
      _logger.i('Recording started');
    } catch (e) {
      _logger.e('Failed to start recording: $e');
      _emitEvent(LiveVisionEvent.error('Failed to start recording: $e'));
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final videoFile = await _cameraController?.stopVideoRecording();
      _isRecording = false;

      if (videoFile != null) {
        _emitEvent(LiveVisionEvent.recordingStopped(videoFile.path));
        _logger.i('Recording stopped: ${videoFile.path}');
        return videoFile.path;
      }

      return null;
    } catch (e) {
      _logger.e('Failed to stop recording: $e');
      _emitEvent(LiveVisionEvent.error('Failed to stop recording: $e'));
      return null;
    }
  }

  // ==================== TIME-LAPSE PHOTOGRAPHY ====================

  Future<void> startTimeLapse({
    Duration interval = const Duration(seconds: 30),
    Duration duration = const Duration(hours: 2),
    String? roomId,
  }) async {
    try {
      if (_isRecording) return;

      final sessionId = await startLiveVision(
        roomId: roomId,
        mode: LiveVisionMode.standard,
        analysisType: AnalysisType.health,
      );

      if (sessionId == null) {
        throw Exception('Failed to start live vision for time-lapse');
      }

      // Capture images at interval
      final timer = Timer.periodic(interval, (_) async {
        await captureImage(analyze: false);
      });

      // Stop after duration
      Timer(duration, () async {
        timer.cancel();
        await stopLiveVision();

        // Create time-lapse video from captured images
        await createTimeLapseVideo(_capturedImages);
      });

      _emitEvent(LiveVisionEvent.timeLapseStarted(interval, duration));
      _logger.i('Time-lapse started: ${interval.inSeconds}s intervals for ${duration.inHours}h');
    } catch (e) {
      _logger.e('Failed to start time-lapse: $e');
      _emitEvent(LiveVisionEvent.error('Failed to start time-lapse: $e'));
    }
  }

  Future<String?> createTimeLapseVideo(List<String> imagePaths) async {
    try {
      _emitEvent(LiveVisionEvent.timeLapseProcessing(imagePaths.length));

      // TODO: Implement video creation from images
      // This would use a library like FFMPEG or video_encoder

      _emitEvent(LiveVisionEvent.timeLapseCompleted('time_lapse_video.mp4'));
      return 'time_lapse_video.mp4';
    } catch (e) {
      _logger.e('Failed to create time-lapse video: $e');
      _emitEvent(LiveVisionEvent.error('Failed to create time-lapse video: $e'));
      return null;
    }
  }

  // ==================== IMAGE PROCESSING ====================

  Future<Map<String, dynamic>> processImageForTrichomeAnalysis(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Extract regions of interest for trichome analysis
      final regions = await _extractTrichomeRegions(image);

      // Analyze each region
      final results = <String, dynamic>{};
      for (int i = 0; i < regions.length; i++) {
        final regionResult = await _analyzeTrichomeRegion(regions[i]);
        results['region_$i'] = regionResult;
      }

      return {
        'regions': results,
        'totalRegions': regions.length,
        'averageClarity': _calculateAverageClarity(results),
        'maturityLevel': _calculateMaturityLevel(results),
      };
    } catch (e) {
      _logger.e('Failed to process image for trichome analysis: $e');
      return {};
    }
  }

  Future<img.Image> _extractTrichomeRegion(img.Image originalImage) async {
    // TODO: Implement trichome region extraction
    // This would identify areas likely to contain trichomes
    return originalImage;
  }

  Future<Map<String, dynamic>> _analyzeTrichomeRegion(img.Image region) async {
    // TODO: Implement trichome region analysis
    return {
      'clarity': 0.0,
      'maturity': 0.0,
      'colorAnalysis': {},
    };
  }

  double _calculateAverageClarity(Map<String, dynamic> results) {
    double totalClarity = 0.0;
    int regionCount = 0;

    for (final region in results.values) {
      if (region['clarity'] != null) {
        totalClarity += region['clarity'] as double;
        regionCount++;
      }
    }

    return regionCount > 0 ? totalClarity / regionCount : 0.0;
  }

  String _calculateMaturityLevel(Map<String, dynamic> results) {
    double totalMaturity = 0.0;
    int regionCount = 0;

    for (final region in results.values) {
      if (region['maturity'] != null) {
        totalMaturity += region['maturity'] as double;
        regionCount++;
      }
    }

    if (regionCount == 0) return 'unknown';

    final average = totalMaturity / regionCount;

    if (average < 0.3) return 'clear';
    if (average < 0.6) return 'milky';
    if (average < 0.8) return 'cloudy';
    return 'amber';
  }

  // ==================== ANNOTATION TOOLS ====================

  Future<void> addAnnotation(String imagePath, Map<String, dynamic> annotation) async {
    try {
      // TODO: Implement image annotation
      _emitEvent(LiveVisionEvent.annotationAdded(annotation));
    } catch (e) {
      _logger.e('Failed to add annotation: $e');
    }
  }

  Future<void> removeAnnotation(String annotationId) async {
    try {
      // TODO: Implement annotation removal
      _emitEvent(LiveVisionEvent.annotationRemoved(annotationId));
    } catch (e) {
      _logger.e('Failed to remove annotation: $e');
    }
  }

  // ==================== IMAGE ENHANCEMENT ====================

  Future<String?> enhanceImage(String imagePath, {ImageEnhancement enhancement = ImageEnhancement.sharpen}) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      img.Image enhancedImage = image;

      switch (enhancement) {
        case ImageEnhancement.sharpen:
          enhancedImage = img.Image sharpen(image);
          break;
        case ImageEnhancement.brightness:
          enhancedImage = img.Image.adjustBrightness(image, 20);
          break;
        case ImageEnhancement.contrast:
          enhancedImage = img.Image.adjustColor(image, contrast: 1.2);
          break;
        case ImageEnhancement.saturation:
          enhancedImage = img.Image.adjustColor(image, saturation: 1.3);
          break;
      }

      final enhancedPath = _saveEnhancedImage(enhancedImage, imagePath);
      if (enhancedPath != null) {
        _emitEvent(LiveVisionEvent.imageEnhanced(enhancement));
      }

      return enhancedPath;
    } catch (e) {
      _logger.e('Failed to enhance image: $e');
      return null;
    }
  }

  Future<String?> _saveEnhancedImage(img.Image enhancedImage, String originalPath) async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'enhanced_${path.basenameWithoutExtension(originalPath)}.jpg';
      final enhancedPath = path.join(directory.path, fileName);

      final enhancedFile = File(enhancedPath);
      await enhancedFile.writeAsBytes(encodeJpg(enhancedImage));

      return enhancedPath;
    } catch (e) {
      _logger.e('Failed to save enhanced image: $e');
      return null;
    }
  }

  // ==================== MEASUREMENT TOOLS ====================

  Future<MeasurementResult?> measureDistance(Point<double> start, Point<double> end) async {
    try {
      // Calculate pixel distance
      final pixelDistance = _calculatePixelDistance(start, end);

      // Convert to real-world units (assuming calibration)
      final realDistance = _pixelDistance * 0.0254; // 254 DPI = 0.0254mm per pixel

      return MeasurementResult(
        start: start,
        end: end,
        pixelDistance: pixelDistance,
        realDistance: realDistance,
        unit: 'mm',
      );
    } catch (e) {
      _logger.e('Failed to measure distance: $e');
      return null;
    }
  }

  double _calculatePixelDistance(Point<double> start, Point<double> end) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    return (dx * dx + dy * dy).abs();
  }

  // ==================== EVENTS & STREAMS ====================

  Stream<LiveVisionEvent> getEvents({String? eventType}) {
    if (eventType != null && _eventControllers.containsKey(eventType)) {
      return _eventControllers[eventType]!.stream;
    }
    return _eventControllers['live_vision']!.stream;
  }

  Stream<LiveVisionEvent> getAnalysisEvents() {
    return _eventControllers['analysis']!.stream;
  }

  Stream<LiveVisionEvent> getRecordingEvents() {
    return _eventControllers['recording']!.stream;
  }

  void _emitEvent(LiveVisionEvent event) {
    // Emit to general stream
    final generalController = _eventControllers['live_vision'];
    if (generalController != null && !generalController.isClosed) {
      generalController.add(event);
    }

    // Emit to specific stream
    String? eventType;
    switch (event.type) {
      case LiveVisionEventType.analysisStarted:
      case LiveVisionEventType.analysisCompleted:
      case LiveVisionEventType.analysisFailed:
        eventType = 'analysis';
        break;
      case LiveVisionEventType.recordingStarted:
      case LiveVisionEventType.recordingStopped:
        eventType = 'recording';
        break;
      default:
        break;
    }

    if (eventType != null) {
      final controller = _eventControllers[eventType];
      if (controller != null && !controller.isClosed) {
        controller.add(event);
      }
    }
  }

  // ==================== GETTERS & STATE ====================

  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  bool get isRecording => _isRecording;
  String? get currentSessionId => _currentSessionId;
  LiveVisionMode get currentMode => _currentMode;
  AnalysisType get currentAnalysisType => _analysisType;
  ResolutionPreset get currentResolution => _resolution;
  FlashMode get currentFlashMode => _flashMode;
  double get currentZoom => _zoomLevel;
  bool get microscopeMode => _microscopeMode;
  double get currentMagnification => _magnification;
  List<String> get capturedImages => List.from(_capturedImages);
  List<String> get analysisResults => List.from(_analysisResults);

  CameraController? get cameraController => _cameraController;
  List<CameraDescription> get availableCameras => List.from(_cameras);
  int get selectedCameraIndex => _selectedCameraIndex;

  // ==================== CLEANUP ====================

  Future<void> dispose() async {
    try {
      await stopLiveVision();
      await stopCamera();

      for (final controller in _eventControllers.values) {
        controller.close();
      }
      _eventControllers.clear();

      _capturedImages.clear();
      _analysisResults.clear();

      _isInitialized = false;
    } catch (e) {
      _logger.e('Failed to dispose Live Vision Service: $e');
    }
  }
}

// ==================== SUPPORTING CLASSES ====================

class LiveVisionEvent {
  final LiveVisionEventType type;
  final String? message;
  final String? sessionId;
  final LiveVisionMode? mode;
  final AnalysisType? analysisType;
  final String? imagePath;
  final AnalysisResult? analysisResult;
  final String? videoPath;
  final Duration? interval;
  final Duration? duration;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  LiveVisionEvent({
    required this.type,
    this.message,
    this.sessionId,
    this.mode,
    this.analysisType,
    this.imagePath,
    this.analysisResult,
    this.videoPath,
    this.interval,
    this.duration,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LiveVisionEvent.cameraInitialized() {
    return LiveVisionEvent(type: LiveVisionEventType.cameraInitialized);
  }

  factory LiveVisionEvent.cameraStopped() {
    return LiveVisionEvent(type: LiveVisionEventType.cameraStopped);
  }

  factory LiveVisionEvent.cameraSwitched(String cameraName) {
    return LiveVisionEvent(
      type: LiveVisionEventType.cameraSwitched,
      message: cameraName,
    );
  }

  factory LiveVisionEvent.sessionStarted(String sessionId, LiveVisionMode mode, AnalysisType analysisType) {
    return LiveVisionEvent(
      type: LiveVisionEventType.sessionStarted,
      sessionId: sessionId,
      mode: mode,
      analysisType: analysisType,
    );
  }

  factory LiveVisionEvent.sessionStopped() {
    return LiveVisionEvent(type: LiveVisionEventType.sessionStopped);
  }

  factory LiveVisionEvent.imageCaptured(String imagePath) {
    return LiveVisionEvent(
      type: LiveVisionEventType.imageCaptured,
      imagePath: imagePath,
    );
  }

  factory LiveVisionEvent.flashChanged(FlashMode flashMode) {
    return LiveVisionEvent(
      type: LiveVisionEventType.flashChanged,
      message: flashMode.name,
    );
  }

  factory LiveVisionEvent.zoomChanged(double zoomLevel) {
    return LiveVisionEvent(
      type: LiveVisionEventType.zoomChanged,
      message: zoomLevel.toString(),
    );
  }

  factory LiveVisionEvent.focusChanged(Point<double> focusPoint) {
    return LiveVisionEvent(
      type: LiveVisionEventType.focusChanged,
      message: '${focusPoint.x}, ${focusPoint.y}',
    );
  }

  factory LiveVisionEvent.modeChanged(LiveVisionMode mode) {
    return LiveVisionEvent(
      type: LiveVisionEventType.modeChanged,
      mode: mode,
    );
  }

  factory LiveVisionEvent.analysisStarted() {
    return LiveVisionEvent(type: LiveVisionEventType.analysisStarted);
  }

  factory LiveVisionEvent.analysisCompleted(AnalysisResult result) {
    return LiveVisionEvent(
      type: LiveVisionEventType.analysisCompleted,
      analysisResult: result,
    );
  }

  factory LiveVisionEvent.analysisFailed(String error) {
    return LiveVisionEvent(
      type: LiveVisionEventType.analysisFailed,
      message: error,
    );
  }

  factory LiveVisionEvent.recordingStarted() {
    return LiveVisionEvent(type: LiveVisionEventType.recordingStarted);
  }

  factory LiveVisionEvent.recordingStopped(String videoPath) {
    return LiveVisionEvent(
      type: LiveVisionEventType.recordingStopped,
      videoPath: videoPath,
    );
  }

  factory LiveVisionEvent.timeLapseStarted(Duration interval, Duration duration) {
    return LiveVisionEvent(
      type: LiveVisionEventType.timeLapseStarted,
      interval: interval,
      duration: duration,
    );
  }

  factory LiveVisionEvent.timeLapseProcessing(int imageCount) {
    return LiveVisionEvent(
      type: LiveVisionEventType.timeLapseProcessing,
      message: 'Processing $imageCount images',
    );
  }

  factory LiveVisionEvent.timeLapseCompleted(String videoPath) {
    return LiveVisionEvent(
      type: LiveVisionEventType.timeLapseCompleted,
      videoPath: videoPath,
    );
  }

  factory LiveVisionEvent.annotationAdded(Map<String, dynamic> annotation) {
    return LiveVisionEvent(
      type: LiveVisionEventType.annotationAdded,
      metadata: annotation,
    );
  }

  factory LiveVisionEvent.annotationRemoved(String annotationId) {
    return LiveVisionEvent(
      type: LiveVisionEventType.annotationRemoved,
      message: annotationId,
    );
  }

  factory LiveVisionEvent.imageEnhanced(ImageEnhancement enhancement) {
    return LiveVisionEvent(
      type: LiveVisionEventType.imageEnhanced,
      message: enhancement.name,
    );
  }

  factory LiveVisionEvent.error(String error) {
    return LiveVisionEvent(
      type: LiveVisionEventType.error,
      message: error,
    );
  }
}

enum LiveVisionEventType {
  cameraInitialized,
  cameraStopped,
  cameraSwitched,
  sessionStarted,
  sessionStopped,
  imageCaptured,
  analysisStarted,
  analysisCompleted,
  analysisFailed,
  recordingStarted,
  recordingStopped,
  timeLapseStarted,
  timeLapseProcessing,
  timeLapseCompleted,
  annotationAdded,
  annotationRemoved,
  imageEnhanced,
  flashChanged,
  zoomChanged,
  focusChanged,
  modeChanged,
  error,
}

enum LiveVisionMode {
  standard,
  microscope,
  wide,
}

enum ImageEnhancement {
  sharpen,
  brightness,
  contrast,
  saturation,
}

class MeasurementResult {
  final Point<double> start;
  final Point<double> end;
  final double pixelDistance;
  final double realDistance;
  final String unit;

  MeasurementResult({
    required this.start,
    required this.end,
    required this.pixelDistance,
    required this.realDistance,
    required this.unit,
  });
}

// Helper function to encode image
List<int> encodeJpg(img.Image image) {
  // TODO: Implement JPEG encoding
  return [];
}