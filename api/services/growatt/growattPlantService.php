<?php
declare(strict_types=1);

require_once __DIR__ . '/growattApiClient.php';

function growatt_get_plants(bool $forceRefresh = false): array
{
    $cacheKey = 'growatt:plants';
    if (!$forceRefresh) {
        $cached = api_cache_get($cacheKey, 300);
        if ($cached !== null) {
            $cached['cached'] = true;
            return $cached;
        }
    }

    $records = [];
    $total = 0;
    $page = 1;
    $pageSize = 100;

    do {
        $response = growatt_request('GET', 'plant/list', [
            'page' => $page,
            'perpage' => $pageSize,
        ], [], 300, $forceRefresh);
        $data = growatt_data_from_response($response);
        $pageRecords = growatt_records_from_data($data, ['plants', 'records', 'list', 'data']);
        $records = array_merge($records, $pageRecords);
        $total = growatt_total_from_data($data, count($records));
        $page++;
    } while ($total > count($records) && count($pageRecords) > 0 && $page <= 20);

    $payload = [
        'records' => $records,
        'total' => $total > 0 ? $total : count($records),
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

function growatt_get_plant_data(string $plantId, bool $forceRefresh = false): array
{
    $response = growatt_request('GET', 'plant/data', [
        'plant_id' => $plantId,
    ], [], 60, $forceRefresh);
    $data = growatt_data_from_response($response);

    return [
        'record' => is_array($data) ? $data : [],
        'cached' => $response['cached'] ?? false,
    ];
}

function growatt_get_plant_power(string $plantId, ?string $date = null, bool $forceRefresh = false): array
{
    $date ??= gmdate('Y-m-d');
    $response = growatt_request('GET', 'plant/power', [
        'plant_id' => $plantId,
        'date' => $date,
    ], [], 300, $forceRefresh);
    $data = growatt_data_from_response($response);
    $records = growatt_records_from_data($data, ['powers', 'records', 'list', 'data']);

    return [
        'records' => $records,
        'total' => count($records),
        'cached' => $response['cached'] ?? false,
    ];
}

function growatt_records_from_data(mixed $data, array $keys): array
{
    if (is_array($data) && array_is_list($data)) {
        return array_values(array_filter($data, 'is_array'));
    }

    if (!is_array($data)) {
        return [];
    }

    foreach ($keys as $key) {
        if (isset($data[$key]) && is_array($data[$key])) {
            return array_values(array_filter($data[$key], 'is_array'));
        }
    }

    return [];
}

function growatt_total_from_data(mixed $data, int $fallback = 0): int
{
    if (!is_array($data)) {
        return $fallback;
    }

    foreach (['count', 'total', 'totalCount'] as $key) {
        if (isset($data[$key]) && is_numeric($data[$key])) {
            return (int) $data[$key];
        }
    }

    return $fallback;
}
