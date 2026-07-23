# Auth email templates (OTP, not magic links)

Match Word’s app UI asks for a **6-digit code**. Supabase’s default **Magic Link**
template sends a clickable “Sign in” link instead — that is what you saw from
`noreply@mail.app.supabase.io`.

## Fix (2 minutes in the dashboard)

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project  
2. **Authentication → Email Templates → Magic Link**  
3. Set **Subject** to: `Your Match Word code`  
4. Replace the **Body** with the HTML in [`magic-link.html`](magic-link.html)  
   (must include `{{ .Token }}`, must **not** use `{{ .ConfirmationURL }}`)  
5. **Save**  
6. In the app: **Forgot My PIN** again → inbox should show a **6-digit number**

Optional: repeat the same `{{ .Token }}` body for any other templates you use
with `signInWithOtp` (they share this path).

## Production (Mailgun hook)

If **Authentication → Hooks → Send Email** points at `functions/send-email`,
Mailgun already formats the numeric code from `email_data.token`. Emails then
come from your Mailgun sender (e.g. `no-reply@mg.…`), not
`noreply@mail.app.supabase.io`.

Seeing `noreply@mail.app.supabase.io` means the hook is **off** or failing and
Supabase’s built-in mailer + Magic Link template are in use — so the template
change above is required.
