<?php
declare(strict_types=1);

function huawei_pick(array $data, array $keys, mixed $default = null): mixed
{
    foreach ($keys as $key) {
        if (array_key_exists($key, $data) && $data[$key] !== null && $data[$key] !== '') {
            return $data[$key];
        }
    }
    return $default;
}

function huawei_float(mixed $value): float
{
    if ($value === null || $value === '') {
        return 0.0;
    }
    return is_numeric($value) ? (float) $value : 0.0;
}

function huawei_status(mixed $value): string
{
    $text = strtolower((string) $value);
    if ($text === '' || $text === 'null') {
        return 'unknown';
    }
    if (str_contains($text, 'normal') || str_contains($text, 'online') || $text === '1') {
        return 'online';
    }
    if (str_contains($text, 'alarm') || str_contains($text, 'warning')) {
        return 'warning';
    }
    if (str_contains($text, 'fault') || str_contains($text, 'error')) {
        return 'fault';
    }
    if (str_contains($text, 'offline') || $text === '0') {
        return 'unknown';
    }
    return 'unknown';
}

function huawei_normalize_station(array $station): array
{
    return [
        'source' => 'huawei',
        'plantName' => (string) huawei_pick($station, ['plantName', 'stationName', 'name'], 'Unknown Plant'),
        'plantCode' => (string) huawei_pick($station, ['plantCode', 'stationCode', 'dn', 'id'], ''),
        'capacity' => huawei_float(huawei_pick($station, ['capacity', 'installedCapacity', 'installCapacity'])),
        'currentPower' => 0.0,
        'dailyEnergy' => 0.0,
        'monthlyEnergy' => 0.0,
        'yearlyEnergy' => 0.0,
        'totalEnergy' => 0.0,
        'status' => huawei_status(huawei_pick($station, ['status', 'plantStatus', 'runningStatus'])),
        'address' => (string) huawei_pick($station, ['plantAddress', 'address'], ''),
        'latitude' => (string) huawei_pick($station, ['latitude', 'lat'], ''),
        'longitude' => (string) huawei_pick($station, ['longitude', 'lng', 'lon'], ''),
        'gridConnectionDate' => huawei_pick($station, ['gridConnectionDate', 'gridConnectedTime']),
        'updatedAt' => gmdate('c'),
        'raw' => $station,
    ];
}

function huawei_normalize_realtime_kpi(array $kpi): array
{
    if (isset($kpi['dataItemMap']) && is_array($kpi['dataItemMap'])) {
        $kpi = array_merge($kpi, $kpi['dataItemMap']);
    }

    $status = huawei_status(huawei_pick($kpi, ['status', 'plantStatus', 'runningStatus']));
    if ($status === 'unknown' && count($kpi) > 0) {
        $status = 'online';
    }

    return [
        'currentPower' => huawei_float(huawei_pick($kpi, ['currentPower', 'activePower', 'realPower', 'real_power', 'ongridPower', 'power'])),
        'dailyEnergy' => huawei_float(huawei_pick($kpi, ['dailyEnergy', 'dayEnergy', 'dailyYield', 'day_power', 'dayPower'])),
        'monthlyEnergy' => huawei_float(huawei_pick($kpi, ['monthlyEnergy', 'monthEnergy', 'month_power', 'monthPower'])),
        'yearlyEnergy' => huawei_float(huawei_pick($kpi, ['yearlyEnergy', 'yearEnergy', 'year_power', 'yearPower'])),
        'totalEnergy' => huawei_float(huawei_pick($kpi, ['totalEnergy', 'totalPower', 'ongridEnergy', 'allEnergy', 'total_power'])),
        'status' => $status,
        'updatedAt' => gmdate('c'),
        'rawKpi' => $kpi,
    ];
}

function huawei_merge_station_with_kpi(array $station, array $kpi): array
{
    $normalizedStation = huawei_normalize_station($station);
    $normalizedKpi = huawei_normalize_realtime_kpi($kpi);
    $status = $normalizedKpi['status'] !== 'unknown'
        ? $normalizedKpi['status']
        : $normalizedStation['status'];

    return array_merge($normalizedStation, $normalizedKpi, [
        'status' => $status,
        'updatedAt' => $normalizedKpi['updatedAt'],
    ]);
}

function huawei_normalize_device(array $device): array
{
    return [
        'source' => 'huawei',
        'deviceId' => (string) huawei_pick($device, ['devId', 'deviceId', 'id'], ''),
        'deviceName' => (string) huawei_pick($device, ['devName', 'deviceName', 'name'], 'Unknown Device'),
        'deviceType' => (string) huawei_pick($device, ['devTypeId', 'deviceType', 'type'], ''),
        'plantCode' => (string) huawei_pick($device, ['plantCode', 'stationCode'], ''),
        'status' => huawei_status(huawei_pick($device, ['status', 'runningStatus'])),
        'raw' => $device,
    ];
}
