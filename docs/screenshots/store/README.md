# Store screenshots

Full user-journey and store-ready frames for **Match Word**.

## Folders

- **`full-journey/`** — Raw phone captures (16 screens, onboarding → friends)
- **`app-store/`** — iPhone 6.7" listing frames (1290×2796)
- **`play-store/`** — Phone listing frames (1080×1920)

## Regenerate

```bash
cd app
flutter build web -t lib/demo_store_screens.dart --no-tree-shake-icons
python3 tools/capture_store_screenshots.py --serve
```

See [App Store Publishing.md](../App%20Store%20Publishing.md) for URLs, checklist, and recommended listing subset.
