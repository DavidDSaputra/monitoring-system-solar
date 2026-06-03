<?php
declare(strict_types=1);

require_once __DIR__ . '/growattApiClient.php';
require_once __DIR__ . '/growattPlantService.php';

function growatt_get_devices(string $plantId, bool $forceRefresh = false): array
{
    $response = growatt_request('GET', 'device/list', [
        'plant_id' => $plantId,
        'page' => 1,
        'perpage' => 100,
    ], [], 300, $forceRefresh);
    $data = growatt_data_from_response($response);
    $records = growatt_records_from_data($data, ['devices', 'records', 'list', 'data']);

    return [
        'records' => $records,
        'total' => growatt_total_from_data($data, count($records)),
        'cached' => $response['cached'] ?? false,
    ];
}

function growatt_get_device_list_v4(int $page = 1, bool $forceRefresh = false): array
{
    $response = growatt_request('POST', 'new-api/queryDeviceList', [], [
        'page' => $page,
    ], 300, $forceRefresh);
    $data = growatt_data_from_response($response);
    $records = growatt_records_from_data($data, ['data', 'devices', 'records', 'list']);

    return [
        'records' => $records,
        'total' => growatt_total_from_data($data, count($records)),
        'cached' => $response['cached'] ?? false,
    ];
}

function growatt_get_dev_last_data(string $deviceSn, string $deviceType, bool $forceRefresh = false): array
{
    $response = growatt_request('POST', 'new-api/queryLastData', [], [
        'deviceSn' => $deviceSn,
        'deviceType' => $deviceType,
    ], 60, $forceRefresh);
    $data = growatt_data_from_response($response);

    return [
        'record' => is_array($data) ? $data : [],
        'cached' => $response['cached'] ?? false,
    ];
}
