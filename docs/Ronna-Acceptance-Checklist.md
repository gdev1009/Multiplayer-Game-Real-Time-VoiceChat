# Match Word — Acceptance checklist (for Ronna)

**Build to test:** iPhone TestFlight **1.0.0 (89) or newer**. Use the exact number Gregory quotes in his message.

This round covers the three things you raised after your last game: the
**stand-in clues that made no sense**, **everyone having white hair**, and the
**music**. Sections A–B and D and F–H are re-checks from last round. The entry
problems (overlapping buttons, the Subscribe lock-out) are covered again at the
end so we know they stayed fixed.

Please tick each item. If something fails, a screenshot of that screen is enough.

---

## 0. Confirm you have the right build (please do this first)

- [ ] In **TestFlight**, Match Word shows **1.0.0 (89)** — tap **Update** if it offers one.
- [ ] Fully close Match Word (swipe it away), then open it again.
- [ ] At the bottom of the **PIN / sign-in** screen you can read **“Match Word 1.0.0 (89)”**.
- [ ] At the bottom of the **Home** screen (under Sign Out) you can read the same **1.0.0 (89)**.

If those lines do not say **89**, please stop and send a screenshot — you are on an
older install and nothing below is a fair test.

---

## A. Taking turns (you chose "back and forth")

You reported that about three-quarters of the way through, the other team was
getting **two or three turns in a row**. The cause: the game worked out whose turn
it was by counting the word number, so after a steal the same team could come
round again. It now goes by **who actually went last**.

- [ ] Turns go **back and forth** all game — no team ever gives two clues in a row.
- [ ] This still holds **after a steal** (the team that stole does not also open the next word).
- [ ] It still holds in the **second half**, after the halftime switch.
- [ ] Please play a **full game** and watch the late rounds especially — that is where you saw it before.

For the record, the rule as it now stands: guessing correctly **scores the
points but does not earn your team another word**. The next word passes to the
other team. Tell me if you would rather the winning team stayed in.

---

## B. Clues (the repeat you spotted)

You reported the opposition being handed **the same clue you had just given**, and
then your side giving that same clue again.

- [ ] After a steal, the other team's clue-giver gives a **brand new clue** — never yours repeated.
- [ ] The same clue is **never used twice on the same word**, by either team.
- [ ] If you try to type a clue that has already been used on that word, you are asked for a different one.
- [ ] The clue word is now visible to **both** clue-givers, so whoever gets a steal is ready.
- [ ] Guessers still **cannot** see the word (please confirm this did not leak).

---

## C. Stand-in players — the clue words themselves (please read)

This was the big one, and you were right. The problem was not the stand-ins and
it was not the scoring — it was **the clue list behind the word database**.

Of the 1,209 words in the database, **1,010 had no real clue attached**. They had
a category label instead. 91 different words were all clued **"Person"**. Another
90 were all clued **"Place"**. The single clue **"Spot"** was standing in for
**145 different answers**.

So the game would say the clue *"Person"*, the stand-in would answer
*"Accountant"*, and the game marked it **correct** — because "Accountant" really
was the secret word. That is exactly what you saw: "the answers they're giving
are not making any sense. And yet often times they tell them they're right."

The fix: a game now only deals words that have **real clues** that point at one
answer. That is 274 words, each with three hand-written clues (a game uses 16
words, so there is plenty of variety). Examples of the new clues:

| Word | Clues |
|---|---|
| Tomato | Ketchup · Vine · Salsa |
| Spider | Web · Arachnid · Tarantula |
| Birthday | Candles · Presents · Wishes |
| Nose | Nostrils · Sneeze · Sniffle |

- [ ] Every clue you hear **points at its word**. No more "Person", "Place", "Thing" or "Spot".
- [ ] When a stand-in **guesses wrong**, the wrong answer is still in the same family — a miss on a food word is another food, not "bicycle" for "teapot".
- [ ] A "correct" is only ever called when the answer **really is** the word, and the clue makes that fair.
- [ ] Over a full game the stand-ins feel like people playing, not nonsense.

If any single clue still feels unfair, please send me **the clue and the word**.
One pair is enough for me to fix it.

---

