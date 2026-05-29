<?php
declare(strict_types=1);

require_once __DIR__ . '/_helpers.php';

$cacheKey = 'app:normalized:overview:v1';
$cached = api_cache_get($cacheKey, 20);
if ($cached !== null) {
    $cached['cached'] = true;
    $cached['stale'] = false;
    api_json($cached);
}

$stale = api_cache_get_stale($cacheKey, 86400);
if ($stale !== null) {
    api_run_background_php(dirname(__DIR__) . '/warm_cache.php', ['overview']);
    $stale['cached'] = true;
    $stale['stale'] = true;
    api_json($stale);
}

$provider = monitoring_provider();
$overview = $provider->overview();

$payload = [
    'success' => true,
    'provider' => $provider->id(),
    'normalized' => true,
    'cached' => false,
    'stale' => false,
    'data' => [
        'plants' => [
            'records' => normalize_records($overview['plants']['records'] ?? [], 'normalize_plant'),
            'total' => $overview['plants']['total'] ?? count($overview['plants']['records'] ?? []),
        ],
        'inverters' => [
            'records' => normalize_records($overview['inverters']['records'] ?? [], 'normalize_inverter'),
            'total' => $overview['inverters']['total'] ?? count($overview['inverters']['records'] ?? []),
        ],
        'batteries' => [
            'records' => normalize_records($overview['batteries']['records'] ?? [], 'normalize_battery'),
            'total' => $overview['batteries']['total'] ?? count($overview['batteries']['records'] ?? []),
        ],
        'collectors' => [
            'records' => normalize_records($overview['collectors']['records'] ?? [], 'normalize_collector'),
            'total' => $overview['collectors']['total'] ?? count($overview['collectors']['records'] ?? []),
        ],
    ],
];

api_cache_put($cacheKey, $payload);
api_json($payload);
