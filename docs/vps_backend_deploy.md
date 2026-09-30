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
2. Set a new, strong `APP_LOGIN_USERNAME` and `APP_LOGIN_PASSWORD`. Do not reuse the old password from the Flutter source history.
3. Fill provider credentials in `.env`.
4. Keep `.env` outside public access when possible. If you must keep it in the uploaded package folder, the included root `.htaccess` blocks direct access to `.env`.
5. Make `api/cache` writable by PHP.
6. Test:

```bash
curl https://api.solisinverters.co.id/api/health.php
curl -i -X POST https://api.solisinverters.co.id/api/auth/login.php -H "Content-Type: application/json" --data '{"username":"YOUR_USERNAME","password":"YOUR_PASSWORD"}'
curl https://api.solisinverters.co.id/api/monitoring/plants.php?source=all
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

## Push Notification

SolarView uses Firebase Cloud Messaging HTTP v1. Create an Android app in
Firebase with package name `com.example.jarwinn_monitoring`, then download a
service-account key from Firebase Project Settings > Service accounts. Keep the
JSON key outside the public web root and configure these values in `.env`:

```env
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_SERVICE_ACCOUNT_FILE=/secure/path/firebase-service-account.json
FIREBASE_PUSH_TOPIC=solarview-alerts
PUSH_CRON_SECRET=replace-with-a-long-random-secret
INCIDENT_STORE_FILE=/var/lib/solarview/incidents.json
```

Create the incident store outside the public web root and allow the PHP group to
read it. The push checker records plant, inverter, battery, and datalogger
transitions here, including priority, SLA deadline, recovery time, and downtime.

```bash
sudo install -d -m 2770 -o root -g www-data /var/lib/solarview
echo '{"incidents":[],"updatedAt":null}' | sudo tee /var/lib/solarview/incidents.json >/dev/null
sudo chown root:www-data /var/lib/solarview/incidents.json
sudo chmod 660 /var/lib/solarview/incidents.json
```

Run the status checker one minute after the provider-cache schedule. Keeping the
jobs separate also allows the checker to use the last good cache if a provider
refresh is temporarily slow:

```cron
*/2 * * * * /usr/bin/php /path/to/jarwinn-monitoring/api/warm_cache.php all >/dev/null 2>&1
1-59/2 * * * * /usr/bin/php /path/to/jarwinn-monitoring/api/notifications/check_alerts.php >/dev/null 2>&1
```

The first run creates a status baseline and does not send a false alarm. Later
transitions to offline/alarm/fault send a notification, and recovery to online
sends a recovery notification. An `unknown` status must occur twice after a
known-online state before it is treated as offline.

Send a protected test message:

```bash
curl -X POST "https://api.solisinverters.co.id/api/notifications/test.php" \
  -H "Content-Type: application/json" \
  -H "X-Push-Secret: YOUR_PUSH_CRON_SECRET" \
  --data '{"title":"SolarView test","body":"Push notification aktif."}'
```

Build the Android app with the public Firebase client identifiers:

```bash
flutter build apk --release \
  --dart-define=MONITORING_API_BASE_URL=https://api.solisinverters.co.id/api \
  --dart-define=FIREBASE_PROJECT_ID=your-firebase-project-id \
  --dart-define=FIREBASE_API_KEY=your-android-api-key \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id \
  --dart-define=FIREBASE_ANDROID_APP_ID=your-android-app-id \
  --dart-define=FIREBASE_PUSH_TOPIC=solarview-alerts
```

On cPanel shared hosting, use Cron Jobs and adjust the PHP binary/path to your hosting account, for example:

```bash
/usr/local/bin/php /home/CPANEL_USER/public_html/jarwinn-monitoring/api/warm_cache.php all >/dev/null 2>&1
```

If direct PHP CLI is restricted, use curl:

```bash
/usr/bin/curl -s "https://api.solisinverters.co.id/api/warm_cache.php?target=all" >/dev/null 2>&1
```

## Mobile App

After the backend is online, set the Flutter app base URL to your public API:

```env
MONITORING_API_BASE_URLS=https://api.solisinverters.co.id/api
MONITORING_API_MOBILE_LOCAL_FIRST=false
```

Then build the APK again.