## C2. Hair colour (new)

You said: "everybody's hair is white. We need to have a choice of hair colour."

The hair artwork was supplied as plain grey so it could be coloured in, but
nothing ever coloured it — so everyone came out white-haired. There is now a
**Hair colour** step right under the hairstyles, with nine colours.

- [ ] In **Create / Edit character**, after picking a hairstyle you see **Hair colour** swatches.
- [ ] Tapping a colour changes the hair **straight away** in the preview.
- [ ] The choice is still there after you **save and reopen** the app.
- [ ] Your existing character is **no longer white-haired** (it defaults to brown).
- [ ] **Grey** and **White** are still available if you want them.

---

## D. Guy's voice

- [ ] Guy **no longer garbles or distorts** partway through a line.
- [ ] His **longer** lines (the welcome, the halftime and end-of-game speeches) stay clear all the way through.
- [ ] He is still a warm game-show host — please say if he now sounds too flat or not deep enough.

He used to be played back slightly slowed down to sound deeper, which is what
smeared his voice. The depth now comes from the voice itself.

---

## E. Music and audience

You said: "The music at the end of the game is pretty light and easy going. I like
that. I think we should use that throughout the game."

The track that had been looping all game was the problem. It is only **8 seconds
long**, and it is a two-second brass riff repeated four times — so the horns came
back every two seconds for the whole game. There was no gentle passage in it to
switch to.

The bed is now built from the **light second half of the opening music** you said
you liked. Measured against the old one, the trumpet/trombone range dropped from
**51% of the track to 25%**, and the volume no longer slams up and down every
quarter second.

- [ ] The in-game music is now **light and easy going** — the horns no longer take over.
- [ ] It does not get **annoying or repetitive** over a full game.
- [ ] Music plays **continuously** through the game, not in bursts.
- [ ] Using the **microphone** (Speak) no longer kills the music — it comes back after you speak.
- [ ] Speaking twice in a game still leaves the music playing.
- [ ] At the **end of the game** you hear the music **and** the audience.
- [ ] The **opening** of the show is unchanged — please confirm you still like it.
- [ ] If it is still not right, the in-game sound control lets you set music to taste.

The mic was the "Mike" problem: opening it shut the whole audio session down and
nothing ever restarted the music, so it stayed dead for the rest of the game.

---

## F. Your name

- [ ] Your **own name** shows on your seat in the game.
- [ ] It matches the name on the Home screen.
- [ ] It is the name you signed up with — not a single letter and not a stand-in's name.

Seat names used to be copied once, when you sat down, and never refreshed. If
this is still wrong, please tell me **what it shows instead** and **what it
should say** — that pins it down immediately.

---

## G. Playing with a friend (the next thing you wanted)

Worth trying once the above looks right.

- [ ] I can start a game and give a friend the **4-digit code**.
- [ ] We both get into the same game from **different houses / phones**.
- [ ] Turns, clues and scoring behave the same as with stand-ins.
- [ ] Both of us hear Guy, the buzzer and the music.

---

## H. Still holding from last round (quick re-check)

- [ ] **Upcoming Games** and **Enter the Studio** are readable and do not overlap.
- [ ] The Subscribe screen does not appear or lock me out — an expired trial can still play.
- [ ] The Home **trophy** is large and the win number sits beside it, not on the cup.
- [ ] Guy's welcome and the character buttons are readable.

---

## I. Not in this build (please don't treat as a fail)

- Apple/Google **Subscribe** checkout is not live yet. Payment stays switched **off** for testing — nothing can lock you out.
- The **annual tournament / cash prizes** are **Coming Soon** (onboarding text only).
- Prize Room shelf (a full room of prizes) is still a later phase.

---

## Sign-off

| | Yes | Not yet |
|---|---|---|
| Turns went back and forth all game | | |
| Clues were never repeated | | |
| Guy's voice was clear throughout | | |
| Music sat under the show and kept playing | | |
| My name showed on my seat | | |
| I played a complete game | | |
| I am willing to release the Testing / Bug Fixes & Store Submission milestone | | |

**Name:** _________________ **Date:** _________________

If anything failed, the screen name + a screenshot is the most helpful next step.
