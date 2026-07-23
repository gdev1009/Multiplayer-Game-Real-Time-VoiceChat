# Store policy pages (host on grandmamac.com)

Static HTML for App Store Connect and Google Play Console.

## Files

| File | Store field |
|------|-------------|
| `privacy-policy.html` | Privacy Policy URL (**required**) |
| `terms-of-service.html` | Terms / EULA (recommended) |
| `support.html` | Support URL (**required**) |
| `security.html` | Optional link from privacy page |

## Example live URLs

After uploading this folder to `https://grandmamac.com/matchword/`:

- https://grandmamac.com/matchword/privacy-policy.html
- https://grandmamac.com/matchword/terms-of-service.html
- https://grandmamac.com/matchword/support.html
- https://grandmamac.com/matchword/security.html

**Support email:** support@grandmamac.com

## Deploy

1. Upload all `.html` files to your web host (FTP, cPanel, Netlify, GitHub Pages, etc.).
2. Confirm each URL loads over HTTPS.
3. Paste URLs into App Store Connect and Google Play Console.

See [App Store Publishing.md](../App%20Store%20Publishing.md) for the full checklist.
