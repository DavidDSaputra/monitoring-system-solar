<?php
declare(strict_types=1);

function growatt_pick(array $data, array $keys, mixed $default = null): mixed
{
    foreach ($keys as $key) {
        if (array_key_exists($key, $data) && $data[$key] !== null && $data[$key] !== '') {
            return $data[$key];
        }
    }
    return $default;
}

function growatt_float(mixed $value): float
{
    if ($value === null || $value === '') {
        return 0.0;
    }
    return is_numeric($value) ? (float) $value : 0.0;
}

function growatt_status(mixed $value, ?bool $lost = null): string
{
    if ($lost === true) {
        return 'unknown';
    }

    $text = strtolower(trim((string) $value));
    if ($text === '') {
        return $lost === false ? 'online' : 'unknown';
    }

    if (in_array($text, ['1', 'online', 'normal', 'running'], true) || str_contains($text, 'online')) {
        return 'online';
    }
    if (in_array($text, ['2', 'standby'], true)) {
        return 'unknown';
    }
    if (in_array($text, ['3', 'fault', 'error'], true) || str_contains($text, 'fault') || str_contains($text, 'error')) {
        return 'fault';
    }
    if (str_contains($text, 'alarm') || str_contains($text, 'warning')) {
        return 'warning';
    }
    if (in_array($text, ['0', 'offline', 'lost', 'disconnect', 'disconnected'], true) || str_contains($text, 'offline')) {
        return 'unknown';
    }

    return 'unknown';
}

function growatt_text(mixed $value, string $default = ''): string
{
    if ($value === null) {
        return $default;
    }
    $text = trim((string) $value);
    return $text === '' ? $default : $text;
}

function growatt_normalize_station(array $station): array
{
    $city = growatt_text(growatt_pick($station, ['city', 'mapCity']));
    $country = growatt_text(growatt_pick($station, ['country']));
    $address = growatt_text(growatt_pick($station, ['address', 'plantAddress', 'address1']));
    if ($address === '') {
        $address = trim(implode(', ', array_filter([$city, $country])));
    }

    $capacity = growatt_float(growatt_pick($station, ['peak_power', 'peakPower', 'nominalPower', 'capacity']));
    $currentPower = growatt_float(growatt_pick($station, ['current_power', 'currentPower', 'currentPac']));
    if ($capacity > 0 && $currentPower > ($capacity * 5)) {
        $currentPower /= 1000;
    }

    return [
        'source' => 'growatt',
        'plantName' => growatt_text(growatt_pick($station, ['name', 'plantName', 'treeName']), 'Unknown Plant'),
        'plantCode' => growatt_text(growatt_pick($station, ['plant_id', 'plantId', 'id'])),
        'capacity' => $capacity,
        'currentPower' => $currentPower,
        'dailyEnergy' => growatt_float(growatt_pick($station, ['today_energy', 'eToday', 'dailyEnergy'])),
        'monthlyEnergy' => growatt_float(growatt_pick($station, ['monthly_energy', 'energyMonth', 'monthlyEnergy'])),
        'yearlyEnergy' => growatt_float(growatt_pick($station, ['yearly_energy', 'energyYear', 'yearlyEnergy'])),
        'totalEnergy' => growatt_float(growatt_pick($station, ['total_energy', 'eTotal', 'totalEnergy'])),
        'status' => growatt_status(growatt_pick($station, ['status', 'status_text', 'plantStatus'])),
        'address' => $address,
        'latitude' => growatt_text(growatt_pick($station, ['latitude', 'plant_lat', 'mapLat'])),
        'longitude' => growatt_text(growatt_pick($station, ['longitude', 'plant_lng', 'mapLng'])),
        'gridConnectionDate' => growatt_pick($station, ['create_date', 'createDate', 'createDateText']),
        'updatedAt' => gmdate('c'),
        'raw' => $station,
    ];
}

