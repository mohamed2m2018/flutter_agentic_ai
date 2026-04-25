# ShopFlow Example

This example app now mirrors the same MobileAI configuration pattern used in FeedYum:

- hosted text proxy: `EXPO_PUBLIC_MOBILEAI_BASE_URL/api/v1/hosted-proxy/text`
- hosted voice proxy: `ws(s)://.../ws/hosted-proxy/voice`
- `enableVoice: true`
- `debug: true`
- telemetry via `EXPO_PUBLIC_MOBILEAI_KEY`
- route-aware `screenMap`

## Run

Use Flutter dart-defines with the same env names FeedYum uses:

```bash
cd example
flutter run --dart-define=EXPO_PUBLIC_MOBILEAI_KEY=your_mobileai_key --dart-define=GEMINI_API_KEY=your_gemini_key
```

By default the sample talks to `https://mobileai.cloud`. For local backend
development, put the localhost override in `.env`:

```bash
flutter run --dart-define-from-file=.env
```

## Notes

- The sample defaults `EXPO_PUBLIC_MOBILEAI_BASE_URL` to `https://mobileai.cloud`.
- Use `.env` to override `EXPO_PUBLIC_MOBILEAI_BASE_URL` to `http://localhost:3001` for local development.
- `GEMINI_API_KEY` remains available as a direct-provider fallback for local development.
- The example uses a manual `screenMap` in [/Users/mohamedsalah/mobileai-suite-copy/mobileai-flutter/example/lib/ai_screen_map.dart](/Users/mohamedsalah/mobileai-suite-copy/mobileai-flutter/example/lib/ai_screen_map.dart).
