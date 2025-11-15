import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import '../enhanced_ai_service.dart';

/// Image processing service for plant analysis
class ImageProcessingService {
  final Logger _logger = Logger();

  /// Preprocess image for AI analysis
  Future<Uint8List> preprocessImage(
    Uint8List imageData, {
    ImageProcessingOptions options = const ImageProcessingOptions(),
  }) async {
    try {
      _logger.d('Starting image preprocessing');

      // Decode image
      var image = img.decodeImage(imageData);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final stopwatch = Stopwatch()..start();

      // Apply preprocessing steps
      if (options.autoCrop) {
        image = await _autoCrop(image);
      }

      if (options.detectLeaves) {
        image = await _enhanceLeafRegions(image);
      }

      if (options.enhanceContrast) {
        image = _enhanceContrast(image);
      }

      // Resize image
      image = _resizeImage(image, options.maxWidth, options.maxHeight);

      // Apply quality adjustments
      image = _adjustQuality(image, options.quality);

      stopwatch.stop();

      _logger.d('Image preprocessing completed in ${stopwatch.elapsedMilliseconds}ms');

      // Encode processed image
      return img.encodeJpg(image, quality: (options.quality * 100).round());
    } catch (e) {
      _logger.e('Image preprocessing failed: $e');
      rethrow;
    }
  }

  /// Generate image hash for caching
  String generateImageHash(Uint8List imageData) {
    try {
      // Generate SHA-256 hash of image data
      final digest = sha256.convert(imageData);
      return digest.toString().substring(0, 16); // Use first 16 characters
    } catch (e) {
      _logger.e('Failed to generate image hash: $e');
      // Fallback to simple hash
      return imageData.length.toString() + DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Assess image quality
  ImageQualityAssessment assessImageQuality(Uint8List imageData) {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        return ImageQualityAssessment(
          score: 0.0,
          resolution: Resolution.low,
          focus: Focus.poor,
          lighting: Lighting.poor,
          issues: ['Failed to decode image'],
        );
      }

      final score = _calculateQualityScore(image);
      final resolution = _assessResolution(image);
      final focus = _assessFocus(image);
      final lighting = _assessLighting(image);
      final issues = _identifyQualityIssues(image, score, resolution, focus, lighting);

      return ImageQualityAssessment(
        score: score,
        resolution: resolution,
        focus: focus,
        lighting: lighting,
        issues: issues,
        recommendations: _getQualityRecommendations(issues),
      );
    } catch (e) {
      _logger.e('Image quality assessment failed: $e');
      return ImageQualityAssessment(
        score: 0.0,
        resolution: Resolution.unknown,
        focus: Focus.unknown,
        lighting: Lighting.unknown,
        issues: ['Assessment failed: ${e.toString()}'],
      );
    }
  }

  /// Auto-crop image to focus on plant
  Future<img.Image> _autoCrop(img.Image image) async {
    try {
      // Detect plant boundaries (simplified)
      final bounds = _detectPlantBounds(image);

      if (bounds == null) {
        return image; // Return original if no plant detected
      }

      // Crop to detected bounds with padding
      final padding = 20;
      final x = (bounds.x - padding).clamp(0, image.width - 1);
      final y = (bounds.y - padding).clamp(0, image.height - 1);
      final width = (bounds.width + padding * 2).clamp(1, image.width - x);
      final height = (bounds.height + padding * 2).clamp(1, image.height - y);

      return img.copyCrop(image, x: x, y: y, width: width, height: height);
    } catch (e) {
      _logger.w('Auto-crop failed: $e');
      return image; // Return original on failure
    }
  }

  /// Detect plant boundaries
  Rectangle? _detectPlantBounds(img.Image image) {
    // Simplified plant detection based on green color
    int minX = image.width;
    int minY = image.height;
    int maxX = 0;
    int maxY = 0;
    bool foundGreen = false;

    // Sample pixels to find green regions
    final step = max(1, (image.width * image.height) ~/ 10000); // Sample ~10k pixels

    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);

