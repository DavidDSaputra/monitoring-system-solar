<?php
declare(strict_types=1);

function normal_float(mixed $value): ?float
{
    if ($value === null || $value === '') {
        return null;
    }
    return is_numeric($value) ? (float) $value : null;
}

function normal_int(mixed $value): ?int
{
    if ($value === null || $value === '') {
        return null;
    }
    return is_numeric($value) ? (int) $value : null;
}

function normal_status(?int $state): string
{
    return match ($state) {
        1 => 'online',
        3 => 'alarm',
        2 => 'offline',
        default => 'unknown',
    };
}

function normalize_plant(array $record): array
{
    $state = normal_int($record['state'] ?? null);
    return [
        'id' => (string) ($record['id'] ?? $record['sno'] ?? ''),
        'provider' => 'solis',
        'providerPlantId' => (string) ($record['id'] ?? ''),
        'name' => (string) ($record['stationName'] ?? $record['sno'] ?? 'Unknown Plant'),
        'status' => normal_status($state),
        'statusCode' => $state,
        'location' => [
            'address' => $record['addr'] ?? $record['addrOrigin'] ?? null,
            'country' => $record['countryStr'] ?? null,
            'region' => $record['regionStr'] ?? null,
            'city' => $record['cityStr'] ?? null,
        ],
        'capacityKw' => normal_float($record['capacity'] ?? null),
        'currentPowerKw' => normal_float($record['power'] ?? null),
        'todayEnergyKwh' => normal_float($record['dayEnergy'] ?? null),
        'monthEnergyKwh' => normal_float($record['monthEnergy'] ?? null),
        'yearEnergyKwh' => normal_float($record['yearEnergy'] ?? null),
        'totalEnergyKwh' => normal_float($record['allEnergy'] ?? null),
        'income' => [
            'currency' => $record['money'] ?? null,
            'today' => normal_float($record['dayIncome'] ?? $record['dayInCome'] ?? null),
            'total' => normal_float($record['allIncome'] ?? null),
        ],
        'deviceCounts' => [
            'inverters' => normal_int($record['inverterCount'] ?? null),
            'onlineInverters' => normal_int($record['inverterOnlineCount'] ?? null),
            'batteries' => normal_int($record['epmCount'] ?? null),
            'collectors' => normal_int($record['collectorCount'] ?? $record['dataloggerCount'] ?? null),
        ],
        'updatedAtMs' => normal_int($record['dataTimestamp'] ?? $record['updateDate'] ?? null),
        'updatedAtText' => $record['dataTimestampStr'] ?? null,
        'units' => [
            'capacity' => $record['capacityStr'] ?? 'kWp',
            'power' => $record['powerStr'] ?? 'kW',
            'energy' => $record['dayEnergyStr'] ?? 'kWh',
        ],
    ];
}

function normalize_inverter(array $record): array
{
    $state = normal_int($record['state'] ?? null);
    return [
        'id' => (string) ($record['id'] ?? $record['sn'] ?? ''),
        'provider' => 'solis',
        'serialNumber' => (string) ($record['sn'] ?? $record['inverterSn'] ?? ''),
        'name' => $record['name'] ?? $record['inverterName'] ?? null,
        'plantId' => isset($record['stationId']) ? (string) $record['stationId'] : null,
        'plantName' => $record['stationName'] ?? null,
        'status' => normal_status($state),
        'statusCode' => $state,
        'currentPowerKw' => normal_float($record['pac'] ?? null),
        'capacityKw' => normal_float($record['power'] ?? null),
        'todayEnergyKwh' => normal_float($record['etoday'] ?? $record['eToday'] ?? null),
        'monthEnergyKwh' => normal_float($record['eMonth'] ?? null),
        'yearEnergyKwh' => normal_float($record['eYear'] ?? null),
        'totalEnergyKwh' => normal_float($record['etotal'] ?? $record['eTotal'] ?? null),
        'model' => $record['productModel'] ?? null,
        'collectorSn' => $record['collectorSn'] ?? null,
        'updatedAtMs' => normal_int($record['dataTimestamp'] ?? null),
        'updatedAtText' => $record['dataTimestampStr'] ?? null,
        'battery' => [
            'socPercent' => normal_float($record['batteryCapacitySoc'] ?? $record['soc'] ?? null),
            'powerKw' => normal_float($record['batteryPower'] ?? null),
            'totalChargeKwh' => normal_float($record['batteryTotalChargeEnergy'] ?? null),
            'totalDischargeKwh' => normal_float($record['batteryTotalDischargeEnergy'] ?? null),
        ],
    ];
}