function growatt_normalize_realtime_kpi(array $kpi): array
{
    $updatedAt = growatt_text(growatt_pick($kpi, ['last_update_time', 'time', 'updatedAt']));

    return [
        'currentPower' => growatt_float(growatt_pick($kpi, ['current_power', 'currentPower', 'currentPac', 'pac'])),
        'dailyEnergy' => growatt_float(growatt_pick($kpi, ['today_energy', 'power_today', 'e_today', 'dailyEnergy'])),
        'monthlyEnergy' => growatt_float(growatt_pick($kpi, ['monthly_energy', 'energyMonth', 'monthlyEnergy'])),
        'yearlyEnergy' => growatt_float(growatt_pick($kpi, ['yearly_energy', 'energyYear', 'yearlyEnergy'])),
        'totalEnergy' => growatt_float(growatt_pick($kpi, ['total_energy', 'power_total', 'e_total', 'totalEnergy'])),
        'status' => growatt_status(growatt_pick($kpi, ['status', 'status_text', 'plantStatus'])),
        'updatedAt' => $updatedAt !== '' ? growatt_to_iso($updatedAt) : gmdate('c'),
        'rawKpi' => $kpi,
    ];
}

function growatt_merge_station_with_kpi(array $station, array $kpi): array
{
    $normalizedStation = growatt_normalize_station($station);
    if (count($kpi) === 0) {
        return $normalizedStation;
    }

    $normalizedKpi = growatt_normalize_realtime_kpi($kpi);
    $merged = array_merge($normalizedStation, $normalizedKpi, [
        'status' => $normalizedKpi['status'] !== 'unknown' ? $normalizedKpi['status'] : $normalizedStation['status'],
    ]);
    if (($merged['currentPower'] ?? 0) <= 0 && ($normalizedStation['currentPower'] ?? 0) > 0) {
        $merged['currentPower'] = $normalizedStation['currentPower'];
    }

    return $merged;
}

function growatt_normalize_device(array $device): array
{
    $sn = growatt_text(growatt_pick($device, ['device_sn', 'deviceSn', 'sn']));
    $type = growatt_text(growatt_pick($device, ['device_type', 'deviceType', 'type']));
    $lost = growatt_pick($device, ['lost']);
    $lostBool = is_bool($lost) ? $lost : null;

    return [
        'source' => 'growatt',
        'deviceId' => growatt_text(growatt_pick($device, ['device_id', 'deviceId', 'id']), $sn),
        'deviceName' => growatt_text(growatt_pick($device, ['name', 'model', 'alias']), $sn !== '' ? $sn : 'Growatt Device'),
        'deviceType' => $type,
        'deviceSn' => $sn,
        'dataloggerSn' => growatt_text(growatt_pick($device, ['datalogger_sn', 'dataloggerSn', 'datalogSn'])),
        'status' => growatt_status(growatt_pick($device, ['status', 'status_text', 'state']), $lostBool),
        'currentPower' => growatt_float(growatt_pick($device, ['currentPower', 'pac', 'power'])),
        'dailyEnergy' => growatt_float(growatt_pick($device, ['dailyEnergy', 'power_today', 'e_today'])),
        'totalEnergy' => growatt_float(growatt_pick($device, ['totalEnergy', 'power_total', 'e_total'])),
        'updatedAt' => growatt_to_iso(growatt_text(growatt_pick($device, ['last_update_time', 'createDate', 'updatedAt']))),
        'raw' => $device,
    ];
}

function growatt_normalize_power_point(array $point): array
{
    return [
        'time' => growatt_to_iso(growatt_text(growatt_pick($point, ['time', 'date', 'timestamp']))),
        'power' => growatt_float(growatt_pick($point, ['power', 'pac', 'currentPower'])),
    ];
}

function growatt_to_iso(string $value): string
{
    $value = trim($value);
    if ($value === '') {
        return '';
    }

    $timestamp = strtotime($value);
    if ($timestamp === false) {
        return $value;
    }

    return gmdate('c', $timestamp);
}
