<?php
declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/lib/bootstrap.php';

function growatt_config(): array
{
    $baseUrl = rtrim((string) api_env('GROWATT_BASE_URL', 'https://openapi.growatt.com'), '/');
    $token = trim((string) api_env('GROWATT_API_TOKEN', ''));

    if ($baseUrl === '' || $token === '') {
        api_fail(500, 'Growatt credentials are missing on the server');
    }

    return [
        'apiUrl' => $baseUrl . '/v4',
        'token' => $token,
    ];
}

function growatt_request(
    string $method,
    string $path,
    array $params = [],
    array $data = [],
    int $ttlSeconds = 60,
    bool $forceRefresh = false
): array {
    $cacheKey = 'growatt:request:' . sha1(json_encode([
        strtoupper($method),
        $path,
        $params,
        $data,
    ], JSON_UNESCAPED_SLASHES) ?: '');

    if (!$forceRefresh) {
        $cached = api_cache_get($cacheKey, $ttlSeconds);
        if ($cached !== null) {
            $cached['cached'] = true;
            return $cached;
        }
    }

    $response = growatt_send_request($method, $path, $params, $data);
    $body = $response['body'];
    if (!is_array($body)) {
        $stale = api_cache_get_stale($cacheKey, 86400);
        if ($stale !== null) {
            $stale['cached'] = true;
            $stale['stale'] = true;
            return $stale;
        }
        api_fail(502, 'Growatt API returned invalid JSON');
    }

    if (!growatt_response_successful($body)) {
        $stale = api_cache_get_stale($cacheKey, 86400);
        if ($stale !== null && growatt_is_rate_limited($body)) {
            $stale['cached'] = true;
            $stale['stale'] = true;
            return $stale;
        }

        api_fail(502, 'Growatt API returned an error', [
            'code' => $body['code'] ?? $body['error_code'] ?? null,
            'message' => $body['message'] ?? $body['error_msg'] ?? null,
        ]);
    }

    $payload = [
        'body' => $body,
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

function growatt_send_request(string $method, string $path, array $params, array $data): array
{
    $config = growatt_config();
    $method = strtoupper($method);
    $path = ltrim($path, '/');
    $url = $config['apiUrl'] . '/' . $path;
    if (count($params) > 0) {
        $url .= '?' . http_build_query(growatt_filter_params($params));
    }

    $headers = [
        'Accept: application/json',
        'token: ' . $config['token'],
    ];

    $ch = curl_init($url);
    $options = [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 35,
        CURLOPT_HTTPHEADER => $headers,
    ];

    if ($method === 'POST') {
        $body = http_build_query(growatt_filter_params($data));
        $options[CURLOPT_POST] = true;
        $options[CURLOPT_POSTFIELDS] = $body;
        $headers[] = 'Content-Type: application/x-www-form-urlencoded';
        $options[CURLOPT_HTTPHEADER] = $headers;
    }

    curl_setopt_array($ch, $options);
    $responseBody = curl_exec($ch);
    $curlError = curl_error($ch);
    $statusCode = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);

    if ($responseBody === false) {
        api_fail(502, "Growatt request failed: {$curlError}");
    }

    if ($statusCode < 200 || $statusCode >= 300) {
        $stale = api_cache_get_stale('growatt:http:' . sha1($url), 86400);
        if ($stale !== null) {
            $stale['cached'] = true;
            $stale['stale'] = true;
            return [
                'statusCode' => $statusCode,
                'body' => $stale,
            ];
        }
        api_fail($statusCode > 0 ? $statusCode : 502, 'Growatt API HTTP error');
    }

    return [
        'statusCode' => $statusCode,
        'body' => json_decode($responseBody, true),
    ];
}

function growatt_filter_params(array $params): array
{
    return array_filter($params, static fn (mixed $value): bool => $value !== null && $value !== '');
}

function growatt_response_successful(array $body): bool
{
    $code = $body['code'] ?? $body['error_code'] ?? 0;
    if (is_numeric($code)) {
        return (int) $code === 0;
    }

    return strtolower((string) $code) === '0' || strtolower((string) $code) === 'success';
}

function growatt_is_rate_limited(array $body): bool
{
    $code = (string) ($body['code'] ?? $body['error_code'] ?? '');
    $message = strtolower((string) ($body['message'] ?? $body['error_msg'] ?? ''));
    return in_array($code, ['102', '10012'], true) || str_contains($message, 'frequency') || str_contains($message, 'limit');
}

function growatt_data_from_response(array $response): mixed
{
    $body = $response['body'] ?? $response;
    return is_array($body) && array_key_exists('data', $body) ? $body['data'] : $body;
}
