<?php
declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/lib/bootstrap.php';

function huawei_auth_config(): array
{
    $baseUrl = rtrim((string) api_env('HUAWEI_BASE_URL', 'https://intl.fusionsolar.huawei.com'), '/');
    $username = (string) api_env('HUAWEI_USERNAME', '');
    $systemCode = (string) api_env('HUAWEI_SYSTEM_CODE', '');

    if ($baseUrl === '' || $username === '' || $systemCode === '') {
        api_fail(500, 'Huawei FusionSolar credentials are missing on the server');
    }

    return [
        'baseUrl' => $baseUrl,
        'username' => $username,
        'systemCode' => $systemCode,
    ];
}

function huawei_login(): array
{
    $config = huawei_auth_config();
    $body = json_encode([
        'userName' => $config['username'],
        'systemCode' => $config['systemCode'],
    ], JSON_UNESCAPED_SLASHES);

    if ($body === false) {
        api_fail(500, 'Unable to encode Huawei login request');
    }

    $headers = [];
    $ch = curl_init($config['baseUrl'] . '/thirdData/login');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POSTFIELDS => $body,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_HEADERFUNCTION => static function ($curl, string $header) use (&$headers): int {
            $length = strlen($header);
            $parts = explode(':', $header, 2);
            if (count($parts) === 2) {
                $name = strtolower(trim($parts[0]));
                $value = trim($parts[1]);
                $headers[$name][] = $value;
            }
            return $length;
        },
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'Accept: application/json',
        ],
    ]);

    $responseBody = curl_exec($ch);
    $curlError = curl_error($ch);
    $statusCode = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);

    if ($responseBody === false) {
        api_fail(502, "Huawei login failed: {$curlError}");
    }

    $decoded = json_decode($responseBody, true);
    if (!is_array($decoded)) {
        api_fail(502, 'Huawei login returned invalid JSON', ['statusCode' => $statusCode]);
    }

    if ($statusCode < 200 || $statusCode >= 300) {
        api_fail($statusCode > 0 ? $statusCode : 502, 'Huawei login HTTP error');
    }

    $session = huawei_extract_session($decoded, $headers);
    if (($session['token'] ?? '') === '' && ($session['cookie'] ?? '') === '') {
        api_fail(502, 'Huawei login succeeded but no token/cookie was returned');
    }

    $session['createdAt'] = time();
    api_cache_put('huawei:session', $session);

    return $session;
}

function huawei_get_session(): array
{
    $cached = api_cache_get('huawei:session', 25 * 60);
    if ($cached !== null) {
        return $cached;
    }

    return huawei_login();
}

function huawei_refresh_session(): array
{
    return huawei_login();
}

function huawei_extract_session(array $body, array $headers): array
{
    $token = huawei_pick_token($body);
    foreach (['xsrf-token', 'x-xsrf-token', 'token', 'authorization'] as $headerName) {
        if ($token !== '') {
            break;
        }
        if (!empty($headers[$headerName][0])) {
            $token = $headers[$headerName][0];
        }
    }

    $cookieParts = [];
    foreach ($headers['set-cookie'] ?? [] as $cookie) {
        $cookieParts[] = explode(';', $cookie, 2)[0];
        if ($token === '' && stripos($cookie, 'XSRF-TOKEN=') !== false) {
            $token = urldecode((string) preg_replace('/^.*XSRF-TOKEN=([^;]+).*$/i', '$1', $cookie));
        }
    }

    return [
        'token' => $token,
        'cookie' => implode('; ', array_filter($cookieParts)),
        'rawLoginCode' => $body['code'] ?? $body['success'] ?? null,
    ];
}

function huawei_pick_token(array $body): string
{
    $candidates = [
        $body['token'] ?? null,
        $body['xsrfToken'] ?? null,
        $body['csrfToken'] ?? null,
        $body['data']['token'] ?? null,
        $body['data']['xsrfToken'] ?? null,
        $body['data']['csrfToken'] ?? null,
    ];

    foreach ($candidates as $candidate) {
        if (is_string($candidate) && trim($candidate) !== '') {
            return trim($candidate);
        }
    }

    return '';
}
