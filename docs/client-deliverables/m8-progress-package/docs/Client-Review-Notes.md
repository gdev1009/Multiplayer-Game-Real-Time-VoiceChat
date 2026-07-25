# Client Review Notes

## Quick Summary

The current build is ready for a visual/progress review through M8. It is not yet the iOS TestFlight install; TestFlight is the next packaging step.

The strongest review path is:

1. Watch the current progress video.
2. Watch the focused M6 host/audio video.
3. Check the billing/free-trial screenshot.
4. Send any feedback about clarity, pace, tone, or senior-friendliness.

## M6 Voice, Animations, and Alarm

The focused M6 video and screenshots cover what the broad progress reel cannot show slowly enough:

- Guy Smiley appears as the host during gameplay.
- The host, stage, speech bubble, score changes, and player busts animate.
- Audio controls include mute and separate music/effects volume.
- The disconnect alarm uses a full red overlay with a clear “Hold on!” message and a “Keep Playing” button.
- Current voice clips are placeholder TTS and can be replaced later without redesigning the app flow.

## Billing and Free Trial

The package includes:

- Home screen free-trial countdown: “5 days left in your free trial.”
- Paywall after trial: $5.99/month · cancel anytime (5-day free trial).
- Subscription screen: $5.99/month, Subscribe, Restore Purchases, and Not now.
- Backend/service scaffolding for entitlement checks and subscription sync.

Store purchase sheets are not live yet. Those require the TestFlight/App Store product setup step.

## Known Placeholder Items

- Prize/trophy images are temporary placeholder art.
- Host voice is a placeholder male voice.
- The web recording uses the app’s actual Flutter screens, but Android/iOS rendering can differ slightly in fonts and rasterization.
