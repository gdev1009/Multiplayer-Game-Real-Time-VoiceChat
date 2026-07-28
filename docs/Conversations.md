She(Ronna M. @RonnaLee8) sent me a msg:
"Hello! Thank you for your proposal. Before we proceed, I have a few questions: 1. Have you built a game before that real people actually played — not just a demo? If yes, can I see it or try it? 2. Match Word is designed for seniors. How would you make sure the interface is simple, large-print friendly, and not overwhelming? 3. What would your first milestone be, and how much would it cost? 4. How do you handle it when something isn’t working and you’re stuck? Do you communicate problems right away or try to fix them first? "

I replied:
"Hello Match Word, thanks for the questions.

Yes, the closest public example I can share here is the Google Multiplayer AR Game/Dino Runner project, which was a real multiplayer AR experience used for Google I/O, not just a private demo. I also have mobile interactive experience from projects like the Samsung Retail Mobile App. I can share the relevant public references here in Freelancer chat.

For seniors, I would keep the interface very calm: large text, big tap areas, high contrast, minimal buttons, one clear action per screen, and no crowded menus. The goal is that someone can understand what to do without needing instructions.

For the first milestone, I would suggest the Visual Layout & Interface Shell: main menu, lobby, room code screen, player waiting state, basic game screen layout, and large-print UI direction. I can do that as a fixed milestone for $500 CAD.

If something is not working, I first reproduce and isolate the issue, then I communicate it clearly if it affects scope, timing, or a technical decision. I don’t hide problems, but I also don’t send constant small messages. I would keep questions grouped into scheduled updates as you requested."

She replied:
"Hi Gregory, Thank you for your thorough and thoughtful responses to my screening questions — they were exactly what I was hoping to see. I'm very interested in moving forward with you on Match Word. Before we get to the NDA and full specification, I have a few important questions I'd like answered first: 1. CURRENCY — Your first milestone quote of $500: is that in USD or CAD? My budget is loaded in CAD on Freelancer, so I want to make sure we're comparing apples to apples. 2. TIMELINE — I understand you may not be able to give a firm timeline until you've seen the full spec, but can you give me a general sense of your current availability? Are you working on other projects right now, and roughly when could you start? 3. VOICE INPUT — Match Word requires players to press a button and speak their clue, with their spoken words appearing as text visible to all players in real time. Have you built anything with voice input and real-time text display before? 4. AI PLAYERS — When fewer than 4 human players join a game, AI characters fill the empty seats and participate as real players (giving clues and guessing). Have you worked with AI-driven game logic like this before? 5. SOUND & AUDIO — The game includes theme music, a voice announcer, sound effects (applause, cheering, alarm), and a host character with voice. Have you integrated audio systems like this into a mobile app before? 6. APP STORE PUBLISHING — Have you published completed apps to the Apple App Store and/or Google Play Store? Match Word will need to be available on both iOS and Android. 7. SUBSCRIPTION BILLING — Match Word runs on a $5.99/month subscription model with a 7-day free trial (no credit card required upfront). A countdown timer shows players how many days remain in their trial. Have you built in-app subscription billing through both the Apple App Store and Google Play before? Once I have your answers, I'll have a full technical specification ready to share with you after we complete the NDA. Looking forward to hearing from you! Ronna"

She replied:
"Hi Ronna,

Thank you, I’m glad the answers were helpful. Happy to answer these before the NDA/spec.

