<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

function incident_store_path(): string
{
    $configured = trim((string) api_env('INCIDENT_STORE_FILE', ''));
    return $configured !== ''
        ? $configured
        : dirname(__DIR__) . DIRECTORY_SEPARATOR . 'data' . DIRECTORY_SEPARATOR . 'incidents.json';
}

function incident_store_read(): array
{
    $path = incident_store_path();
    if (!is_file($path)) {
        return ['incidents' => [], 'updatedAt' => null];
    }

    $handle = fopen($path, 'rb');
    if ($handle === false) {
        return ['incidents' => [], 'updatedAt' => null];
    }

    try {
        flock($handle, LOCK_SH);
        $raw = stream_get_contents($handle);
        $decoded = json_decode(is_string($raw) ? $raw : '', true);
        return is_array($decoded)
            ? $decoded
            : ['incidents' => [], 'updatedAt' => null];
    } finally {
        flock($handle, LOCK_UN);
        fclose($handle);
    }
}

function incident_store_mutate(callable $mutator): array
{
    $path = incident_store_path();
    $directory = dirname($path);
    if (!is_dir($directory)) {
        mkdir($directory, 0770, true);
    }

    $handle = fopen($path, 'c+');
    if ($handle === false) {
        throw new RuntimeException('Unable to open incident store');
    }

    try {
        if (!flock($handle, LOCK_EX)) {
            throw new RuntimeException('Unable to lock incident store');
        }
        rewind($handle);
        $raw = stream_get_contents($handle);
        $store = json_decode(is_string($raw) ? $raw : '', true);
        if (!is_array($store)) {
            $store = ['incidents' => [], 'updatedAt' => null];
        }
        $store['incidents'] = is_array($store['incidents'] ?? null)
            ? $store['incidents']
            : [];

        $result = $mutator($store);
        $store['updatedAt'] = gmdate(DATE_ATOM);
        rewind($handle);
        ftruncate($handle, 0);
        fwrite($handle, json_encode($store, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT));
        fflush($handle);
        return is_array($result) ? $result : [];
    } finally {
        flock($handle, LOCK_UN);
        fclose($handle);
    }
}

function incident_priority(string $entityType, string $status): array
{
    $entityType = strtolower($entityType);
    $status = strtolower($status);

    if ($entityType === 'datalogger' || in_array($status, ['fault', 'error', 'alarm'], true)) {
        return ['priority' => 'P1', 'label' => 'Critical', 'slaMinutes' => 15];
    }
    if ($entityType === 'plant' || in_array($entityType, ['inverter', 'battery'], true)) {
        return ['priority' => 'P2', 'label' => 'High', 'slaMinutes' => 60];
    }
    return ['priority' => 'P3', 'label' => 'Medium', 'slaMinutes' => 240];
}

function incident_open(array $entity, string $status): array
{
    return incident_store_mutate(static function (array &$store) use ($entity, $status): array {
        $entityKey = (string) $entity['key'];
        foreach ($store['incidents'] as $incident) {
            if (($incident['entityKey'] ?? '') === $entityKey && empty($incident['resolvedAt'])) {
                return $incident;
            }
        }

        $now = time();
        $policy = incident_priority((string) $entity['entityType'], $status);
        $incident = [
            'id' => bin2hex(random_bytes(12)),
            'entityKey' => $entityKey,
            'entityType' => $entity['entityType'],
            'entityId' => $entity['entityId'],
            'entityName' => $entity['entityName'],
            'source' => $entity['source'],
            'plantCode' => $entity['plantCode'],
            'plantName' => $entity['plantName'],
            'status' => $status,
            'priority' => $policy['priority'],
            'priorityLabel' => $policy['label'],
            'slaMinutes' => $policy['slaMinutes'],
            'startedAt' => gmdate(DATE_ATOM, $now),
            'slaDueAt' => gmdate(DATE_ATOM, $now + ($policy['slaMinutes'] * 60)),
            'resolvedAt' => null,
            'durationSeconds' => null,
            'address' => $entity['address'] ?? '',
            'latitude' => $entity['latitude'] ?? null,
            'longitude' => $entity['longitude'] ?? null,
        ];
        array_unshift($store['incidents'], $incident);
        $store['incidents'] = array_slice($store['incidents'], 0, 5000);
        return $incident;
    });
}

function incident_resolve(string $entityKey): ?array
{
    $result = incident_store_mutate(static function (array &$store) use ($entityKey): array {
        foreach ($store['incidents'] as &$incident) {
            if (($incident['entityKey'] ?? '') !== $entityKey || !empty($incident['resolvedAt'])) {
                continue;
            }
            $resolvedAt = time();
            $startedAt = strtotime((string) ($incident['startedAt'] ?? '')) ?: $resolvedAt;
            $incident['resolvedAt'] = gmdate(DATE_ATOM, $resolvedAt);
            $incident['durationSeconds'] = max(0, $resolvedAt - $startedAt);
            return $incident;
        }
        unset($incident);
        return [];
    });
    return $result === [] ? null : $result;
}

function incident_with_sla_state(array $incident): array
{
    $due = strtotime((string) ($incident['slaDueAt'] ?? '')) ?: 0;
    $end = !empty($incident['resolvedAt'])
        ? (strtotime((string) $incident['resolvedAt']) ?: time())
        : time();
    $incident['slaBreached'] = $due > 0 && $end > $due;
    $incident['isOpen'] = empty($incident['resolvedAt']);
    if ($incident['isOpen']) {
        $startedAt = strtotime((string) ($incident['startedAt'] ?? '')) ?: $end;
        $incident['durationSeconds'] = max(0, $end - $startedAt);
    }
    return $incident;
}
