<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

function solis_credentials(): array
{
    $keyId = api_env('SOLIS_API_KEY') ?: api_env('SOLIS_KEY_ID') ?: '';
    $keySecret = api_env('SOLIS_API_SECRET') ?: api_env('SOLIS_KEY_SECRET') ?: '';
    $baseUrl = api_env('SOLIS_API_URL', 'https://www.soliscloud.com:13333') ?: 'https://www.soliscloud.com:13333';

    if ($keyId === '' || $keySecret === '') {
        api_fail(500, 'Solis API credentials are missing on the server');
    }

    return [$keyId, $keySecret, rtrim($baseUrl, '/')];
}

function solis_request(
    string $endpoint,
    array $body,
    int $ttlSeconds = 15,
    bool $forceRefresh = false
): array
{
    $cacheKey = 'solis:' . $endpoint . ':' . json_encode($body, JSON_UNESCAPED_SLASHES);
    $cached = $forceRefresh ? null : api_cache_get($cacheKey, $ttlSeconds);
    if ($cached !== null) {
        $cached['cached'] = true;
        return $cached;
    }

    [$keyId, $keySecret, $baseUrl] = solis_credentials();
    $bodyJson = json_encode($body, JSON_UNESCAPED_SLASHES);
    if ($bodyJson === false) {
        api_fail(400, 'Unable to encode Solis request body');
    }

    $contentType = 'application/json';
    $contentMd5 = base64_encode(md5($bodyJson, true));
    $date = gmdate('D, d M Y H:i:s \G\M\T');
    $signString = "POST\n{$contentMd5}\n{$contentType}\n{$date}\n{$endpoint}";
    $signature = base64_encode(hash_hmac('sha1', $signString, $keySecret, true));

    $ch = curl_init($baseUrl . $endpoint);
    if ($ch === false) {
        api_fail(500, 'Unable to initialize Solis request');
    }

    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POSTFIELDS => $bodyJson,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_HTTPHEADER => [
            "Content-Type: {$contentType}",
            "Content-MD5: {$contentMd5}",
            "Date: {$date}",
            "Authorization: API {$keyId}:{$signature}",
        ],
    ]);

    $responseBody = curl_exec($ch);
    $curlError = curl_error($ch);
    $statusCode = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);

    if ($responseBody === false) {
        api_fail(502, "Solis request failed: {$curlError}");
    }

    $payload = json_decode($responseBody, true);
    if (!is_array($payload)) {
        api_fail(502, 'Solis returned invalid JSON', ['statusCode' => $statusCode]);
    }

    if ($statusCode !== 200) {
        api_json($payload, $statusCode > 0 ? $statusCode : 502);
    }

    if (($payload['success'] ?? false) !== true && ($payload['code'] ?? null) !== '0') {
        api_json($payload, 502);
    }

    $payload['cached'] = false;
    api_cache_put($cacheKey, $payload);
    return $payload;
}

function solis_extract_records(mixed $data): array
{
    if ($data === null) {
        return [];
    }

    if (is_array($data) && array_is_list($data)) {
        return $data;
    }

    if (!is_array($data)) {
        return [];
    }

    if (isset($data['page']) && is_array($data['page'])) {
        foreach (['records', 'data', 'list'] as $key) {
            if (isset($data['page'][$key]) && is_array($data['page'][$key])) {
                return $data['page'][$key];
            }
        }
    }

    foreach (['records', 'data', 'list', 'rows', 'inverterStatusVo', 'stationStatusVo'] as $key) {
        if (isset($data[$key]) && is_array($data[$key])) {
            return $data[$key];
        }
    }

    return [];
}

function solis_extract_total(mixed $data): int
{
    if (!is_array($data)) {
        return 0;
    }

    if (isset($data['page']) && is_array($data['page']) && isset($data['page']['total'])) {
        return (int) $data['page']['total'];
    }

    return isset($data['total']) ? (int) $data['total'] : 0;
}

function solis_all_records(
    string $endpoint,
    array $body = [],
    int $ttlSeconds = 20,
    int $pageSize = 100,
    bool $forceRefresh = false
): array
{
    $firstBody = array_merge($body, ['pageNo' => 1, 'pageSize' => $pageSize]);
    $first = solis_request($endpoint, $firstBody, $ttlSeconds, $forceRefresh);
    $data = $first['data'] ?? null;
    $records = solis_extract_records($data);
    $total = solis_extract_total($data);
    $pages = $total > $pageSize ? (int) ceil($total / $pageSize) : 1;

    for ($page = 2; $page <= $pages; $page++) {
        $result = solis_request(
            $endpoint,
            array_merge($body, ['pageNo' => $page, 'pageSize' => $pageSize]),
            $ttlSeconds,
            $forceRefresh
        );
        $records = array_merge($records, solis_extract_records($result['data'] ?? null));
    }

    return [
        'records' => $records,
        'total' => $total > 0 ? $total : count($records),
        'cached' => (bool) ($first['cached'] ?? false),
    ];
}

function solis_list_response(array $result): never
{
    api_json([
        'success' => true,
        'provider' => 'solis',
        'cached' => $result['cached'] ?? false,
        'data' => [
            'records' => $result['records'] ?? [],
            'total' => $result['total'] ?? count($result['records'] ?? []),
        ],
    ]);
}

function solis_detail_response(array $payload): never
{
    api_json([
        'success' => true,
        'provider' => 'solis',
        'cached' => $payload['cached'] ?? false,
        'data' => $payload['data'] ?? new stdClass(),
    ]);
}