The $500 milestone quote was in CAD, since your Freelancer budget is in CAD.
I am working on other projects, but I can start the first milestone shortly after the NDA, full spec, and funded milestone are in place. For the first UI/layout milestone, I would expect roughly 5 to 7 working days depending on the final screen count.
Yes, I have worked with real-time mobile interaction and audio-related flows. For Match Word, I would treat this as press-to-speak, speech-to-text, then sync the recognized clue text to all players through the multiplayer server so every device sees the same result.
Yes, I can handle AI player logic. For the MVP, I would keep the AI characters simple and predictable first, so they can fill empty seats, give basic clues, guess, and follow the same turn rules as human players. More advanced behavior can come later after the core game is stable.
Yes, I have integrated sound and audio systems in mobile apps before. I would structure this with a simple audio manager for music, announcer lines, host voice, applause, alarm sounds, and game state-based effects.
Yes, I have experience with iOS and Android app delivery, including App Store and Google Play preparation, build signing, testing, and submission support.
Yes, subscription billing can be built through Apple and Google in-app subscriptions with a 7-day trial and trial countdown inside the app. One small detail to confirm later: Apple/Google control the subscription checkout flow, so the “no credit card upfront” part depends on their billing requirements and the user’s store account setup. The in-app countdown and access control are fully manageable.

Overall, nothing here changes my view that the MVP is feasible. My main recommendation is still to keep the first milestone focused on the senior-friendly interface and core app structure before going deeper into the real-time sync, voice, AI players, and billing."

She replied:
"TO: Gregory H. (@HamparProd) — Freelancer.com chat only RE: Match Word — Welcome to the Team! --- Hi Gregory, Congratulations — and welcome to the Match Word team! We are absolutely thrilled to have you on board. I want to share a little bit about why this project means so much to me personally. I am a senior myself, and I spent decades working as a social worker on the frontlines — child protection, disability services, and eventually teaching social work at the college level. One of the biggest issues I saw throughout my career, and still see today, is senior loneliness. It is a genuine crisis and it breaks my heart. Match Word is my answer to that. I want to give seniors something fresh, fun, and social — a reason to show up, laugh, connect with friends, and maybe even make new ones. This is my baby, and I intend for us to do an absolutely wonderful job with it together. Your answers were thorough, honest, and exactly what I was hoping to hear. I especially appreciated that you flagged the Apple/Google billing detail — that kind of transparency is exactly how I like to work. A few things about how I work so we start off on the right foot: — I have several other projects on the go, which is why I keep my availability structured. — I will answer your questions sometime during the day that you send them. — I take weekends off. — All communication stays on the Freelancer platform chat only — no email, no phone. Next steps: I will send the NDA for your review and signature. Once that is signed, I will share the full project specification and we can get Milestone 1 funded and underway. I cannot wait to get started! Ronna Grandma Mac grandmamac.com"

I replied:
"Thank you so much. I really appreciate the warm welcome, and I’m genuinely glad to be part of Match Word.

The purpose behind this project means a lot. Senior loneliness is a real issue, and I can see why this is so personal for you. I’ll treat the work with the care and patience it deserves, not just as another app build.

Your communication style works well for me. I’ll keep everything inside Freelancer chat, group questions clearly, avoid unnecessary back-and-forth, and respect your weekday schedule and weekends off.

Please send over the NDA when ready. I’ll review it here, and once it is signed, I’ll go through the full specification and we can define and fund Milestone 1 properly before starting.

Looking forward to building this together."

She sent me NDA, I sent back NDA with signed.

---

## After NDA — Freelancer chat (project work)

I sent (alpha / M1–M6 test):
"Hi Ronna — thank you for your patience. The Match Word alpha through Milestone 6 is ready for you to try on phone.

What to install: MatchWord-stageFix2-phone-arm64-20260713.apk (most phones). There are also arm32 and LDPlayer versions if you need them.

How to test: I’ve written a full step-by-step guide covering Sign-in → Opening → Character Studio → Lobby → Live game → Guy Smiley host + sound: Match Word Alpha Test Guide M1-M6.

Two phones work best (one hosts, one joins with the 4-digit code). One phone is fine too — use Add Players so studio teammates fill the empty seats.

Quick Test Sign-In: On the Welcome screen you’ll see a Quick Test Sign-In button. That button is only for testing so we can get into the game quickly without making a full account every time. It will disappear on the productive / store version — real players will only use Create Account, Daily Login, and Forgot My PIN.

When you have a chance, please work through the checklist and let me know what feels clear, confusing, or needs polish.

Warmly,
Gregory"

