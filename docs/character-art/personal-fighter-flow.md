# Personal fighter: what we do with a real user, and what we tell them

Goal: a player films or photographs themselves, picks preferences, and gets **their own fighter** for online and offline play.
This flow is the product's core promise and its biggest legal and safety surface. Nothing ships until the "Blocking for
launch" list is satisfied.

## 1. The flow (what exactly happens)

| Step | What the user does | What we do | Output |
|---|---|---|---|
| 1. Consent | reads and accepts a plain-language notice | store consent version and timestamp | consent record |
| 2. Capture | takes 1 front selfie + 1 side selfie in the app (live camera, guided frame), optionally a short head-turn video | liveness check (blink/turn head), quality check (light, sharpness, one face only) | verified capture |
| 3. Look preferences | picks body build, outfit style, colours, hair/beard adjustments, accessory, name, optional taunt | map choices to a `{CHARACTER DESCRIPTION}` | character brief |
| 4. Stats | spends a **fixed point budget** (power, speed, defence, reach, special) and picks an archetype | validate the budget server side (same total for everyone) | fighter data (JSON) |
| 5. Generate | waits ~1-3 min | server runs the image pipeline (`prompts.md` workflow B) from the captures + brief, in a stylised game look (not a photo) | character reference, 12 poses, portrait |
| 6. Auto QA | nothing | checks from `README.md` acceptance list plus the engine sprite tests; moderation; likeness-to-user check | pass or retry |
| 7. Preview | sees all 12 poses and a short demo clip, can ask for 2 re-rolls or tweak preferences | | approved fighter |
| 8. Fight | plays online and offline | bundle is cached on the device; stats come from the signed fighter data | |
| 9. Delete | can delete the fighter and all source photos any time | hard delete from storage and backups on schedule | |

Rules that keep it fair: appearance never changes power; power is the same total budget for everybody; archetype defines the
move set; the server, not the client, owns the stats.

## 2. What we tell the user (copy, Hebrew first)

**Screen: "הדמות שלך"**

> אנחנו יוצרים לוחם אישי שנראה כמוך. צלם/י סלפי חי, בחר/י סגנון וכוחות, ובתוך דקות תקבל/י דמות משחק מסוגננת שנלחמת בשמך ברחבי העולם.
>
> מה קורה עם התמונות שלך:
> - התמונות משמשות רק ליצירת הדמות שלך ולא לשום דבר אחר.
> - אנחנו מוחקים את תמונות המקור מהשרת מיד אחרי שהדמות אושרה (עד 24 שעות). נשמרת רק הדמות המסוגננת.
> - איננו משתמשים בתמונות או בדמות לאימון מודלים, ואיננו מוכרים אותן.
> - אפשר למחוק את הדמות ואת כל הנתונים בכל רגע במסך "פרטיות".
> - מותר לצלם רק את עצמך. לא מצלמים אדם אחר, פוליטיקאי או דמות ציבורית. מערכת הבדיקה מאמתת שהפנים חיות ושייכות למצלם.
> - כל הדמויות הן בדיוניות וסאטיריות, והכוח במשחק אינו תלוי במראה.
>
> [ ] קראתי ואני מסכים/ה (גיל 16 ומעלה, או באישור הורה)   [המשך]

**English (same content)**

> We build a personal fighter that looks like you. Take a live selfie, pick a style and strengths, and in a few minutes you get a stylised game character that fights under your name worldwide.
>
> What happens to your photos: used only to create your character; the source photos are deleted right after you approve the character (within 24 hours) and only the stylised character is kept; never used to train models and never sold; you can delete your character and all data any time in Privacy; you may only capture yourself, never another person, a politician or a public figure, and a liveness check confirms the face is live and yours; all characters are fictional and satirical, and power never depends on looks.
>
> [ ] I have read and agree (16+ or with parent consent)   [Continue]

**Short labels and errors**

| Moment | Hebrew | English |
|---|---|---|
| Camera hint | "מרכזו את הפנים, אור טוב מלפנים" | "Centre your face, good light from the front" |
| Liveness | "סובב/י את הראש לאט שמאלה ואז ימינה" | "Turn your head slowly left, then right" |
| Not you | "לא הצלחנו לאמת שזה אתה. נסה/י שוב בלי משקפי שמש" | "We could not verify it is you. Try again without sunglasses" |
| Another person | "אפשר ליצור רק דמות של עצמך" | "You can only create a fighter of yourself" |
| Generating | "הלוחם שלך עולה לזירה..." | "Your fighter is entering the ring..." |
| Delete | "מחיקה סופית של הדמות והתמונות" | "Permanently delete your fighter and photos" |

## 3. Blocking for launch (safety and legal)

1. **Biometric and personal data.** A face image is sensitive in many jurisdictions (GDPR, UK GDPR, Israeli privacy law, Illinois BIPA, children's laws). Needs a lawful basis (explicit consent), data-minimisation, retention limits, a privacy policy, a deletion path, and data-processing agreements with every image-AI vendor. Prefer a vendor/contract that does not train on inputs.
2. **Only your own face.** Liveness plus face-match between live capture and uploaded images; reject photos of screens/print, celebrities and politicians (block-list via face recognition on public figures), and a report button.
3. **Minors.** Age gate; under 16 (or local age) requires parental consent; no selfie flow below the legal minimum.
4. **Output moderation.** Automatic checks for nudity, hate symbols, violence beyond the fighter pose, copyrighted characters/logos; human review for reports.
5. **Likeness rights.** The character is the user's own likeness with the user's consent; users cannot request "looks like [celebrity]". Never take real photos of third parties.
6. **Store rules.** Apple/Google require disclosure of data collection, a privacy policy and in-app account deletion.
7. **Cost and abuse.** Rate limit generations per user, re-rolls capped, server-side budget validation.

## 4. Engine requirements this flow creates (tracked in the plan)

- Fighter = data (stats + archetype + art bundle id), not code.
- Server-signed stat blocks; clients cannot edit power.
- Art bundles downloaded on demand and cached for offline play.
- The 12-frame contract stays the interface; the generator must pass the sprite tests before a fighter is activated.
