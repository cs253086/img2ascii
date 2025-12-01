# Image to ASCII

A Flutter mobile application that converts images to ASCII art. Select an image from your gallery or take a photo, and the app will transform it into beautiful ASCII art.

## Features

- 📸 Select images from gallery or take photos with camera
- 🎨 Convert images to ASCII art in real-time
- ⚙️ Adjustable width (40-150 characters)
- 🔄 Invert colors option for better contrast
- 📱 Works on both Android and iOS
- 📋 Copy ASCII art text (selectable text)

## Getting Started

### Prerequisites

- Flutter SDK (3.10.1 or higher)
- Android Studio / Xcode (for mobile development)
- A physical device or emulator/simulator

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd img2ascii
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Usage

1. **Select an Image**: Tap the "Select Image" button at the bottom of the screen
2. **Choose Source**: Select either "Choose from Gallery" or "Take a Photo"
3. **Adjust Settings**:
   - Use the width slider to control the ASCII output width (40-150 characters)
   - Toggle "Invert colors" to reverse the brightness mapping
4. **View Result**: The ASCII art will be displayed in a scrollable, selectable text view

## Permissions

The app requires the following permissions:

### Android
- `CAMERA` - To take photos
- `READ_EXTERNAL_STORAGE` - To read images from gallery (Android < 13)
- `READ_MEDIA_IMAGES` - To read images from gallery (Android 13+)

### iOS
- `NSPhotoLibraryUsageDescription` - To access photo library
- `NSCameraUsageDescription` - To access camera

## Technical Details

- **Framework**: Flutter
- **Dependencies**:
  - `image_picker`: For selecting images from gallery or camera
  - `image`: For image processing and pixel manipulation

The ASCII conversion algorithm:
- Resizes the image to the specified width while maintaining aspect ratio
- Converts each pixel to grayscale using luminance formula (0.299*R + 0.587*G + 0.114*B)
- Maps brightness values to ASCII characters: `@%#*+=-:. `
- Supports color inversion for better visibility on different backgrounds

## Building for Release

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## License

This project is open source and available for personal use.
