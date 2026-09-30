<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

function monitoring_merge_device_snapshot(string $source, string $plantCode, array $devices): array
{
    $cacheKey = 'monitoring:devices:' . strtolower($source);
    $existing = api_cache_get_stale($cacheKey, 86400 * 30);
    $indexed = [];
    foreach (($existing['data'] ?? []) as $device) {
        if (!is_array($device)) continue;
        $id = trim((string) ($device['deviceId'] ?? $device['id'] ?? $device['deviceSn'] ?? ''));
        if ($id !== '') $indexed[$id] = $device;
    }

    foreach ($devices as $device) {
        if (!is_array($device)) continue;
        if (trim((string) ($device['plantCode'] ?? '')) === '') {
            $device['plantCode'] = $plantCode;
        }
        $id = trim((string) ($device['deviceId'] ?? $device['id'] ?? $device['deviceSn'] ?? ''));
        if ($id !== '') $indexed[$id] = $device;
    }

    $payload = [
        'success' => true,
        'source' => strtolower($source),
        'data' => array_slice(array_values($indexed), 0, 5000),
        'updatedAt' => gmdate(DATE_ATOM),
    ];
    api_cache_put($cacheKey, $payload);
    return $payload['data'];
}
