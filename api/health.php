<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/bootstrap.php';

$providers = [
    'solis' => provider_health('solis', [
        'configured' => api_env('SOLIS_API_KEY', '') !== '' && api_env('SOLIS_API_SECRET', '') !== '',
        'cacheKeys' => [
            'overview' => 'app:overview:v1',
            'plants' => 'app:plants:v1',
            'alarms' => 'app:alarms:v1',
            'normalizedPlants' => 'monitoring:plants:solis',
        ],
    ]),
    'huawei' => provider_health('huawei', [
        'configured' => api_env('HUAWEI_BASE_URL', '') !== ''
            && api_env('HUAWEI_USERNAME', '') !== ''
            && api_env('HUAWEI_SYSTEM_CODE', '') !== '',
        'cacheKeys' => [
            'session' => 'huawei:session',
            'stations' => 'huawei:stations',
            'plants' => 'huawei:normalized-plants',
        ],
    ]),
    'growatt' => provider_health('growatt', [
        'configured' => api_env('GROWATT_API_TOKEN', '') !== '',
        'cacheKeys' => [
            'plantsFast' => 'growatt:normalized-plants:fast',
            'plantsHydrated' => 'growatt:normalized-plants:hydrated',
        ],
    ]),
];

$overall = 'ok';
foreach ($providers as $provider) {
    if (($provider['status'] ?? 'unknown') === 'down') {
        $overall = 'degraded';
        break;
    }
    if (($provider['status'] ?? 'unknown') !== 'ok') {
        $overall = 'degraded';
    }
}

api_json([
    'success' => true,
    'status' => $overall,
    'serverTime' => gmdate(DATE_ATOM),
    'environment' => [
        'php' => PHP_VERSION,
        'host' => $_SERVER['HTTP_HOST'] ?? '',
        'https' => (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off'),
    ],
    'providers' => $providers,
]);

function provider_health(string $name, array $options): array
{
    $configured = (bool) ($options['configured'] ?? false);
    $cache = [];
    $freshCount = 0;
    $staleCount = 0;

    foreach (($options['cacheKeys'] ?? []) as $label => $key) {
        $meta = api_cache_meta((string) $key);
        $exists = (bool) ($meta['exists'] ?? false);
        $age = $meta['ageSeconds'];
        $fresh = $exists && is_int($age) && $age <= 300;
        $stale = $exists && !$fresh;
        if ($fresh) {
            $freshCount++;
        } elseif ($stale) {
            $staleCount++;
        }

        $cache[$label] = [
            'exists' => $exists,
            'fresh' => $fresh,
            'stale' => $stale,
            'ageSeconds' => $age,
            'createdAt' => $meta['createdAt'],
        ];
    }

    $status = 'down';
    if ($configured && $freshCount > 0) {
        $status = 'ok';
    } elseif ($configured && $staleCount > 0) {
        $status = 'stale';
    } elseif ($configured) {
        $status = 'warming';
    }

    return [
        'source' => $name,
        'configured' => $configured,
        'status' => $status,
        'cache' => $cache,
    ];
}
