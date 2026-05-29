<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/monitoring_provider.php';
require_once dirname(__DIR__, 2) . '/lib/solis.php';

class SolisProvider implements MonitoringProviderAdapter
{
    public function id(): string
    {
        return 'solis';
    }

    public function plants(bool $forceRefresh = false): array
    {
        return solis_all_records('/v1/api/userStationList', [], 20, 100, $forceRefresh);
    }

    public function overview(bool $forceRefresh = false): array
    {
        return [
            'plants' => $this->plants($forceRefresh),
            'inverters' => $this->inverters(null, $forceRefresh),
            'batteries' => $this->batteries($forceRefresh),
            'collectors' => $this->collectors($forceRefresh),
        ];
    }

    public function inverters(?string $stationId = null, bool $forceRefresh = false): array
    {
        $body = $stationId !== null && trim($stationId) !== '' ? ['stationId' => trim($stationId)] : [];
        return solis_all_records('/v1/api/inverterList', $body, 25, 100, $forceRefresh);
    }

    public function batteries(bool $forceRefresh = false): array
    {
        $result = solis_all_records('/v1/api/epmList', [], 30, 100, $forceRefresh);
        if (count($result['records']) > 0) {
            return $result;
        }

        $inverters = $this->inverters(null, $forceRefresh);
        $batteryRecords = array_values(array_filter($inverters['records'], static function ($record): bool {
            if (!is_array($record)) {
                return false;
            }

            $soc = (float) ($record['batteryCapacitySoc'] ?? $record['soc'] ?? 0);
            $batteryPower = abs((float) ($record['batteryPower'] ?? 0));
            $charge = abs((float) ($record['batteryTotalChargeEnergy'] ?? 0));
            $discharge = abs((float) ($record['batteryTotalDischargeEnergy'] ?? 0));

            return $soc > 0 && ($batteryPower > 0.000001 || $charge > 0.000001 || $discharge > 0.000001);
        }));

        return [
            'records' => $batteryRecords,
            'total' => count($batteryRecords),
            'cached' => $inverters['cached'] ?? false,
        ];
    }

    public function collectors(bool $forceRefresh = false): array
    {
        return solis_all_records('/v1/api/collectorList', [], 30, 100, $forceRefresh);
    }

    public function alarms(bool $forceRefresh = false): array
    {
        $payload = solis_request(
            '/v1/api/alarmList',
            ['pageNo' => 1, 'pageSize' => 100],
            30,
            $forceRefresh
        );
        $data = $payload['data'] ?? null;
        $records = solis_extract_records($data);

        return [
            'records' => $records,
            'total' => solis_extract_total($data),
            'cached' => $payload['cached'] ?? false,
        ];
    }

    public function stationDetail(string $stationId, bool $forceRefresh = false): array
    {
        return solis_request('/v1/api/stationDetail', ['id' => $stationId], 20, $forceRefresh);
    }

    public function inverterDetail(string $sn, bool $forceRefresh = false): array
    {
        return solis_request('/v1/api/inverterDetail', ['sn' => $sn], 15, $forceRefresh);
    }

    public function collectorDetail(string $sn, bool $forceRefresh = false): array
    {
        return solis_request('/v1/api/collectorDetail', ['sn' => $sn], 15, $forceRefresh);
    }

    public function stationEnergy(
        string $scope,
        string $stationId,
        string $time,
        bool $forceRefresh = false
    ): array {
        $endpoint = match ($scope) {
            'month' => '/v1/api/stationMonth',
            'year' => '/v1/api/stationYear',
            default => '/v1/api/stationDay',
        };

        $ttl = match ($scope) {
            'month' => 300,
            'year' => 600,
            default => 60,
        };

        $payload = solis_request($endpoint, [
            'id' => $stationId,
            'money' => 'IDR',
            'time' => $time,
            'timeZone' => 7,
        ], $ttl, $forceRefresh);

        $records = solis_extract_records($payload['data'] ?? null);
        return [
            'records' => $records,
            'total' => count($records),
            'cached' => $payload['cached'] ?? false,
        ];
    }
}
