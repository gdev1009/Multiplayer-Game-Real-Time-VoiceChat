# Milestone 1 Sign-off Checklist

Product: Match Word (Grandma Mac)
Milestone: 1 - Sign In & Account System
Status target: Ready for client review and payment request

## 1) Scope Completion Checklist

- [ ] First-time account creation flow works end-to-end (first name -> email -> 4-digit PIN -> confirm PIN).
- [ ] Daily login works with first name + 4-digit PIN.
- [ ] Wrong PIN is rejected with calm, large-text messaging.
- [ ] Forgot-PIN recovery works via email one-time code, then allows setting a new PIN.
- [ ] Silent trial-abuse prevention is active (device that already used trial does not get another trial).
- [ ] AuthGate routing is correct:
  - [ ] No local account -> Welcome/Create
  - [ ] Local account on device -> Daily Login
  - [ ] Signed in -> Home placeholder
- [ ] Senior-first UI checklist met on all auth screens (large text, clear contrast, one primary action per screen, 48x48+ tap targets, no rushed timers).

## 2) Database + Security Checklist

- [ ] Migration applied: app/supabase/migrations/0001_init.sql
- [ ] Tables exist: profiles, device_trials
- [ ] RLS enabled on both tables
- [ ] Policies verified:
  - [ ] profiles_select_own
  - [ ] profiles_insert_own
  - [ ] profiles_update_own
  - [ ] device_trials_select
  - [ ] device_trials_insert
- [ ] No app secrets committed to source control (.env is local only).

## 3) Device Test Script (Manual QA)

Use one physical device (or emulator) and one known email inbox.

### A. Create Account

- [ ] Launch app on fresh install/device state.
- [ ] Confirm Welcome screen appears.
- [ ] Tap Create My Account.
- [ ] Enter first name.
- [ ] Enter email.
- [ ] Enter 4-digit PIN and confirm.
- [ ] Confirm app routes to Home placeholder.

### B. Lock + Daily Login

- [ ] Tap Sign Out on Home.
- [ ] Confirm Daily Login screen appears.
- [ ] Enter correct PIN and confirm sign-in success.
- [ ] Sign out again.
- [ ] Enter wrong PIN and confirm friendly rejection message.

### C. Forgot PIN Recovery

- [ ] From Daily Login, tap Forgot My PIN.
- [ ] Enter same email used at signup.
- [ ] Receive one-time email code.
- [ ] Enter code in app and continue.
- [ ] Set a new 4-digit PIN.
- [ ] Confirm app returns to login and new PIN works.

### D. Silent Trial-Abuse Check

- [ ] On a device that already consumed trial, attempt new account creation.
- [ ] Confirm account creation still works.
- [ ] Confirm second free trial is not granted.

## 4) Engineering Quality Gate

Run from app directory:

```bash
flutter analyze
flutter test
```

- [ ] Analyzer passes with no issues.
- [ ] Tests pass.
- [ ] Build runs on target iOS/Android device for demo recording.

## 5) Proof-of-Work Package (Client-Facing)

- [ ] Screen recording includes: create account -> logout -> daily login -> forgot PIN reset.
- [ ] Include short clip or screenshot proving wrong-PIN rejection message.
- [ ] Include short note confirming silent device trial check is active.
- [ ] Provide debug build artifact(s):
  - [ ] Android APK/AAB (as requested)
  - [ ] iOS test build/TestFlight note (as requested)

## 6) Sign-off Notes

Date:
Tester:
Build/Commit:
Supabase project ref:
Known limitations:
- Home is a placeholder in Milestone 1; opening screen/navigation shell starts in Milestone 2.

Decision:
- [ ] Approved for Milestone 1 payment request
- [ ] Changes required before submission