function normalize_battery(array $record): array
{
    $state = normal_int($record['state'] ?? null);
    return [
        'id' => (string) ($record['id'] ?? $record['sn'] ?? $record['inverterSn'] ?? ''),
        'provider' => 'solis',
        'serialNumber' => (string) ($record['sn'] ?? $record['inverterSn'] ?? ''),
        'name' => $record['name'] ?? $record['batteryName'] ?? $record['inverterName'] ?? null,
        'plantId' => isset($record['stationId']) ? (string) $record['stationId'] : null,
        'plantName' => $record['stationName'] ?? null,
        'status' => normal_status($state),
        'statusCode' => $state,
        'powerKw' => normal_float($record['batteryPower'] ?? $record['pEpmTotal'] ?? null),
        'socPercent' => normal_float($record['batteryCapacitySoc'] ?? null),
        'sohPercent' => normal_float($record['batteryHealthSoh'] ?? null),
        'todayChargeKwh' => normal_float($record['batteryTodayChargeEnergy'] ?? null),
        'todayDischargeKwh' => normal_float($record['batteryTodayDischargeEnergy'] ?? null),
        'totalChargeKwh' => normal_float($record['batteryTotalChargeEnergy'] ?? null),
        'totalDischargeKwh' => normal_float($record['batteryTotalDischargeEnergy'] ?? null),
        'updatedAtMs' => normal_int($record['dataTimestamp'] ?? null),
        'updatedAtText' => $record['dataTimestampStr'] ?? null,
    ];
}

function normalize_collector(array $record): array
{
    $state = normal_int($record['state'] ?? null);
    return [
        'id' => (string) ($record['id'] ?? $record['sn'] ?? $record['collectorSn'] ?? ''),
        'provider' => 'solis',
        'serialNumber' => (string) ($record['sn'] ?? $record['collectorSn'] ?? ''),
        'name' => $record['collectorName'] ?? $record['name'] ?? null,
        'plantId' => isset($record['stationId']) ? (string) $record['stationId'] : null,
        'plantName' => $record['stationName'] ?? null,
        'status' => $state === 1 ? 'online' : 'offline',
        'statusCode' => $state,
        'model' => $record['collectorType'] ?? $record['model'] ?? $record['dataloggerModel'] ?? null,
        'firmwareVersion' => $record['firmwareVersion'] ?? $record['softVersion'] ?? $record['version'] ?? null,
        'network' => [
            'ipAddress' => $record['ipAddress'] ?? $record['ip'] ?? $record['lanIp'] ?? null,
            'macAddress' => $record['mac'] ?? $record['macAddress'] ?? $record['macAddr'] ?? null,
            'ssid' => $record['ssid'] ?? $record['wifiSsid'] ?? null,
            'signalStrength' => normal_int($record['signalStrength'] ?? $record['rssiLevel'] ?? $record['rssi'] ?? null),
        ],
        'updatedAtMs' => normal_int($record['dataTimestamp'] ?? null),
        'updatedAtText' => $record['dataTimestampStr'] ?? null,
    ];
}

function normalize_alarm(array $record): array
{
    $level = normal_int($record['alarmLevel'] ?? null);
    return [
        'id' => (string) ($record['id'] ?? ''),
        'provider' => 'solis',
        'deviceSerialNumber' => (string) ($record['alarmDeviceSn'] ?? ''),
        'plantId' => isset($record['stationId']) ? (string) $record['stationId'] : null,
        'plantName' => $record['stationName'] ?? null,
        'name' => $record['alarmName'] ?? null,
        'message' => $record['alarmMsg'] ?? null,
        'severity' => match ($level) {
            1 => 'info',
            2 => 'warning',
            3 => 'critical',
            default => 'unknown',
        },
        'severityCode' => $level,
        'isRecovered' => normal_int($record['alarmStatus'] ?? null) === 1,
        'startedAtMs' => normal_int($record['alarmBeginTime'] ?? null),
        'startedAtText' => $record['alarmBeginTimeStr'] ?? null,
        'recoveredAtMs' => normal_int($record['alarmRecoverTime'] ?? null),
        'recoveredAtText' => $record['alarmRecoverTimeStr'] ?? null,
    ];
}

function normalize_energy_point(array $record): array
{
    return [
        'time' => (string) ($record['time'] ?? $record['timeStr'] ?? ''),
        'powerKw' => normal_float($record['power'] ?? $record['pac'] ?? $record['pow'] ?? null),
        'energyKwh' => normal_float($record['energy'] ?? $record['eToday'] ?? $record['value'] ?? null),
        'timestampMs' => normal_int($record['timeStamp'] ?? $record['timestamp'] ?? null),
    ];
}

function normalize_records(array $records, callable $normalizer): array
{
    return array_values(array_map(static fn ($record) => $normalizer(is_array($record) ? $record : []), $records));
}