        // Check if pixel is green-ish
        if (pixel.g > pixel.r && pixel.g > pixel.b && pixel.g > 50) {
          foundGreen = true;
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    if (!foundGreen) {
      return null; // No green detected
    }

    // Expand bounds slightly
    final expansion = 50;
    minX = max(0, minX - expansion);
    minY = max(0, minY - expansion);
    maxX = min(image.width, maxX + expansion);
    maxY = min(image.height, maxY + expansion);

    return Rectangle(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  /// Enhance leaf regions for better analysis
  Future<img.Image> _enhanceLeafRegions(img.Image image) async {
    try {
      // Apply green channel enhancement
      final enhanced = img.Image(width: image.width, height: image.height);

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);

          // Enhance green channel for leaf regions
          if (pixel.g > pixel.r && pixel.g > pixel.b) {
            // This is likely a leaf pixel
            final enhancedGreen = min(255, pixel.g * 1.1);
            enhanced.setPixel(x, y, img.Pixel(
              r: (pixel.r * 0.9).round(),
              g: enhancedGreen.round(),
              b: (pixel.b * 0.9).round(),
            ));
          } else {
            enhanced.setPixel(x, y, pixel);
          }
        }
      }

      return enhanced;
    } catch (e) {
      _logger.w('Leaf enhancement failed: $e');
      return image;
    }
  }

  /// Enhance image contrast
  img.Image _enhanceContrast(img.Image image) {
    try {
      // Calculate histogram
      final histogram = _calculateHistogram(image);

      // Find min and max values (excluding outliers)
      final minVal = _findHistogramPercentile(histogram, 0.02);
      final maxVal = _findHistogramPercentile(histogram, 0.98);

      // Apply contrast stretching
      final enhanced = img.Image(width: image.width, height: image.height);
      final range = maxVal - minVal;

      if (range > 0) {
        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final pixel = image.getPixel(x, y);

            final newR = ((pixel.r - minVal) / range * 255).clamp(0.0, 255.0).round();
            final newG = ((pixel.g - minVal) / range * 255).clamp(0.0, 255.0).round();
            final newB = ((pixel.b - minVal) / range * 255).clamp(0.0, 255.0).round();

            enhanced.setPixel(x, y, img.Pixel(r: newR, g: newG, b: newB));
          }
        }
      } else {
        return image; // No contrast enhancement needed
      }

      return enhanced;
    } catch (e) {
      _logger.w('Contrast enhancement failed: $e');
      return image;
    }
  }

  /// Resize image maintaining aspect ratio
  img.Image _resizeImage(img.Image image, int maxWidth, int maxHeight) {
    if (image.width <= maxWidth && image.height <= maxHeight) {
      return image; // No resize needed
    }

    // Calculate new dimensions maintaining aspect ratio
    final widthRatio = maxWidth / image.width;
    final heightRatio = maxHeight / image.height;
    final ratio = min(widthRatio, heightRatio);

    final newWidth = (image.width * ratio).round();
    final newHeight = (image.height * ratio).round();

    return img.copyResize(image, width: newWidth, height: newHeight, interpolation: img.Interpolation.linear);
  }

  /// Adjust image quality
  img.Image _adjustQuality(img.Image image, double quality) {
    if (quality >= 0.95) {
      return image; // No adjustment needed for high quality
    }

    // Apply slight blur for quality reduction (simulates compression)
    final adjusted = img.Image(width: image.width, height: image.height);
    final blurRadius = ((1.0 - quality) * 2).round();

    if (blurRadius > 0) {
      // Simple box blur
      for (int y = blurRadius; y < image.height - blurRadius; y++) {
        for (int x = blurRadius; x < image.width - blurRadius; x++) {
          int rSum = 0, gSum = 0, bSum = 0, count = 0;

          for (int dy = -blurRadius; dy <= blurRadius; dy++) {
            for (int dx = -blurRadius; dx <= blurRadius; dx++) {
              final pixel = image.getPixel(x + dx, y + dy);
              rSum += pixel.r;
              gSum += pixel.g;
              bSum += pixel.b;
              count++;
            }
          }

          adjusted.setPixel(x, y, img.Pixel(
            r: (rSum / count).round(),
            g: (gSum / count).round(),
            b: (bSum / count).round(),
          ));
        }
      }
    }

    return adjusted;
  }

  /// Calculate image quality score
  double _calculateQualityScore(img.Image image) {
    double score = 1.0;

    // Resolution score
    final resolutionScore = _calculateResolutionScore(image);
    score *= resolutionScore;

    // Focus score (based on edge detection)
    final focusScore = _calculateFocusScore(image);
    score *= focusScore;

    // Lighting score
    final lightingScore = _calculateLightingScore(image);
    score *= lightingScore;

    // Noise score
    final noiseScore = _calculateNoiseScore(image);
    score *= noiseScore;

    return score.clamp(0.0, 1.0);
  }

  /// Assess image resolution
  Resolution _assessResolution(img.Image image) {
    final totalPixels = image.width * image.height;

    if (totalPixels >= 1920 * 1080) {
      return Resolution.high;
    } else if (totalPixels >= 1280 * 720) {
      return Resolution.medium;
    } else if (totalPixels >= 640 * 480) {
      return Resolution.low;
    } else {
      return Resolution.very_low;
    }
  }

  /// Calculate resolution score
  double _calculateResolutionScore(img.Image image) {
    final totalPixels = image.width * image.height;
    final targetPixels = 1280 * 720; // 720p as baseline

    return min(1.0, totalPixels / targetPixels);
  }

  /// Assess image focus
  Focus _assessFocus(img.Image image) {
    final focusScore = _calculateFocusScore(image);

    if (focusScore >= 0.8) {
      return Focus.excellent;
    } else if (focusScore >= 0.6) {
      return Focus.good;
    } else if (focusScore >= 0.4) {
      return Focus.fair;
    } else {
      return Focus.poor;
    }
  }

  /// Calculate focus score using edge detection
  double _calculateFocusScore(img.Image image) {
    int edgeCount = 0;
    int totalSamples = 0;

    // Sample edges across the image
    final step = max(1, (image.width * image.height) ~/ 5000);

    for (int y = 1; y < image.height - 1; y += step) {
      for (int x = 1; x < image.width - 1; x += step) {
        totalSamples++;

        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);

        // Simple edge detection
        final hDiff = (center.r - right.r).abs() + (center.g - right.g).abs() + (center.b - right.b).abs();
        final vDiff = (center.r - bottom.r).abs() + (center.g - bottom.g).abs() + (center.b - bottom.b).abs();

        if (hDiff > 30 || vDiff > 30) {
          edgeCount++;
        }
      }
    }

    return totalSamples > 0 ? edgeCount / totalSamples : 0.0;
  }

  /// Assess lighting
  Lighting _assessLighting(img.Image image) {
    final lightingScore = _calculateLightingScore(image);

    if (lightingScore >= 0.8) {
      return Lighting.excellent;
    } else if (lightingScore >= 0.6) {
      return Lighting.good;
    } else if (lightingScore >= 0.4) {
      return Lighting.fair;
    } else {
      return Lighting.poor;
    }
  }

  /// Calculate lighting score
  double _calculateLightingScore(img.Image image) {
    int totalBrightness = 0;
    int pixelCount = 0;

    // Sample brightness across the image
    final step = max(1, (image.width * image.height) ~/ 10000);

    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        totalBrightness += brightness;
        pixelCount++;
      }
    }

    if (pixelCount == 0) return 0.0;

    final avgBrightness = totalBrightness / pixelCount;

    // Ideal brightness range (not too dark, not too bright)
    if (avgBrightness >= 80 && avgBrightness <= 200) {
      return 1.0;
    } else if (avgBrightness >= 60 && avgBrightness <= 220) {
      return 0.8;
    } else if (avgBrightness >= 40 && avgBrightness <= 240) {
      return 0.6;
    } else {
      return 0.3;
    }
  }

  /// Calculate noise score
  double _calculateNoiseScore(img.Image image) {
    double totalVariance = 0;
    int sampleCount = 0;

    // Sample local variance
    final step = max(1, (image.width * image.height) ~/ 2000);

    for (int y = 1; y < image.height - 1; y += step) {
      for (int x = 1; x < image.width - 1; x += step) {
        final center = image.getPixel(x, y);
        final neighbors = [
          image.getPixel(x - 1, y), image.getPixel(x + 1, y),
          image.getPixel(x, y - 1), image.getPixel(x, y + 1)
        ];

        final avgR = neighbors.map((p) => p.r).reduce((a, b) => a + b) / neighbors.length;
        final avgG = neighbors.map((p) => p.g).reduce((a, b) => a + b) / neighbors.length;
        final avgB = neighbors.map((p) => p.b).reduce((a, b) => a + b) / neighbors.length;

        final variance = ((center.r - avgR).abs() + (center.g - avgG).abs() + (center.b - avgB).abs()) / 3;
        totalVariance += variance;
        sampleCount++;
      }
    }

    final avgVariance = sampleCount > 0 ? totalVariance / sampleCount : 0;

    // Lower variance = less noise = higher score
    return max(0.0, 1.0 - (avgVariance / 50.0));
  }

  /// Identify quality issues
  List<String> _identifyQualityIssues(img.Image image, double score, Resolution resolution, Focus focus, Lighting lighting) {
    final issues = <String>[];

    if (score < 0.3) {
      issues.add('Overall image quality is poor');
    }

    if (resolution == Resolution.very_low) {
      issues.add('Resolution is too low for accurate analysis');
    } else if (resolution == Resolution.low) {
      issues.add('Resolution could be higher for better results');
    }

    if (focus == Focus.poor) {
      issues.add('Image is out of focus');
    } else if (focus == Focus.fair) {
      issues.add('Image focus could be improved');
    }

    if (lighting == Lighting.poor) {
      issues.add('Poor lighting conditions');
    } else if (lighting == Lighting.fair) {
      issues.add('Lighting could be improved');
    }

    // Check for common issues
    if (_isTooDark(image)) {
      issues.add('Image is too dark');
    } else if (_isTooBright(image)) {
      issues.add('Image is overexposed');
    }

    if (_hasColorCast(image)) {
      issues.add('Image has noticeable color cast');
    }

    if (_isBlurry(image)) {
      issues.add('Image appears blurry');
    }

    return issues;
  }

  /// Get quality recommendations
  List<String> _getQualityRecommendations(List<String> issues) {
    final recommendations = <String>[];

    for (final issue in issues) {
      switch (issue.toLowerCase()) {
        case 'resolution is too low for accurate analysis':
          recommendations.add('Use a higher resolution camera (minimum 1280x720)');
          break;
        case 'image is out of focus':
          recommendations.add('Ensure camera is focused on the plant');
          recommendations.add('Use macro mode for close-up shots');
          break;
        case 'poor lighting conditions':
          recommendations.add('Ensure bright, even lighting');
          recommendations.add('Avoid direct sunlight which can cause harsh shadows');
          recommendations.add('Consider using a ring light or diffused lighting');
          break;
        case 'image is too dark':
          recommendations.add('Increase lighting or use longer exposure');
          recommendations.add('Ensure light source is positioned correctly');
          break;
        case 'image is overexposed':
          recommendations.add('Reduce lighting intensity or use faster shutter speed');
          recommendations.add('Avoid shooting directly into bright light sources');
          break;
        case 'image appears blurry':
          recommendations.add('Hold camera steady or use a tripod');
          recommendations.add('Ensure proper focus before taking the photo');
          break;
      }
    }

    // General recommendations
    if (recommendations.isEmpty) {
      recommendations.add('Image quality is good for analysis');
    }

    return recommendations;
  }

  // Helper methods for quality assessment
  bool _isTooDark(img.Image image) {
    return _calculateLightingScore(image) < 0.3;
  }

  bool _isTooBright(img.Image image) {
    return _calculateLightingScore(image) > 0.95;
  }

  bool _hasColorCast(img.Image image) {
    // Simple color cast detection
    final histogram = _calculateHistogram(image);

    final redMean = _calculateChannelMean(histogram['red'] as List<int>);
    final greenMean = _calculateChannelMean(histogram['green'] as List<int>);
    final blueMean = _calculateChannelMean(histogram['blue'] as List<int>);

    final maxDiff = [redMean, greenMean, blueMean].reduce(max) -
                     [redMean, greenMean, blueMean].reduce(min);

    return maxDiff > 30; // Threshold for noticeable color cast
  }

  bool _isBlurry(img.Image image) {
    return _calculateFocusScore(image) < 0.3;
  }

  Map<String, List<int>> _calculateHistogram(img.Image image) {
    final redHistogram = List.filled(256, 0);
    final greenHistogram = List.filled(256, 0);
    final blueHistogram = List.filled(256, 0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        redHistogram[pixel.r]++;
        greenHistogram[pixel.g]++;
        blueHistogram[pixel.b]++;
      }
    }

    return {
      'red': redHistogram,
      'green': greenHistogram,
      'blue': blueHistogram,
    };
  }

  double _calculateChannelMean(List<int> histogram) {
    int sum = 0;
    int count = 0;

    for (int i = 0; i < histogram.length; i++) {
      sum += i * histogram[i];
      count += histogram[i];
    }

    return count > 0 ? sum / count : 0.0;
  }

  double _findHistogramPercentile(Map<String, List<int>> histogram, double percentile) {
    // Combine all channels for percentile calculation
    final allValues = <int>[];

    for (final channel in histogram.values) {
      for (int i = 0; i < channel.length; i++) {
        if (channel[i] > 0) {
          allValues.addAll(List.filled(channel[i], i));
        }
      }
    }

    if (allValues.isEmpty) return 0.0;

    allValues.sort();
    final index = (allValues.length * percentile).floor().clamp(0, allValues.length - 1);

    return allValues[index].toDouble();
  }
}

// Supporting classes

class Rectangle {
  final int x;
  final int y;
  final int width;
  final int height;

  Rectangle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class ImageQualityAssessment {
  final double score;
  final Resolution resolution;
  final Focus focus;
  final Lighting lighting;
  final List<String> issues;
  final List<String> recommendations;

  ImageQualityAssessment({
    required this.score,
    required this.resolution,
    required this.focus,
    required this.lighting,
    required this.issues,
    this.recommendations = const [],
  });
}

enum Resolution {
  very_low,
  low,
  medium,
  high,
  unknown,
}

enum Focus {
  poor,
  fair,
  good,
  excellent,
  unknown,
}

enum Lighting {
  poor,
  fair,
  good,
  excellent,
  unknown,
}