<?php
declare(strict_types=1);

require_once __DIR__ . '/huaweiAuthService.php';

function huawei_request(string $path, array $body = [], bool $retry = true): array
{
    $config = huawei_auth_config();
    $session = huawei_get_session();
    $result = huawei_send_request($config['baseUrl'] . $path, $body, $session);

    if ($retry && huawei_is_unauthorized($result)) {
        $session = huawei_refresh_session();
        $result = huawei_send_request($config['baseUrl'] . $path, $body, $session);
    }

    if ($result['statusCode'] < 200 || $result['statusCode'] >= 300) {
        throw new RuntimeException('Huawei API HTTP error: ' . ($result['statusCode'] ?: 502));
    }

    if (!is_array($result['body'])) {
        throw new RuntimeException('Huawei API returned invalid JSON');
    }

    if (($result['body']['success'] ?? true) === false) {
        $failCode = (string) ($result['body']['failCode'] ?? '');
        $message = (string) ($result['body']['message'] ?? $result['body']['data'] ?? 'Huawei API returned an error');
        throw new RuntimeException(trim("Huawei API error {$failCode}: {$message}"));
    }

    return $result['body'];
}

function huawei_send_request(string $url, array $body, array $session): array
{
    $bodyJson = json_encode($body, JSON_UNESCAPED_SLASHES);
    if ($bodyJson === false) {
        throw new RuntimeException('Unable to encode Huawei request body');
    }

    $headers = [
        'Content-Type: application/json',
        'Accept: application/json',
    ];

    if (($session['token'] ?? '') !== '') {
        $headers[] = 'XSRF-TOKEN: ' . $session['token'];
    }

    if (($session['cookie'] ?? '') !== '') {
        $headers[] = 'Cookie: ' . $session['cookie'];
    }

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POSTFIELDS => $bodyJson,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 35,
        CURLOPT_HTTPHEADER => $headers,
    ]);

    $responseBody = curl_exec($ch);
    $curlError = curl_error($ch);
    $statusCode = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);

    if ($responseBody === false) {
        throw new RuntimeException("Huawei request failed: {$curlError}");
    }

    return [
        'statusCode' => $statusCode,
        'body' => json_decode($responseBody, true),
    ];
}

function huawei_is_unauthorized(array $result): bool
{
    if (in_array((int) ($result['statusCode'] ?? 0), [401, 403], true)) {
        return true;
    }

    $body = $result['body'] ?? [];
    if (!is_array($body)) {
        return false;
    }

    $code = strtolower((string) ($body['code'] ?? $body['failCode'] ?? $body['errorCode'] ?? ''));
    $message = strtolower((string) ($body['message'] ?? $body['msg'] ?? $body['errorMsg'] ?? ''));

    return str_contains($code, '401') ||
        str_contains($code, '403') ||
        str_contains($message, 'session') ||
        str_contains($message, 'token') ||
        str_contains($message, 'unauthorized');
}

function huawei_records_from_response(array $response): array
{
    $data = $response['data'] ?? $response['result'] ?? $response;
    if (is_array($data) && array_is_list($data)) {
        return $data;
    }

    if (!is_array($data)) {
        return [];
    }

    foreach (['list', 'records', 'stationList', 'data', 'items'] as $key) {
        if (isset($data[$key]) && is_array($data[$key])) {
            return $data[$key];
        }
    }

    return [];
}

function huawei_total_from_response(array $response, int $fallback = 0): int
{
    $data = $response['data'] ?? $response['result'] ?? [];
    if (is_array($data)) {
        foreach (['total', 'totalCount', 'count'] as $key) {
            if (isset($data[$key]) && is_numeric($data[$key])) {
                return (int) $data[$key];
            }
        }
    }

    foreach (['total', 'totalCount', 'count'] as $key) {
        if (isset($response[$key]) && is_numeric($response[$key])) {
            return (int) $response[$key];
        }
    }

    return $fallback;
}
