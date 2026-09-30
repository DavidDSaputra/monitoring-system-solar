<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

function fcm_base64url(string $value): string
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function fcm_service_account(): array
{
    $path = trim((string) api_env('FIREBASE_SERVICE_ACCOUNT_FILE', ''));
    if ($path === '' || !is_file($path)) {
        throw new RuntimeException('FIREBASE_SERVICE_ACCOUNT_FILE is missing or unreadable');
    }

    $decoded = json_decode((string) file_get_contents($path), true);
    if (!is_array($decoded)) {
        throw new RuntimeException('Firebase service-account JSON is invalid');
    }

    foreach (['project_id', 'client_email', 'private_key'] as $requiredKey) {
        if (trim((string) ($decoded[$requiredKey] ?? '')) === '') {
            throw new RuntimeException("Firebase service account is missing {$requiredKey}");
        }
    }

    return $decoded;
}

function fcm_access_token(): string
{
    $cached = api_cache_get('firebase:oauth-token:v1', 3300);
    if (is_array($cached) && !empty($cached['accessToken'])) {
        return (string) $cached['accessToken'];
    }

    $account = fcm_service_account();
    $now = time();
    $header = fcm_base64url(json_encode([
        'alg' => 'RS256',
        'typ' => 'JWT',
    ], JSON_UNESCAPED_SLASHES));
    $claims = fcm_base64url(json_encode([
        'iss' => $account['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => $account['token_uri'] ?? 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    ], JSON_UNESCAPED_SLASHES));
    $unsignedJwt = $header . '.' . $claims;

    $signature = '';
    if (!openssl_sign($unsignedJwt, $signature, (string) $account['private_key'], OPENSSL_ALGO_SHA256)) {
        throw new RuntimeException('Unable to sign Firebase OAuth request');
    }
    $assertion = $unsignedJwt . '.' . fcm_base64url($signature);

    $curl = curl_init((string) ($account['token_uri'] ?? 'https://oauth2.googleapis.com/token'));
    curl_setopt_array($curl, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
        CURLOPT_POSTFIELDS => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $assertion,
        ]),
    ]);
    $response = curl_exec($curl);
    $statusCode = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
    $curlError = curl_error($curl);
    curl_close($curl);

    $payload = json_decode(is_string($response) ? $response : '', true);
    if ($statusCode !== 200 || !is_array($payload) || empty($payload['access_token'])) {
        throw new RuntimeException('Firebase OAuth failed: ' . ($curlError !== '' ? $curlError : (string) $response));
    }

    $token = (string) $payload['access_token'];
    api_cache_put('firebase:oauth-token:v1', ['accessToken' => $token]);
    return $token;
}

function fcm_send_topic(
    string $title,
    string $body,
    array $data = [],
    ?string $topic = null
): array {
    $account = fcm_service_account();
    $projectId = trim((string) api_env('FIREBASE_PROJECT_ID', (string) $account['project_id']));
    $targetTopic = trim($topic ?? (string) api_env('FIREBASE_PUSH_TOPIC', 'solarview-alerts'));
    if ($projectId === '' || $targetTopic === '') {
        throw new RuntimeException('Firebase project ID or push topic is missing');
    }
    if (!preg_match('/^[a-zA-Z0-9\-_.~%]+$/', $targetTopic)) {
        throw new RuntimeException('Firebase push topic contains unsupported characters');
    }

    $stringData = [];
    foreach ($data as $key => $value) {
        $stringData[(string) $key] = is_scalar($value)
            ? (string) $value
            : json_encode($value, JSON_UNESCAPED_SLASHES);
    }
    $stringData['title'] = $title;
    $stringData['body'] = $body;

    $request = [
        'message' => [
            'topic' => $targetTopic,
            'notification' => [
                'title' => $title,
                'body' => $body,
            ],
            'data' => $stringData,
            'android' => [
                'priority' => 'high',
                'notification' => [
                    'channel_id' => 'solar_alerts',
                    'sound' => 'default',
                ],
            ],
            'apns' => [
                'payload' => [
                    'aps' => [
                        'sound' => 'default',
                        'content-available' => 1,
                    ],
                ],
            ],
        ],
    ];

    $url = 'https://fcm.googleapis.com/v1/projects/' . rawurlencode($projectId) . '/messages:send';
    $curl = curl_init($url);
    curl_setopt_array($curl, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . fcm_access_token(),
            'Content-Type: application/json; charset=UTF-8',
        ],
        CURLOPT_POSTFIELDS => json_encode($request, JSON_UNESCAPED_SLASHES),
    ]);
    $response = curl_exec($curl);
    $statusCode = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
    $curlError = curl_error($curl);
    curl_close($curl);

    $payload = json_decode(is_string($response) ? $response : '', true);
    if ($statusCode < 200 || $statusCode >= 300) {
        throw new RuntimeException('FCM send failed: ' . ($curlError !== '' ? $curlError : (string) $response));
    }

    return is_array($payload) ? $payload : ['raw' => $response];
}

function push_require_cron_secret(): void
{
    if (PHP_SAPI === 'cli') {
        return;
    }

    $expected = trim((string) api_env('PUSH_CRON_SECRET', ''));
    $provided = trim((string) (
        $_SERVER['HTTP_X_PUSH_SECRET']
        ?? $_GET['secret']
        ?? ''
    ));
    if ($expected === '' || $provided === '' || !hash_equals($expected, $provided)) {
        api_fail(401, 'Invalid push cron secret');
    }
}
