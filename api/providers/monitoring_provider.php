<?php
declare(strict_types=1);

interface MonitoringProviderAdapter
{
    public function id(): string;

    public function plants(bool $forceRefresh = false): array;

    public function overview(bool $forceRefresh = false): array;

    public function inverters(?string $stationId = null, bool $forceRefresh = false): array;

    public function batteries(bool $forceRefresh = false): array;

    public function collectors(bool $forceRefresh = false): array;

    public function alarms(bool $forceRefresh = false): array;

    public function stationDetail(string $stationId, bool $forceRefresh = false): array;

    public function inverterDetail(string $sn, bool $forceRefresh = false): array;

    public function collectorDetail(string $sn, bool $forceRefresh = false): array;

    public function stationEnergy(
        string $scope,
        string $stationId,
        string $time,
        bool $forceRefresh = false
    ): array;
}
