import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class AsciiConverter {
  // Extended ASCII characters from darkest to lightest for better detail
  // Using a more comprehensive set with better gradation
  // Alternative character sets for different styles
  static const String _detailedChars = 
      '@\$B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,"^\'`. ';
  
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

    // Use detailed character set for better quality
    final asciiChars = useDetailed ? _detailedChars : _smoothChars;

    // Calculate aspect ratio to maintain proportions
    // Character aspect ratio is approximately 0.5 (characters are taller than wide)
    final aspectRatio = image.height / image.width;
    final height = (width * aspectRatio * 0.5).round();

    // Resize image with better interpolation for smoother results
    final resized = img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );

    // Convert to grayscale first for better processing
    final grayscale = img.grayscale(resized);

    // Build ASCII string with improved brightness mapping
    final StringBuffer buffer = StringBuffer();
    
    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y);
        
        // Get RGBA values
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final a = pixel.a.toDouble();
        
        // Handle transparency: if pixel is transparent or very transparent, use space (lightest)
        // Transparent pixels should appear as white/light background
        if (a < 10) {
          buffer.write(' ');
          continue;
        }
        
        // Calculate brightness using luminance formula
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        
        // For transparent pixels, blend with white background (brightness = 1.0)
        // This ensures transparent areas appear light, not dark
        final alphaFactor = a / 255.0;
        final alphaBlended = brightness * alphaFactor + (1.0 - alphaFactor);
        
        // Apply gamma correction for better visual representation
        final gammaCorrected = _gammaCorrection(alphaBlended, 2.2);
        
        // Invert if needed
        final normalizedBrightness = invert ? 1.0 - gammaCorrected : gammaCorrected;
        
        // Clamp brightness to [0, 1]
        final clampedBrightness = normalizedBrightness.clamp(0.0, 1.0);
        
        // Map brightness to ASCII character with better distribution
        final charIndex = (clampedBrightness * (asciiChars.length - 1)).round();
        buffer.write(asciiChars[charIndex]);
      }
      buffer.write('\n');
    }
    
    return buffer.toString();
  }

  /// Applies gamma correction to brightness for better visual representation
  static double _gammaCorrection(double value, double gamma) {
    return value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : 
        (value < 0.04045 ? value / 12.92 : 
         math.pow((value + 0.055) / 1.055, gamma).toDouble()));
  }
}

