# YOLOv8 + Gemini 2.5 Flash Setup Guide

## Architecture Overview

```
Camera Frame
    ↓
YOLO Model (Local TFLite) → Fast object detection
    ↓
Structured Text Result
    ↓
Gemini 2.5 Flash → AI reasoning & insights
    ↓
Display Results
```

## Step 1: Get Your YOLO Model

### Option A: Pre-trained from Roboflow Universe (Recommended)

1. Go to https://universe.roboflow.com
2. Search for "refrigerator detection"
3. Pick a model with good performance
4. Click "Download"
5. Select **TensorFlow Lite** format
6. Download the `.tflite` file

### Option B: Train Your Own

```bash
# Install YOLOv8
pip install ultralytics

# Train on your dataset
yolo detect train data=coco128.yaml epochs=100 imgsz=640

# Export to TFLite
yolo export model=yolov8n.pt format=tflite imgsz=640
```

## Step 2: Add Model to Flutter App

1. Create folder: `assets/models/`
2. Copy your model file to: `assets/models/yolov8_fridge_detection.tflite`
3. Update `pubspec.yaml`:

```yaml
assets:
  - assets/models/yolov8_fridge_detection.tflite
```

4. Run: `flutter pub get`

## Step 3: Setup Gemini API

1. Get API key from https://ai.google.dev
2. Add to your app initialization (in `main.dart`):

```dart
void main() {
  // Initialize Gemini service
  GeminiAIService().initialize(
    apiKey: 'YOUR_GEMINI_API_KEY',
  );
  
  runApp(const FridgeApp());
}
```

**Security Note**: Use environment variables in production!

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();
  GeminiAIService().initialize(
    apiKey: dotenv.env['GEMINI_API_KEY']!,
  );
  runApp(const FridgeApp());
}
```

## Step 4: Integrate Camera Detection to Home Screen

Update `lib/screens/home_screen.dart` to add camera button:

```dart
// In your tab or FAB
FloatingActionButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CameraDetectionScreen(),
      ),
    );
  },
  child: const Icon(Icons.camera),
)
```

## Step 5: Android Permissions

Update `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

## Step 6: iOS Permissions

Update `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan your fridge</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access for fridge images</string>
```

## Data Flow Example

### User scans fridge:

1. **Camera captures image**
   ```
   CameraDetectionScreen → Take photo
   ```

2. **YOLO runs locally (Fast! No internet!)**
   ```
   YOLODetectionService.detectFromFile(imageFile)
   
   Returns:
   {
     "fridgeType": "French Door",
     "numDoors": 2,
     "itemsDetected": ["milk", "eggs", "juice", "butter"],
     "confidence": 0.87
   }
   ```

3. **Send ONLY structured text to Gemini**
   ```
   GeminiAIService.generateInsights(detection)
   
   Prompt sent (NO IMAGE):
   "User has French Door fridge with 2 doors.
    Items detected: milk, eggs, juice, butter.
    Provide grocery insights and recipes."
   ```

4. **Gemini analyzes and responds**
   ```
   GeminiInsights:
   - Appliance description
   - Grocery insights  
   - Recipe recommendations
   - Storage optimization tips
   ```

5. **Display results**
   ```
   DetectionResultsScreen shows all insights
   ```

## Cost & Performance

| Task | Tool | Cost | Speed | Privacy |
|------|------|------|-------|---------|
| Object Detection | YOLO TFLite | FREE (local) | ~100ms | ✅ Local |
| Items Recognition | YOLO | FREE (local) | ~100ms | ✅ Local |
| AI Reasoning | Gemini 2.5 Flash | $0.075/million tokens | ~500ms | ⚠️ Text only |
| Per scan | Combined | ~$0.0001 | ~600ms | Good |

## Benefits Over Roboflow-Only

| Feature | Roboflow Only | YOLOv8 + Gemini |
|---------|--------------|-----------------|
| Local inference | ❌ | ✅ |
| Offline capable | ❌ | ✅ |
| Per-request cost | Yes | Minimal |
| Real-time speed | 1-2s | 600ms |
| AI reasoning | Limited | Excellent |
| Scalability | Limited | Great |
| Privacy | Lower | Higher |

## Troubleshooting

### Model not loading
- Check: `assets/models/` folder exists
- Verify: Model file name matches `yolov8_fridge_detection.tflite`
- Run: `flutter pub get` && `flutter pub cache clean`

### Gemini errors
- Check: API key is valid
- Verify: Internet connection
- Ensure: Quota not exceeded (check Google Cloud Console)

### Camera not working
- Android: Verify permissions in manifest
- iOS: Check Info.plist permissions
- Test: Run on physical device (not emulator)

## Next Steps

1. **Fine-tune YOLO**: Train on your specific fridge types
2. **Add local storage**: Save detection history with Hive
3. **Batch processing**: Detect multiple fridges
4. **Notifications**: Alert on expiring items
5. **Sharing**: Export insights to recipes app

## Resources

- YOLOv8 Docs: https://docs.ultralytics.com
- Gemini API: https://ai.google.dev/tutorials
- Roboflow: https://roboflow.com
- TensorFlow Lite: https://www.tensorflow.org/lite/guide
