<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';
require_once __DIR__ . '/providers/solis/normalizer.php';

$cacheKey = 'app:plants:v1';
$forceRefresh = filter_var($_GET['refresh'] ?? $_GET['forceRefresh'] ?? false, FILTER_VALIDATE_BOOLEAN);
$pageNo = max(1, (int) ($_GET['pageNo'] ?? 0));
$pageSize = max(0, min(100, (int) ($_GET['pageSize'] ?? 0)));

if ($forceRefresh) {
    try {
        $plants = monitoring_provider()->plants(true);
        $payload = solis_plants_payload($plants, false, false);
        api_cache_put($cacheKey, $payload);
        api_cache_put('monitoring:plants:solis', [
            'success' => true,
            'source' => 'solis',
            'data' => normalize_records($plants['records'] ?? [], 'normalize_plant'),
        ]);
        api_json(solis_paginated_plants_payload($payload, $pageNo, $pageSize));
    } catch (Throwable $e) {
        $stale = api_cache_get_stale($cacheKey, 86400);
        if ($stale !== null) {
            $stale['cached'] = true;
            $stale['stale'] = true;
            $stale['refreshError'] = $e->getMessage();
            api_json(solis_paginated_plants_payload($stale, $pageNo, $pageSize));
        }

        api_fail(503, 'Solis plants unavailable', [
            'detail' => $e->getMessage(),
        ]);
    }
}

$cached = api_cache_get($cacheKey, 20);
if ($cached !== null) {
    $cached['cached'] = true;
    $cached['stale'] = false;
    api_json(solis_paginated_plants_payload($cached, $pageNo, $pageSize));
}

$stale = api_cache_get_stale($cacheKey, 86400);
if ($stale !== null) {
    api_run_background_php(__DIR__ . '/warm_cache.php', ['solis-plants']);
    $stale['cached'] = true;
    $stale['stale'] = true;
    api_json(solis_paginated_plants_payload($stale, $pageNo, $pageSize));
}

$overview = api_cache_get('app:overview:v1', 86400);
if (is_array($overview)) {
    $plants = $overview['data']['plants'] ?? null;
    if (is_array($plants)) {
        $payload = solis_plants_payload($plants, true, true);
        api_cache_put($cacheKey, $payload);
        api_run_background_php(__DIR__ . '/warm_cache.php', ['solis-plants']);
        api_json(solis_paginated_plants_payload($payload, $pageNo, $pageSize));
    }
}

$plants = monitoring_provider()->plants();
$payload = solis_plants_payload($plants, (bool) ($plants['cached'] ?? false), false);
api_cache_put($cacheKey, $payload);
api_cache_put('monitoring:plants:solis', [
    'success' => true,
    'source' => 'solis',
    'data' => normalize_records($plants['records'] ?? [], 'normalize_plant'),
]);
api_json(solis_paginated_plants_payload($payload, $pageNo, $pageSize));

function solis_plants_payload(array $plants, bool $cached, bool $stale): array
{
    return [
        'success' => true,
        'provider' => 'solis',
        'cached' => $cached,
        'stale' => $stale,
        'data' => [
            'records' => $plants['records'] ?? [],
            'total' => $plants['total'] ?? count($plants['records'] ?? []),
        ],
    ];
}

function solis_paginated_plants_payload(array $payload, int $pageNo, int $pageSize): array
{
    if ($pageSize <= 0) {
        return $payload;
    }

    $records = $payload['data']['records'] ?? [];
    if (!is_array($records)) {
        $records = [];
    }

    $total = count($records);
    $offset = max(0, ($pageNo - 1) * $pageSize);
    $payload['data']['records'] = array_slice($records, $offset, $pageSize);
    $payload['data']['total'] = (int) ($payload['data']['total'] ?? $total);
    $payload['data']['pageNo'] = $pageNo;
    $payload['data']['pageSize'] = $pageSize;

    return $payload;
}
