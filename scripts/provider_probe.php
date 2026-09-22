<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/api/lib/bootstrap.php';
require_once dirname(__DIR__) . '/api/lib/solis.php';
require_once dirname(__DIR__) . '/api/services/huawei/huaweiAuthService.php';
require_once dirname(__DIR__) . '/api/services/huawei/huaweiStationService.php';
require_once dirname(__DIR__) . '/api/services/huawei/huaweiKpiService.php';
require_once dirname(__DIR__) . '/api/services/huawei/huaweiDeviceService.php';
require_once dirname(__DIR__) . '/api/services/growatt/growattPlantService.php';
require_once dirname(__DIR__) . '/api/services/growatt/growattDeviceService.php';

$refresh = in_array('--refresh', $argv ?? [], true);

function probe_line(string $label, mixed $value): void
{
    if (is_bool($value)) {
        $value = $value ? 'yes' : 'no';
    }
    if (is_array($value)) {
        $value = json_encode($value, JSON_UNESCAPED_SLASHES);
    }
    echo str_pad($label . ':', 24) . (string) $value . PHP_EOL;
}

function probe_section(string $title): void
{
    echo PHP_EOL . '== ' . $title . ' ==' . PHP_EOL;
}

function probe_keys(array $record, int $limit = 30): string
{
    return implode(', ', array_slice(array_keys($record), 0, $limit));
}

function probe_sample(array $record, array $fields): void
{
    probe_line('keys', probe_keys($record));
    foreach ($fields as $field) {
        if (array_key_exists($field, $record)) {
            probe_line($field, is_scalar($record[$field]) ? $record[$field] : json_encode($record[$field], JSON_UNESCAPED_SLASHES));
        }
    }
}

probe_section('Environment');
probe_line('Solis configured', api_env('SOLIS_API_KEY', '') !== '' && api_env('SOLIS_API_SECRET', '') !== '');
probe_line('Huawei configured', api_env('HUAWEI_BASE_URL', '') !== '' && api_env('HUAWEI_USERNAME', '') !== '' && api_env('HUAWEI_SYSTEM_CODE', '') !== '');
probe_line('Growatt configured', api_env('GROWATT_API_TOKEN', '') !== '');

probe_section('Solis');
try {
    $solis = solis_request('/v1/api/userStationList', ['pageNo' => 1, 'pageSize' => 10], 30, $refresh);
    $records = solis_extract_records($solis['data'] ?? null);
    probe_line('ok', true);
    probe_line('cached', $solis['cached'] ?? false);
    probe_line('records', count($records));
    if (isset($records[0]) && is_array($records[0])) {
        probe_sample($records[0], ['id', 'stationName', 'state', 'power', 'powerStr', 'dayEnergy', 'dayEnergyStr', 'capacity', 'capacityStr']);
    }
} catch (Throwable $e) {
    probe_line('ok', false);
    probe_line('error', $e->getMessage());
}

probe_section('Huawei');
try {
    $session = huawei_login();
    probe_line('login', true);
    probe_line('has token', trim((string) ($session['token'] ?? '')) !== '');
    probe_line('has cookie', trim((string) ($session['cookie'] ?? '')) !== '');
} catch (Throwable $e) {
    probe_line('login', false);
    probe_line('login error', $e->getMessage());
}

try {
    $stations = huawei_get_stations($refresh);
    $records = array_values(array_filter($stations['records'] ?? [], 'is_array'));
    probe_line('stations ok', true);
    probe_line('cached', $stations['cached'] ?? false);
    probe_line('stale', $stations['stale'] ?? false);
    probe_line('station count', count($records));
    if (isset($records[0])) {
        probe_sample($records[0], ['plantName', 'stationName', 'plantCode', 'stationCode', 'capacity', 'plantAddress', 'latitude', 'longitude']);
        $plantCode = (string) ($records[0]['plantCode'] ?? $records[0]['stationCode'] ?? $records[0]['dn'] ?? $records[0]['id'] ?? '');
        if ($plantCode !== '') {
            $kpi = huawei_get_station_realtime_kpi($plantCode, $refresh);
            probe_line('kpi cached', $kpi['cached'] ?? false);
            probe_line('kpi stale', $kpi['stale'] ?? false);
            if (isset($kpi['record']) && is_array($kpi['record'])) {
                probe_sample($kpi['record'], ['stationCode', 'plantCode', 'real_health_state', 'active_power', 'day_power', 'total_power', 'installed_capacity']);
            }

            $devices = huawei_get_dev_list($plantCode, $refresh);
            probe_line('device count', count($devices['records'] ?? []));
            if (isset($devices['records'][0]) && is_array($devices['records'][0])) {
                probe_sample($devices['records'][0], ['devId', 'id', 'devName', 'sn', 'devTypeId', 'invType']);
            }
        }
    }
} catch (Throwable $e) {
    probe_line('stations ok', false);
    probe_line('error', $e->getMessage());
}

probe_section('Growatt');
try {
    $plants = growatt_get_plants($refresh);
    $records = array_values(array_filter($plants['records'] ?? [], 'is_array'));
    probe_line('plants ok', true);
    probe_line('cached', $plants['cached'] ?? false);
    probe_line('plant count', count($records));
    if (isset($records[0])) {
        probe_sample($records[0], ['plant_id', 'name', 'status', 'peak_power', 'current_power', 'total_energy', 'city', 'country', 'latitude', 'longitude']);
    }

    $plantId = '';
    foreach ($records as $record) {
        $candidate = (string) ($record['plant_id'] ?? $record['plantId'] ?? $record['id'] ?? '');
        if ($candidate !== '') {
            $plantId = $candidate;
            break;
        }
    }

    if ($plantId !== '') {
        $data = growatt_get_plant_data($plantId, $refresh);
        probe_line('detail cached', $data['cached'] ?? false);
        probe_sample($data['record'] ?? [], ['today_energy', 'monthly_energy', 'yearly_energy', 'total_energy', 'current_power', 'last_update_time', 'timezone', 'carbon_offset']);

        $devices = growatt_get_devices($plantId, $refresh);
        probe_line('device count', count($devices['records'] ?? []));
        if (isset($devices['records'][0]) && is_array($devices['records'][0])) {
            probe_sample($devices['records'][0], ['device_sn', 'deviceSn', 'sn', 'device_type', 'deviceType', 'status', 'alias']);
        }

        $power = growatt_get_plant_power($plantId, null, $refresh);
        probe_line('power points', count($power['records'] ?? []));
        if (isset($power['records'][0]) && is_array($power['records'][0])) {
            probe_sample($power['records'][0], ['time', 'power']);
        }
    }
} catch (Throwable $e) {
    probe_line('plants ok', false);
    probe_line('error', $e->getMessage());
}
