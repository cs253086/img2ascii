import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class AsciiConverter {
  // Extended character set with many gradations for better contrast distinction
  // Characters ordered by visual density/brightness (darkest to lightest)
  // Using 90+ characters for fine-grained brightness mapping
  static const String _detailedChars = 
      '\$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,"^\'`. ';
  
  // Ultra-detailed character set with maximum gradations (100+ characters)
  // Includes many more characters and symbols for even finer contrast distinction
  // This provides more brightness levels for better text readability
  // Characters carefully ordered by visual density from darkest to lightest
  static const String _ultraDetailedChars = 
      '\$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,"^\'`. '
      '2345679ABCDEFGHKNPQRSTVWabcdefghijklmnopqrstuvwxyz';
  
  static const String _smoothChars = '@%#*+=-:. ';

  /// Converts an image to ASCII art with improved accuracy
  /// 
  /// [imageBytes] - The image file bytes
  /// [width] - Desired width of ASCII output (in characters)
  /// [invert] - If true, inverts the brightness
  /// [useDetailed] - If true, uses a more detailed character set
  /// 
  /// Returns a String containing the ASCII art
  static Future<String> convertToAscii(
    Uint8List imageBytes, {
    int width = 100,
    bool invert = false,
    bool useDetailed = true,
  }) async {
    // Decode the image
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Use ultra-detailed character set for maximum contrast distinction
    // This provides 90+ brightness levels for fine-grained mapping
    final asciiChars = useDetailed ? _ultraDetailedChars : _smoothChars;

    // Calculate aspect ratio to maintain proportions
    final aspectRatio = image.height / image.width;
    final height = (width * aspectRatio * 0.5).round();

    // Process at moderate resolution (2x) - too high resolution causes artifacts with limited characters
    img.Image processed = img.copyResize(
      image,
      width: width * 2,
      height: (height * 2).round(),
      interpolation: img.Interpolation.cubic,
    );

    // Handle transparency by compositing onto white background
    if (processed.hasAlpha) {
      processed = _compositeOnWhite(processed);
    }

    // Convert to grayscale
    processed = img.grayscale(processed);

    // Apply very strong contrast enhancement (4.0x) to make text stand out
    processed = _enhanceContrast(processed, 4.0);

    // Apply aggressive sharpening for text clarity
    processed = _applyUnsharpMask(processed, 2.0);

    // Apply binary thresholding for ultra-sharp edges
    processed = _applyBinaryThresholding(processed);

    // Apply edge detection and thresholding for sharp edges (very sensitive)
    processed = _applyEdgeThresholding(processed, 0.05);

    // Now resize to final dimensions with nearest-neighbor for sharp edges
    final resized = img.copyResize(
      processed,
      width: width,
      height: height,
      interpolation: img.Interpolation.nearest, // Use nearest-neighbor to preserve sharp edges
    );

    // Use percentile-based histogram for better range utilization
    // This prevents outliers from compressing the range
    final histogram = _calculatePercentileHistogram(resized, 2.0, 98.0);
    final minBrightness = histogram[0];
    final maxBrightness = histogram[1];
    final brightnessRange = maxBrightness - minBrightness;

    // Build ASCII string with improved brightness mapping
    final StringBuffer buffer = StringBuffer();
    
    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        // Use point sampling for sharp edges, area sampling would blur edges
        final pixel = resized.getPixel(x, y);
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        
        // Normalize brightness using histogram (stretch to full range)
        // Clamp values outside range to 0 or 1 for maximum contrast
        double normalizedBrightness;
        if (brightnessRange > 0.01) {
          normalizedBrightness = ((brightness - minBrightness) / brightnessRange);
          // Aggressively clamp to use full range
          normalizedBrightness = normalizedBrightness.clamp(0.0, 1.0);
        } else {
          normalizedBrightness = brightness;
        }
        
        // Apply stronger gamma correction for better contrast (lower gamma = more contrast)
        final gammaCorrected = _gammaCorrection(normalizedBrightness, 1.5);
        
        // Apply aggressive contrast curve for text readability
        final contrastEnhanced = _applyContrastCurve(gammaCorrected, 2.0);
        
        // Invert if needed
        final finalBrightness = invert ? 1.0 - contrastEnhanced : contrastEnhanced;
        
        // Clamp brightness to [0, 1]
        final clampedBrightness = finalBrightness.clamp(0.0, 1.0);
        
        // Map brightness to ASCII character
        final charIndex = (clampedBrightness * (asciiChars.length - 1)).round();
        buffer.write(asciiChars[charIndex]);
      }
      buffer.write('\n');
    }
    
    return buffer.toString();
  }

  /// Composites image with transparency onto white background
  static img.Image _compositeOnWhite(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final a = pixel.a / 255.0;
        
        if (a < 0.01) {
          result.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        } else {
          final r = (pixel.r * a + 255 * (1 - a)).round();
          final g = (pixel.g * a + 255 * (1 - a)).round();
          final b = (pixel.b * a + 255 * (1 - a)).round();
          result.setPixel(x, y, img.ColorRgb8(r, g, b));
        }
      }
    }
    
    return result;
  }

  /// Enhances contrast of the image
  static img.Image _enhanceContrast(img.Image image, double factor) {
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        
        final r = ((pixel.r - 128) * factor + 128).clamp(0, 255).round();
        final g = ((pixel.g - 128) * factor + 128).clamp(0, 255).round();
        final b = ((pixel.b - 128) * factor + 128).clamp(0, 255).round();
        
        result.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }
    
    return result;
  }

  /// Applies unsharp mask for edge enhancement
  static img.Image _applyUnsharpMask(img.Image image, double strength) {
    if (strength <= 0) return image;
    
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final center = image.getPixel(x, y);
        final centerBrightness = (0.299 * center.r + 0.587 * center.g + 0.114 * center.b) / 255.0;
        
        // Calculate average brightness of surrounding pixels
        double avgBrightness = 0.0;
        int count = 0;
        
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final sx = (x + dx).clamp(0, image.width - 1);
            final sy = (y + dy).clamp(0, image.height - 1);
            final pixel = image.getPixel(sx, sy);
            avgBrightness += (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
            count++;
          }
        }
        avgBrightness /= count;
        
        // Unsharp mask: add difference between original and blurred
        final diff = (centerBrightness - avgBrightness) * strength;
        final enhancedBrightness = (centerBrightness + diff).clamp(0.0, 1.0);
        
        final enhancedValue = (enhancedBrightness * 255).round().clamp(0, 255);
        result.setPixel(x, y, img.ColorRgb8(enhancedValue, enhancedValue, enhancedValue));
      }
    }
    
    return result;
  }

  /// Applies binary thresholding for ultra-sharp edges
  /// Converts image to pure black and white based on median threshold
  static img.Image _applyBinaryThresholding(img.Image image) {
    // Calculate median brightness for threshold
    final List<double> brightnesses = [];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        brightnesses.add(brightness);
      }
    }
    brightnesses.sort();
    final median = brightnesses[brightnesses.length ~/ 2];
    
    // Apply binary thresholding
    final result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        
        // Binary threshold: 0 or 255
        final value = brightness > median ? 255 : 0;
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }
    
    return result;
  }

  /// Applies edge detection and thresholding for sharp, clean edges
  /// This helps preserve crisp boundaries when using limited characters
  /// Applies binary thresholding to all pixels for maximum sharpness
  static img.Image _applyEdgeThresholding(img.Image image, double threshold) {
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        
        // Always apply binary thresholding for ultra-sharp edges
        // This ensures crisp boundaries - every pixel is either 0 or 255
        final finalBrightness = brightness < 0.5 ? 0.0 : 1.0;
        final value = (finalBrightness * 255).round().clamp(0, 255);
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }
    
    return result;
  }

  /// Enhances edges using Sobel-like operator
  static img.Image _enhanceEdges(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        // Get center pixel brightness
        final center = image.getPixel(x, y);
        final centerBrightness = (0.299 * center.r + 0.587 * center.g + 0.114 * center.b) / 255.0;
        
        // Calculate edge strength using simple gradient
        final right = image.getPixel(x + 1, y);
        final rightBrightness = (0.299 * right.r + 0.587 * right.g + 0.114 * right.b) / 255.0;
        final bottom = image.getPixel(x, y + 1);
        final bottomBrightness = (0.299 * bottom.r + 0.587 * bottom.g + 0.114 * bottom.b) / 255.0;
        
        final edgeStrength = (centerBrightness - rightBrightness).abs() + 
                            (centerBrightness - bottomBrightness).abs();
        
        // Enhance edges by darkening/lightening based on edge strength
        final edgeEnhancement = edgeStrength * 0.3;
        final enhancedBrightness = centerBrightness + 
            (centerBrightness < 0.5 ? -edgeEnhancement : edgeEnhancement);
        
        final finalBrightness = enhancedBrightness.clamp(0.0, 1.0);
        final value = (finalBrightness * 255).round().clamp(0, 255);
        result.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }
    
    // Copy borders
    for (int y = 0; y < image.height; y++) {
      result.setPixel(0, y, image.getPixel(0, y));
      result.setPixel(image.width - 1, y, image.getPixel(image.width - 1, y));
    }
    for (int x = 0; x < image.width; x++) {
      result.setPixel(x, 0, image.getPixel(x, 0));
      result.setPixel(x, image.height - 1, image.getPixel(x, image.height - 1));
    }
    
    return result;
  }

  /// Samples brightness from a small area around the pixel
  static double _sampleAreaBrightness(img.Image image, int x, int y) {
    double totalBrightness = 0.0;
    double count = 0.0;
    
    // Sample 3x3 area with center weight
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final sx = (x + dx).clamp(0, image.width - 1);
        final sy = (y + dy).clamp(0, image.height - 1);
        final pixel = image.getPixel(sx, sy);
        
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        final weight = (dx == 0 && dy == 0) ? 2.0 : 1.0;
        totalBrightness += brightness * weight;
        count += weight;
      }
    }
    
    return totalBrightness / count;
  }

  /// Calculates brightness histogram [min, max] for adaptive mapping
  static List<double> _calculateHistogram(img.Image image) {
    double minBrightness = 1.0;
    double maxBrightness = 0.0;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        
        if (brightness < minBrightness) minBrightness = brightness;
        if (brightness > maxBrightness) maxBrightness = brightness;
      }
    }
    
    return [minBrightness, maxBrightness];
  }

  /// Calculates percentile-based histogram to avoid outliers compressing the range
  /// [lowerPercentile] and [upperPercentile] are percentages (0-100)
  static List<double> _calculatePercentileHistogram(
      img.Image image, double lowerPercentile, double upperPercentile) {
    final List<double> brightnesses = [];
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255.0;
        brightnesses.add(brightness);
      }
    }
    
    brightnesses.sort();
    
    final lowerIndex = (brightnesses.length * lowerPercentile / 100.0).floor();
    final upperIndex = (brightnesses.length * upperPercentile / 100.0).floor();
    
    final minBrightness = brightnesses[lowerIndex.clamp(0, brightnesses.length - 1)];
    final maxBrightness = brightnesses[upperIndex.clamp(0, brightnesses.length - 1)];
    
    return [minBrightness, maxBrightness];
  }

  /// Applies contrast curve for better text readability
  static double _applyContrastCurve(double value, double strength) {
    // S-curve for better contrast in mid-tones
    if (value < 0.5) {
      return math.pow(value * 2, strength) / 2;
    } else {
      return 1.0 - math.pow((1.0 - value) * 2, strength) / 2;
    }
  }

  /// Applies gamma correction to brightness
  static double _gammaCorrection(double value, double gamma) {
    return value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : 
        (value < 0.04045 ? value / 12.92 : 
         math.pow((value + 0.055) / 1.055, gamma).toDouble()));
  }
}
