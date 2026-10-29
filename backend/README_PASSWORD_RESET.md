# Password reset and account email configuration

1. Copy `.env.example` to `.env` in the `backend` directory if you do not already have a working `.env`.
2. Keep your existing `DATABASE_URL`, `JWT_SECRET`, and weather API key values. Do not replace them with the example placeholders.
3. Configure SMTP using `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_USERNAME`, `EMAIL_PASSWORD`, `EMAIL_FROM`, and `EMAIL_USE_TLS`. For Gmail, use `smtp.gmail.com`, port `587`, TLS enabled, and a Google App Password (not your regular Google password). Keep credentials only in `.env`.
4. Set `PASSWORD_RESET_URL` to the root URL of the Flutter Web app that farmers can open from their email, for example `http://localhost:52831/` for a local run. The actual port can change; update this setting and restart FastAPI when it does. The reset token is placed after `#token=` in the URL fragment so it is not sent to the web server in the HTTP request.
5. Set `PASSWORD_RESET_EXPIRE_MINUTES` (default 30). The reset token is single-use; only its SHA-256 hash is stored.
6. Restart FastAPI after editing `.env`. Never commit `.env`; `.gitignore` excludes it.

New registrations now require an email address and a strong password. Existing users are preserved, but their new `email` column will be NULL until you populate it. Those accounts must have a verified email address added to the existing PostgreSQL `users` row before they can use password reset. Do not guess or assign email addresses on their behalf.

The backend uses bcrypt for password hashes and the existing in-memory login throttle. The throttle is per process; for multi-worker/production deployments, use a shared rate limiter (for example Redis or a reverse proxy).
