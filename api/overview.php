<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';

$cacheKey = 'app:overview:v1';
$cached = api_cache_get($cacheKey, 20);
if ($cached !== null) {
    $cached['cached'] = true;
    $cached['stale'] = false;
    api_json($cached);
}

$stale = api_cache_get_stale($cacheKey, 86400);
if ($stale !== null) {
    $lock = api_lock_acquire('overview-refresh', 120);
    if ($lock !== false) {
        api_lock_release($lock);
        api_run_background_php(__DIR__ . '/warm_cache.php', ['overview']);
    }

    $stale['cached'] = true;
    $stale['stale'] = true;
    api_json($stale);
}

$overview = monitoring_provider()->overview();

$payload = [
    'success' => true,
    'provider' => monitoring_provider()->id(),
    'cached' => false,
    'stale' => false,
    'data' => $overview,
];

api_cache_put($cacheKey, $payload);
api_json($payload);
