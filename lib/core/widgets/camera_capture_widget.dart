import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CameraCaptureWidget extends StatefulWidget {
  final Function(File) onImageCaptured;
  final bool isAnalyzing;

  const CameraCaptureWidget({
    super.key,
    required this.onImageCaptured,
    this.isAnalyzing = false,
  });

  @override
  State<CameraCaptureWidget> createState() => _CameraCaptureWidgetState();
}

class _CameraCaptureWidgetState extends State<CameraCaptureWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  File? _capturedImage;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Camera Preview Area
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildCameraPreview(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Camera Controls
          AnimatedBuilder(
            animation: _slideController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - _slideController.value)),
                child: Opacity(
                  opacity: _slideController.value,
                  child: _buildCameraControls(colorScheme),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Tips and Guidelines
          _buildCaptureGuidelines(colorScheme),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_capturedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _capturedImage!,
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  onPressed: _retakePhoto,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _confirmPhoto,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Camera placeholder with guides
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Camera Preview',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Focus brackets overlay
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.green.withOpacity(0.5 + 0.5 * _pulseController.value),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 2,
                      color: Colors.green.withOpacity(0.5 + 0.5 * _pulseController.value),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Focus Area',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 2,
                      color: Colors.green.withOpacity(0.5 + 0.5 * _pulseController.value),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Corner brackets
        Positioned(
          top: 40,
          left: 40,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.green.withOpacity(0.7), width: 2),
                left: BorderSide(color: Colors.green.withOpacity(0.7), width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          top: 40,
          right: 40,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.green.withOpacity(0.7), width: 2),
                right: BorderSide(color: Colors.green.withOpacity(0.7), width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 40,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.green.withOpacity(0.7), width: 2),
                left: BorderSide(color: Colors.green.withOpacity(0.7), width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          right: 40,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.green.withOpacity(0.7), width: 2),
                right: BorderSide(color: Colors.green.withOpacity(0.7), width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraControls(ColorScheme colorScheme) {
    if (_capturedImage != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _retakePhoto,
            icon: const Icon(Icons.refresh),
            label: const Text('Retake'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          ElevatedButton.icon(
            onPressed: widget.isAnalyzing ? null : _confirmPhoto,
            icon: widget.isAnalyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(widget.isAnalyzing ? 'Analyzing...' : 'Analyze'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Gallery button
        IconButton(
          onPressed: _pickFromGallery,
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        // Capture button
        GestureDetector(
          onTap: _capturePhoto,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5 + 0.5 * _pulseController.value),
                    width: 4,
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              );
            },
          ),
        ),
        // Flash toggle button
        IconButton(
          onPressed: _toggleFlash,
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? Colors.yellow : Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureGuidelines(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Capture Tips',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('🌿 Focus on leaves showing symptoms'),
          _buildTipItem('☀️ Ensure good lighting, avoid shadows'),
          _buildTipItem('📐 Keep camera steady and parallel to plant'),
          _buildTipItem('🎯 Capture both top and underside of leaves'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to capture photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
    });
  }

  void _confirmPhoto() {
    if (_capturedImage != null && !widget.isAnalyzing) {
      widget.onImageCaptured(_capturedImage!);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}