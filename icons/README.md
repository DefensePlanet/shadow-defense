# App Icons

Generate the following icon sizes from the base `icon.svg`:

## Android
- `android/icon_192.png` — 192x192 launcher icon
- `android/adaptive_fg_432.png` — 432x432 adaptive foreground
- `android/adaptive_bg_432.png` — 432x432 adaptive background

## iOS
- `ios/icon_76.png` — 76x76 iPad
- `ios/icon_120.png` — 120x120 iPhone
- `ios/icon_152.png` — 152x152 iPad Retina
- `ios/icon_167.png` — 167x167 iPad Pro
- `ios/icon_180.png` — 180x180 iPhone Retina
- `ios/icon_1024.png` — 1024x1024 App Store

Generate with: `magick icon.svg -resize NxN icon_N.png`
