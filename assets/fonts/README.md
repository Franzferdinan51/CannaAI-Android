# Fonts Directory

This directory contains custom fonts used by the CannaAI Flutter application.

## Current Fonts

### Custom Fonts
The app currently uses system fonts (Roboto on Android, San Francisco on iOS) for optimal performance and native feel.

### Future Custom Fonts
If you want to add custom fonts, place them here and update `pubspec.yaml`.

## Adding Custom Fonts

1. Place your font files in this directory
2. Update `pubspec.yaml` to include the fonts:

```yaml
flutter:
  fonts:
    - family: MyCustomFont
      fonts:
        - asset: assets/fonts/MyCustomFont-Regular.ttf
        - asset: assets/fonts/MyCustomFont-Bold.ttf
          weight: 700
```

3. Use the font in your Flutter code:

```dart
Text(
  'Hello CannaAI',
  style: TextStyle(
    fontFamily: 'MyCustomFont',
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
)
```

## Font Licensing

- Ensure you have proper licenses for any custom fonts
- Free fonts: Google Fonts, Font Squirrel
- Paid fonts: Adobe Fonts, MyFonts, etc.
- Web fonts need proper embedding licenses

## Font Formats Supported
- TrueType (.ttf)
- OpenType (.otf)
- WOFF2 (.woff2) - web optimized

## Performance Considerations
- Limit the number of custom fonts (affects app size)
- Use font subsetting for large character sets
- Consider variable fonts for multiple weights
- Test performance on older devices