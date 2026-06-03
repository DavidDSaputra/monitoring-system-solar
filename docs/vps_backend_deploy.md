# Jarwinn Monitoring Backend VPS Package

Upload the contents of this package to the web root or subfolder that will serve the API, for example:

- `public_html/jarwinn-monitoring/`
- `/var/www/jarwinn-monitoring/`

This package also works on cPanel/shared hosting such as Dewaweb as long as PHP cURL and Cron Jobs are available.

## Requirements

- PHP 8.1 or newer
- PHP extensions: `curl`, `json`, `openssl`
- Apache with `mod_rewrite` enabled, or Nginx rules that route to the same PHP files
- HTTPS domain for production mobile apps

## Setup

1. Copy `.env.example` to `.env` on the server.
2. Fill provider credentials in `.env`.
3. Keep `.env` outside public access when possible. If you must keep it in the uploaded package folder, the included root `.htaccess` blocks direct access to `.env`.
4. Make `api/cache` writable by PHP.
5. Test:

```bash
curl https://your-domain.com/jarwinn-monitoring/api/health.php
curl https://your-domain.com/jarwinn-monitoring/api/monitoring/plants.php?source=all
```

## Warm Cache

Run this periodically from cron so the first mobile user does not wait for slow provider APIs:

```bash
php /path/to/jarwinn-monitoring/api/warm_cache.php all
```

Recommended cron:

```cron
*/2 * * * * php /path/to/jarwinn-monitoring/api/warm_cache.php all >/dev/null 2>&1
```

On cPanel shared hosting, use Cron Jobs and adjust the PHP binary/path to your hosting account, for example:

```bash
/usr/local/bin/php /home/CPANEL_USER/public_html/jarwinn-monitoring/api/warm_cache.php all >/dev/null 2>&1
```

If direct PHP CLI is restricted, use curl:

```bash
/usr/bin/curl -s "https://your-domain.com/jarwinn-monitoring/api/warm_cache.php?target=all" >/dev/null 2>&1
```

## Mobile App

After the backend is online, set the Flutter app base URL to your public API:

```env
MONITORING_API_BASE_URLS=https://your-domain.com/jarwinn-monitoring/api
MONITORING_API_MOBILE_LOCAL_FIRST=false
```

Then build the APK again.