She replied (Drive / APK naming + prefer direct install):
"Hi Gregory,

Thanks for the update! I tried downloading the APK but ran into a couple of snags:

1. The file I received from the Drive link is named \"MatchWord-stageFix-phone-arm64-20260713.apk\" but your message mentioned \"MatchWord-stageFix2-phone-arm64-20260713.apk\" (note the \"2\"). Just want to confirm I have the right build before I test.

2. Google Drive gives a \"too large to scan\" warning and it's a bit of a fiddly process to get it onto my phone. Would you be able to send me a direct download link instead (something like Diawi or Firebase App Distribution) that I can just tap on my phone to install, without going through Drive? That would make testing a lot smoother going forward.

Thanks so much,
Ronna"

I replied:
"Hi Ronna — thanks for flagging both of those.

1. You’re right that the Drive file name didn’t match what I wrote. The build you downloaded (…stageFix…, no \"2\") was an older package. Please don’t use that one. I’ve just rebuilt a fresh APK for you today: MatchWord-stageFix3-phone-arm64-20260714.apk. That’s the one to install.

2. Totally fair about Drive — the \"too large to scan\" warning is awkward. Here’s a direct install link you can open on your phone: [Diawi / Firebase link]. Tap it → install → allow \"Install unknown apps\" if prompted. Going forward I’ll share test builds this way so you don’t have to wrestle with Drive.

Same Quick Test Sign-In button is still there for alpha testing. If anything feels off once you’re in, just ping me."

She replied (iPhone only — needs TestFlight):
"Hi Gregory,

Thanks for the fresh build and the Diawi link — that part worked great! But I realized when I opened it that I only have an iPhone (no Android device or emulator), so I'm not able to install or test the .apk file.

I'm sorry for the extra work this creates on your end. Would you be able to set up a TestFlight build for iOS so I can test on my iPhone going forward? I know Match Word is meant to work on both iOS and Android eventually, so I just want to make sure I can actually test it myself as we go.

Thanks so much for your patience,
Ronna"

I replied:
"Hi Ronna — totally understand, and thank you for saying so clearly. No need to apologize.

Right now the alpha builds are Android-only, which is why the Diawi APK worked on the download side but can’t install on your iPhone. That’s on me for not checking what device you’d test on first.

Plan going forward: I’m already into Milestone 7, and I’ll wrap M7 and M8 soon. The iOS / TestFlight build is scheduled for Milestone 9, so you’ll be able to tap an invite on your iPhone and test there going forward — same codebase, just the iOS delivery path dialed in then.

In the meantime, I’m putting together a screen recording of the current progress so you can still see and review the flow without needing an Android device. I’ll send that as soon as it’s ready.

Thanks again for the patience — glad the Diawi link itself was smooth, and we’ll get you onto TestFlight when we hit M9.

Warmly,
Gregory"

I later sent a current-progress review package (through M8) for iPhone review before TestFlight (see docs/Progress Reel Client Chat Message.md / docs/Alpha Test Client Chat Message.md / docs/client-deliverables/m8-progress-package/).

I asked her for Apple Developer access for TestFlight (and later Google Play Console for Android + subscriptions). She preferred invite-only (no shared passwords). Freelancer blocks plain emails in chat, so we used spaced text / file attachment for account emails.

She replied (M8 package review — studio-first + accounts):
"Hi Gregory,

Here's where things stand on my end:

M8 Progress Package Review

Before anything else, the most important piece of feedback I have: the studio scene needs to be the main focus of the whole app. Right now it feels like a small part of the screen surrounded by a lot of other stuff. I want players to feel like they're actually standing in a game show studio when they play — that's the whole feeling I'm going for, and it's the top priority for me.

Concretely:
- Please shrink the top header/title bar (the \"Match Word\" banner) as much as possible so it takes up less space.
- Look at what else is taking up screen real estate around the studio (labels, extra text boxes, etc.) and see what can be trimmed or made smaller so the studio itself becomes the dominant visual.
- Since Guy Smiley will be speaking and announcing whose turn it is out loud, some of the on-screen text (like \"Sunny, it's your turn!\") may be redundant with the voice — if trimming that helps give the studio more room, I'm all for it. I trust your judgment on what's needed for accessibility versus what's just clutter.

Other feedback from going through the video, the M6 video, and the screenshots:
1. Guy Smiley's voice — I'd like it deeper and louder. I had my volume all the way up and it was still hard to hear.
2. The characters/players look small and a bit hard to see clearly — is there a way to make them larger or more prominent, especially for senior players?
3. The M6 host-voice-animation video plays but has no audio at all. I confirmed this isn't a device issue on my end — the file itself seems to be missing its audio track.
4. Is the current plainer studio look a placeholder before the character art and studio visuals get layered in, or is it close to final? Just want to understand where things stand.

Apple Developer Account — I've created my own Apple Developer account and I'm waiting on Apple's approval (24–48 hours). Once approved, I'll add you as a team member in App Store Connect with an appropriate role — I won't be sending my Apple ID login directly, for account security reasons.

Google Play Console Account — I've also created my own Google Play Console developer account (under Grandma Mac). I'm currently working through the required verification steps. Same as above — once it's set up, I'll add you as a user with appropriate permissions rather than sharing my login.

Mailgun — Still working through your setup guide for grandmamac.com — will follow up separately on that.

Thanks,
Ronna"

I replied agreeing studio-first was top priority, noted deeper/louder voice, larger characters, regenerating the silent M6 video, and that the plainer studio was not final. We also sorted store access: she would invite me (Developer role); I asked her to share the Apple/Google account emails (no passwords) so I could send collaboration requests, or she could invite my email via spaced text / attachment.

She replied (hold M6 payment until studio pass; invite-only access):
"Hi Gregory,

Thanks for the thorough response — really glad we’re aligned on the studio being the priority, and appreciate you catching the audio issue on the M6 video so fast.

On the account access question — I hear you on Freelancer blocking emails in chat, that makes sense. But I’d still rather not share account passwords directly, even for dedicated developer accounts — that’s just a boundary I want to hold for security reasons on both the Apple and Google side. The good news is App Store Connect and Google Play Console both have their own built-in invite systems (Users and Access on Apple, Users and Permissions on Google Play) that let me add you with a Developer-level role — enough to upload builds and manage TestFlight/Play testing — without giving you the master login.

To make that work, I just need your email address, and since Freelancer’s chat won’t let it through as plain text, here are a few ways to get it to me:
1. Type it with spaces or substitutions so the filter doesn’t catch it — like “gregory [at] gmail [dot] com”
2. Attach it in a file or screenshot instead of typing it directly in the message box
3. Include it in a milestone deliverable note or project doc

Once I have it, I’ll send the invites from both consoles directly.

On Milestone 6 — I want to hold off releasing payment for now. Based on what you described, it’s not quite finished yet: the video is missing audio (which you’re regenerating), and you mentioned the studio look itself is still a functional placeholder, not the final version you’re aiming for after the studio-first pass. Let’s treat M6 as complete once I’ve seen the updated screenshots/video with the studio changes, the fixed audio, and the larger/higher-contrast characters — then I’ll release it right away.

Thanks again for the clear breakdown — looking forward to seeing the next pass.

Ronna"

I replied agreeing to hold M6 until the studio pass, and we flipped invites so she could send the two account emails and I’d request access / she’d accept:

"Hi Ronna —

Totally understand wanting to keep passwords off the table — I’m with you on that.

For the console invites, let’s flip it so I don’t need to put my email in Freelancer chat. If you can send me (safely — file attachment or spaced text is fine):

1. The Apple ID email on the App Store Connect / Apple Developer account for Match Word
2. The Google account email used for the Google Play Console

No passwords — just those two account emails.

I’ll send the access / collaboration requests to those accounts from my side. You’d only need to accept the invites in App Store Connect and Play Console when they arrive. That keeps master logins with you and avoids me posting an email in chat.

On Milestone 6 — agreed. Hold payment until you’ve seen the updated studio pass (screenshots/video with the studio-first look, fixed audio, and larger / higher-contrast characters). I’ll send that next package as soon as it’s ready for your review.

Thanks again,
Gregory"

She shared store account emails (saved in docs/App Store Publishing.md):
Apple ID + Google Play: rljjmckenzie@gmail.com (same address for both). I send collaboration requests; she accepts.

I also sent Mailgun setup guidance for her side (docs/Mailgun Setup Guide for Ronna.md) — Supabase stays on my side.

---

### Studio / Guy Smiley / ElevenLabs

I sent walkthrough updates (including video6 / stageFix builds) for her to check red flag, Guy cutout, and studio feel.

She replied (ElevenLabs voice reference + studio concept image + M6 host must run the show):
"https://elevenlabs.io/app/voice-lab?… (Voice Lab link she created)

Hi Gregory,

Thank you for the update on Milestone 6! I can see progress on the four characters, and I appreciate you putting something together to show me.

I wanted to share some feedback before we move forward with payment. I sent you the ElevenLabs voice link as a reference for the kind of energy I'm hoping for with Guy Smiley - big, warm, booming, like a classic game show host. What I received back sounds computerized and repeats the same line, so I'm not yet seeing that host personality come through in the demo.

I also want to make sure we're aligned on scope for M6: Guy Smiley isn't just a voice playing in the background - he needs to actively run the game. That means welcoming players, announcing rounds, reacting to right/wrong answers. Maybe a bell should ding ding ding for right answer and a buzzer for wrong answer would help. He needs to be building excitement, and guiding the whole show from start to finish. I know this might just be an early demo step, so I don't want to assume the worst, but I want to be upfront about what I'm hoping to see before we call M6 complete.

To help, I've also put together a Studio concept (built in ChatGPT) showing the game show setup and how I picture the host interacting with the game. I'm attaching that now so you have a clearer visual reference.

Can you please look at this and see what you can come up with?

Thank you,
Ronna"

(Studio concept image: gold marquee seats, Match Word sign, Guy center, four players — app/assets/images/ChatGPT Image Jul 20.png.)

I replied:
"Hi Ronna —

Thank you for the clear feedback, the ElevenLabs link, and the studio concept. That image is really helpful — gold marquee seats, Match Word sign, curtains/lights, Guy in the center with the four players around him. That’s the show feel we’re aiming for.

On the voice: I hear you. Big, warm, booming classic game-show host — not thin or computerized, and not the same line on loop. Your ElevenLabs design is a great reference for the energy. The current demo uses shorter pre-recorded clips as a first pass, and that clearly isn’t landing the personality yet. Next step on my side is to rebuild Guy’s lines to match that tone (welcome, rounds, right/wrong reactions, winner) so he sounds like the host in your link, not a generic TTS read.

On scope for M6: we’re aligned. Guy isn’t background audio — he should run the show: welcome players in, introduce rules, announce rounds, react to right and wrong answers, and carry excitement through to the winner. Visually he’s already tied to those moments (green flag / red flag / reveal / winner). What’s missing for you is that full host personality + clearer cueing in the audio. Your ding-ding-ding for correct and buzzer for wrong is a great call — I’ll add those so the reactions punch harder even before the next voice pass.

In the original quote, ElevenLabs for dynamic/live lines was listed as a later-phase add-on, with M6 using a set of warm pre-recorded host lines. Happy to stay on that path and make the pre-recorded set match your ElevenLabs energy, or pull ElevenLabs forward if you want the exact voice from your Voice Lab. Tell me which you prefer and I’ll build to that.

I’m treating your note as the bar for calling M6 complete: host personality you can feel, and Guy clearly guiding the game start to finish — with your studio concept as the visual north star.

I’ll put together an updated host/audio pass and send a short demo focused on that. Thanks again for being direct — this helps a lot.

Gregory"

She then set up ElevenLabs access for me (Game Show Host voice + Sound Effects on a TTS-only API key — key stored privately, not repeated here). Voice id: DHeX7CCuOXUPRpnb0AdT. Full note:

"Hi Gregory,

Thank you for such a thoughtful reply, and I'm so glad the studio image landed the way I hoped. Yes, that's exactly the show feel I'm picturing.

On the voice: instead of sending you a short sample, I've set you up with direct access to the actual voice I designed in ElevenLabs, so you can generate as many lines as you need, in whatever wording works best for the game, rather than being limited to one or two samples.

Here's what you need:
API Key: [private — not stored in this doc]
Voice id: DHeX7CCuOXUPRpnb0AdT
Voice Name: Game Show Host

This key gives you Text-to-Speech access only, so you can generate Guy Smiley's lines directly, but it doesn't give access to my account settings or billing. I've also turned on Sound Effects access on the same key, since I'd like you to pull in the ding-ding-ding for correct answers and the buzzer for wrong answers using ElevenLabs' sound effects tool - that way the whole audio feel (voice and effects) comes from one consistent source.

Given this, let's go ahead and pull ElevenLabs forward now instead of waiting for a later phase. Since you'll have direct access to generate lines dynamically, there's no need to lock into a fixed set of pre-recorded lines for M6 - you can generate the full range of what Guy needs: welcoming players, introducing rules, announcing rounds, reacting to right and wrong answers, and carrying the excitement through to the winner, all in this voice.

Your read on M6 sounds exactly right to me: host personality you can feel, and Guy clearly guiding the game from start to finish, with the studio concept as the visual backdrop. Please go ahead and start the audio pass with this voice and the sound effects whenever you're ready.

Thank you again for being so thorough and easy to work with on this - it makes a big difference.

Ronna
Grandma Mac"

I replied thanking her and asked her to check the latest studio recording first, then we’d continue the audio pass from her feedback:
"Hi Ronna —

Thank you so much for this — and for setting up the ElevenLabs access with the Game Show Host voice and the sound effects. That’s incredibly helpful, and I’ll keep that ready for the full audio pass.

Before we dig further into generating more lines and effects, I’d love for you to check the latest studio build first and tell me how it feels. I’ll share a short recording of the current game so you can see the updated stage, seats, and host in action.

Once you’ve had a look and shared any feedback, I’ll take the next audio pass from there with this voice.

Thanks again — really appreciate how clear and easy you’ve been to work with on this.

Gregory"

She replied (studio looks great; text too small; mystery word front-and-center):
"Hi Gregory,

This new demonstration looks great! The studio came together really well, and the players look good too.

One fix needed: the font is too small overall - not just the mystery words and guesses, but the player names too. Could you increase all the text throughout the studio as large as possible without disrupting the layout? Bolding it would help as well.

Also, for the mystery word specifically, I'd love it moved to a more prominent spot so there's zero confusion about what word it is - somewhere similarly front-and-center? The person giving the clue needs to see it instantly, no squinting or guessing.

Separately, I've put together a suggestion for Guy Smiley's full introduction script, plus a set of \"correct answer\" reactions and \"wrong answer\" reactions so his responses vary each time instead of repeating. I'll send those over next so you can start building them into the audio pass.

Thanks again, this is looking really strong.
Ronna"

I replied:
"Hi Ronna —

So glad the studio landed for you — thank you!

Got it on the text: I’ll bump up the size (and bold it) across the studio — names, mystery word, guesses, the works — as large as we can go without crowding the layout.

And yes on the mystery word — I’ll move it somewhere more front-and-center so the clue-giver can see it instantly, no squinting.

Looking forward to the intro script and the correct/wrong reaction sets — once those land I’ll start folding them into the audio pass.

Thanks again for the clear notes. More soon!

Gregory"

She sent intro + correct/wrong reaction banks (full range so Guy doesn’t repeat), plus notes: wrap-up at end of game; games room with wins/ties/losses + “stay tuned for annual tournament”; guessers need ~15–20 seconds before buzzer.

INTRODUCTION (canonical — also in host_voice_scripts.dart):
“Ladies and gentlemen… welcome to the studio that makes words come alive… this… is MATCH WORD! I’m your host, Guy Smiley, and let me tell you, we are in for a fantastic time today! Here’s how we play: one lucky player on each team becomes the Clue Giver, and it’s their job to describe our mystery word with just one word — without saying the word itself, of course! The other player on the team is the guesser. Guess it right, and the points are yours! Get it wrong, and the team has a chance to steal with their own clue! Are you ready to play? Let’s find out who takes home the win… right here, right now, on MATCH WORD!”

CORRECT ANSWER bank (examples): “Yes! You got it! Fantastic!” / “Ding ding ding! That's exactly right!” / “Bingo! You nailed it!” / “That's it! Give that player a round of applause!” / … (15 lines — see HostVoiceScripts.correct)

WRONG ANSWER bank (examples): “Ohhh, so close, but not quite!” / “Buzz! Not this time, folks.” / “Ohh, too bad! It moves on to the next player now.” / … (15 lines — see HostVoiceScripts.wrong)

Also: wrap-up lines at end of game; Prize/Games Room with wins/ties/losses + tournament teaser; 15–20s guess window.

I replied:
"Hi Ronna —

Thank you for all of this — the intro, the correct/wrong reaction banks, and the wrap-up note are exactly what we need so Guy doesn’t sound like he’s on repeat. I’ll build from these and trim/mix as we go.

Also noted on the games room idea: a simple page with wins / ties / losses, plus a “stay tuned for the annual tournament” line for top scorers — I like that a lot.

And yes on the clock: I’ll give guessers more time — somewhere in that 15–20 second range before the buzzer.

Studio text and mystery-word placement from your earlier note are already in the latest build. Once the audio pass is further along, I’ll send another recording so you can hear Guy with the new lines.

Thanks again — this is such clear, useful direction.

Gregory"

She later released a milestone, shared buzzer + cheer/clap clips (and links), and asked for ~10–15s opening music before Guy speaks.

I replied:
"Hi Ronna —

Thank you so much for releasing the milestone — really appreciate that, and I’m glad the studio is feeling like it’s coming together for you.

Got the sound-effect links and the two clips you attached (buzzer + audience cheering/clapping). I’ll fold those into the audio pass so the right/wrong moments land with that game-show punch.

And yes on the opening music — I’ll add a short bed (about 10–15 seconds) at the start of the game, before Guy starts speaking, then hand off into his welcome.

I’ll send another short recording once that’s in so you can hear how it feels.

Thanks again!
Gregory"

---

### Billing / trial length

She replied:
"hi gregory, Quick update before you get further into the subscription billing milestone — I'd like to have you change the free trial length from seven days to five days. Everything else in the milestone (countdown timer, App Store plus Google Play billing integration, $5.99 a month) stays the same. I hope this doesn't affect anything you've already built. thank you Ronna"

I replied:
"Hi Ronna —

Got it — thanks for the quick heads-up.

I’ll change the free trial from 7 days to 5 days. Everything else stays as planned: countdown timer, App Store + Google Play billing, and $5.99/month.

It’s a small config change on my side, so it won’t disrupt what’s already built. I’ll update it as part of the subscription billing milestone.

Thanks!
Gregory"

I later confirmed the update:
"Hi Ronna —

Quick update: the free trial is now 5 days (was 7). Everything else is unchanged — countdown timer, App Store + Google Play billing, and $5.99/month.

I’ve got fresh screenshots ready (home trial banner + subscribe screen) if you’d like to take a look.

Thanks!
Gregory"

---

### Ongoing studio polish (recordings / APKs)

I sent short notes asking her to review updated recordings and builds as we implemented her feedback (studio layout, seats/names, bubbles, mystery word, welcome timing, Guy placement, seat fill/clip, larger characters).

Latest simple ask for feedback:
"Hi Ronna — here’s an updated build when you have a moment. Please take a look and let me know how it feels / anything you’d like changed. Thanks!"

---

### Video feedback — Guy motion, cheer length, pacing (Jul 2026)

She replied:
"Hi Gregory,

Thanks so much for sending the video — I really loved the opening with the music and Guy's introduction, that set the tone perfectly!

A few things I noticed watching it through:

1. Guy isn't moving — during playback he seems frozen/static rather than animating while he talks.

2. Audio is cutting off in places — I noticed it especially around when he talks about halftime, some words seem to get clipped.

3. Audience cheering/clapping is too short — could we make that much longer? It's a fun moment and it goes by too quickly right now.

4. Pacing is too fast for our seniors — when we ran through it, the round moved much quicker than someone would realistically need to type an answer. Could we slow it down significantly, or at least build in enough time for typing before it moves on?

5. Voice vs. typing choice — I know the original spec has players choosing to either speak or type their clue/answer, with both as clearly labeled buttons. I didn't see where that choice appears on screen in this video — can you confirm it's implemented, and if so, where/how it shows up for the player?

6. AI characters — will the AI player characters change or rotate a bit from game to game (different look/personality), or are they the same each time?

Let me know if you need me to clarify any of this. So great to see it coming together!

Thanks,
Ronna"

I replied:
"Hi Ronna —

So glad the opening landed for you — thank you!

Here’s where I am on each of your notes:

1. Guy not moving while he talks — You’re right — he should feel alive while he’s speaking, not frozen. I’ll wire his talking animation back in so he animates through the welcome / host lines.

2. Audio cutting off (especially around halftime) — Got it. I’ll check those clips (halftime especially) and fix any early cutoffs so lines finish cleanly.

3. Cheering / clapping too short — Agreed — that’s a fun beat and it shouldn’t blink by. I’ll stretch the audience cheer/clap so it lands longer.

4. Pacing too fast for seniors — Totally fair. I’ll slow the round timing and give more room to type before the turn moves on, so it feels calmer and more realistic for our players.

5. Voice vs typing — Yes — the design is speak or type. On the player’s turn, the bottom dock is meant to offer both (press-to-speak mic + type field). In that recording it may not have been obvious depending on whose turn it was / the camera framing. I’ll make the choice clearer on screen so both options are easy to spot.

6. AI characters — They get a look based on the seat/name for that game, so they stay consistent during a match. Across different games / different names, the looks can vary — they aren’t locked to one face forever. If you’d like more variety even when the same names come back, I can loosen that too.

I’ll work through these and send another short recording once the main ones are in. If any of the above needs a different direction, just say so.

Thanks again — this is really helpful feedback.

Gregory"

Follow-up polish (host puppet / lipsync / welcome announcer animation) continued via APKs and recordings (video23–video25, MatchWord-v25Announcer / Announcer2 builds).

---

### Phase 1 scope — trophies over store (Jul 2026)

She replied:
"Thanks Gregory. One thing I didn't mention is that I no longer think the store is something I need for phase one. As discussed, if we could give the active players a clay looking trophy for each game they win. Maybe it could be shown when they sign in? Whatever is easiest. I want it to help to have them want to back and play again. Thanks! Ronna"

I replied:
"Thanks Ronna — that helps a lot.

We’ll drop the store from phase one. For the win reward, the simplest path is what we already sketched: a clay-looking trophy each time someone wins a game, kept in their Prize Room. On sign-in we can show a quick “you’ve got X trophies” moment (or highlight the latest win) so it feels good to come back.

I’ll keep it light and easy — enough to make winning feel special without building a full store. I’ll send a quick look once it’s in a build.

Thanks!
Gregory"

Project update (implemented):
- Novelty prize “store” shelf deferred past Phase 1 (`PrizeAssets.showNoveltyPrizes = false`; migration `0022_phase1_win_trophies.sql`).
- One clay win trophy per match win (`profiles.games_won` drives the shelf count).
- Opening / sign-in home shows `WinTrophyWelcome` (tap → Prize Room).
- Milestone trophies (first win, 10 / 50 games) kept; novelty prizes stay in the catalog for later.