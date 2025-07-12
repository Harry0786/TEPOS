# TEPOS App Icon Creation

## Instructions

1. Open the `icon_generator.html` file in a web browser.
2. You will see a green square with "TE" text in white.
3. Right-click on this image and select "Save image as...".
4. Save it as `app_icon.png` in the `assets/icon` directory.
5. After saving the icon, run the following commands:

```
flutter pub get
flutter pub run flutter_launcher_icons
```

This will generate the app icon for all platforms.

## Icon Design

The icon has the following specifications:
- Background color: #6B8E7F (the green color used in the app)
- Text: "TE" in white
- Font: Bold, Arial or similar sans-serif font
- Size: 1024x1024 pixels (will be resized for different platforms)

## Manual Icon Creation (Alternative)

If the HTML method doesn't work, you can create the icon using any image editing software:

1. Create a 1024x1024 pixel square image
2. Fill it with color #6B8E7F
3. Add "TE" text in white, bold font, centered
4. Save as PNG in the assets/icon directory
5. Run the flutter_launcher_icons command
