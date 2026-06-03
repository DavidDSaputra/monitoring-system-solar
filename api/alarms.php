<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';

$cacheKey = 'app:alarms:v1';
$cached = api_cache_get($cacheKey, 30);
if ($cached !== null) {
    $cached['cached'] = true;
    $cached['stale'] = false;
    api_json($cached);
}

$stale = api_cache_get_stale($cacheKey, 86400);
if ($stale !== null) {
    api_run_background_php(__DIR__ . '/warm_cache.php', ['all']);
    $stale['cached'] = true;
    $stale['stale'] = true;
    api_json($stale);
}

$alarms = monitoring_provider()->alarms();
$payload = [
    'success' => true,
    'provider' => 'solis',
    'cached' => (bool) ($alarms['cached'] ?? false),
    'stale' => false,
    'data' => [
        'records' => $alarms['records'] ?? [],
        'total' => $alarms['total'] ?? count($alarms['records'] ?? []),
    ],
];

api_cache_put($cacheKey, $payload);
api_json($payload);
