<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/firebase_messaging.php';
require_once dirname(__DIR__) . '/lib/incident_store.php';

push_require_cron_secret();

$lock = api_lock_acquire('push:check-alerts', 120);
if ($lock === false) {
    api_json(['success' => true, 'message' => 'Push alert check already running']);
}

try {
    $plants = push_current_plants();
    $entities = $plants + push_current_devices($plants);
    $previousPayload = api_cache_get_stale('push:entity-state:v3', 31536000);
    $previousStates = is_array($previousPayload['entities'] ?? null)
        ? $previousPayload['entities']
        : [];
    $nextStates = [];
    $sent = [];
    $errors = [];

    foreach ($entities as $key => $entity) {
        $status = strtolower(trim((string) ($entity['status'] ?? 'unknown')));
        $previous = is_array($previousStates[$key] ?? null) ? $previousStates[$key] : null;
        $unknownCount = $status === 'unknown'
            ? ((int) ($previous['unknownCount'] ?? 0)) + 1
            : 0;
        $lastKnownStatus = $status === 'unknown'
            ? (string) ($previous['lastKnownStatus'] ?? 'unknown')
            : $status;
        $directIssue = in_array($status, ['offline', 'alarm', 'warning', 'fault', 'error'], true);
        $confirmedUnknown = $status === 'unknown'
            && $unknownCount >= 2
            && ($previous['lastKnownStatus'] ?? '') === 'online';
        $isIssue = $directIssue || $confirmedUnknown;
        $wasIssue = (bool) ($previous['isIssue'] ?? $previous['notifiedIssue'] ?? false);
        $wasNotified = (bool) ($previous['notifiedIssue'] ?? false);
        $notificationSent = false;
        $baselineIssue = $previous === null && $isIssue;
        $displayStatus = $confirmedUnknown ? 'offline' : $status;

        if ($previous === null && $isIssue) {
            incident_open($entity, $displayStatus);
        } elseif ($previous !== null && $isIssue && !$wasIssue) {
            $incident = incident_open($entity, $displayStatus);
            try {
                $response = push_send_entity_notification($entity, $incident, $displayStatus, false);
                $sent[] = ['entity' => $entity['entityName'], 'event' => 'issue', 'response' => $response];
                $notificationSent = true;
            } catch (Throwable $error) {
                $errors[] = ['entity' => $entity['entityName'], 'message' => $error->getMessage()];
            }
        } elseif ($previous !== null && $isIssue && !$wasNotified) {
            $incident = incident_open($entity, $displayStatus);
            try {
                $response = push_send_entity_notification($entity, $incident, $displayStatus, false);
                $sent[] = ['entity' => $entity['entityName'], 'event' => 'issue-retry', 'response' => $response];
                $notificationSent = true;
            } catch (Throwable $error) {
                $errors[] = ['entity' => $entity['entityName'], 'message' => $error->getMessage()];
            }
        } elseif ($previous !== null && !$isIssue && $status === 'online' && $wasIssue) {
            $incident = incident_resolve($key);
            try {
                $response = push_send_entity_notification($entity, $incident ?? [], 'online', true);
                $sent[] = ['entity' => $entity['entityName'], 'event' => 'recovered', 'response' => $response];
                $notificationSent = true;
            } catch (Throwable $error) {
                $errors[] = ['entity' => $entity['entityName'], 'message' => $error->getMessage()];
            }
        }

        $nextStates[$key] = [
            'source' => $entity['source'],
            'entityType' => $entity['entityType'],
            'entityId' => $entity['entityId'],
            'entityName' => $entity['entityName'],
            'plantCode' => $entity['plantCode'],
            'plantName' => $entity['plantName'],
            'status' => $status,
            'lastKnownStatus' => $lastKnownStatus,
            'unknownCount' => $unknownCount,
            'isIssue' => $isIssue,
            'notifiedIssue' => $isIssue
                ? ($wasNotified || $notificationSent || $baselineIssue)
                : false,
            'checkedAt' => gmdate(DATE_ATOM),
        ];
    }

    api_cache_put('push:entity-state:v3', [
        'entities' => $nextStates,
        'checkedAt' => gmdate(DATE_ATOM),
    ]);

    $deviceCount = count(array_filter($entities, static fn (array $item): bool => $item['entityType'] !== 'plant'));
    api_json([
        'success' => count($errors) === 0,
        'checkedPlants' => count($plants),
        'checkedDevices' => $deviceCount,
        'sent' => $sent,
        'errors' => $errors,
        'baselineCreated' => count($previousStates) === 0,
    ], count($errors) === 0 ? 200 : 502);
} finally {
    api_lock_release($lock);
}

function push_send_entity_notification(array $entity, array $incident, string $status, bool $recovered): array
{
    $entityLabel = push_entity_label((string) $entity['entityType']);
    $duration = (int) ($incident['durationSeconds'] ?? 0);
    $priority = (string) ($incident['priority'] ?? 'P2');
    $title = $recovered ? "{$entityLabel} kembali normal" : "{$priority} · {$entityLabel} perlu diperiksa";
    $body = $recovered
        ? sprintf('%s di %s pulih%s.', $entity['entityName'], $entity['plantName'], $duration > 0 ? ' setelah ' . push_duration($duration) : '')
        : sprintf('%s di %s berstatus %s. SLA %s menit.', $entity['entityName'], $entity['plantName'], strtoupper($status), $incident['slaMinutes'] ?? 60);

    return fcm_send_topic($title, $body, [
        'type' => $entity['entityType'] === 'plant' ? 'plant_status' : 'device_status',
        'route' => 'plant_detail',
        'event' => $recovered ? 'recovered' : 'issue',
        'tab' => $recovered ? 'overview' : 'alarm',
        'source' => $entity['source'],
        'plantCode' => $entity['plantCode'],
        'plantName' => $entity['plantName'],
        'entityType' => $entity['entityType'],
        'entityId' => $entity['entityId'],
        'entityName' => $entity['entityName'],
        'status' => $status,
        'priority' => $priority,
        'incidentId' => (string) ($incident['id'] ?? ''),
    ]);
}

function push_current_plants(): array
{
    $sources = [
        ['key' => 'monitoring:plants:solis', 'source' => 'solis'],
        ['key' => 'huawei:normalized-plants', 'source' => 'huawei'],
        ['key' => 'growatt:normalized-plants:hydrated', 'source' => 'growatt'],
        ['key' => 'growatt:normalized-plants:fast', 'source' => 'growatt'],
    ];
    $plants = [];

    foreach ($sources as $sourceConfig) {
        $payload = api_cache_get_stale($sourceConfig['key'], 86400);
        $records = is_array($payload['data'] ?? null) ? $payload['data'] : [];
        foreach ($records as $record) {
            if (!is_array($record)) continue;
            $source = strtolower(trim((string) ($record['source'] ?? $record['provider'] ?? $sourceConfig['source'])));
            $code = trim((string) ($record['plantCode'] ?? $record['providerPlantId'] ?? $record['id'] ?? ''));
            $name = trim((string) ($record['plantName'] ?? $record['name'] ?? 'Unknown Plant'));
            if ($code === '') $code = sha1($source . ':' . $name);
            $key = $source . ':plant:' . $code;
            $location = is_array($record['location'] ?? null) ? $record['location'] : [];
            $plants[$key] = [
                'key' => $key,
                'source' => $source,
                'entityType' => 'plant',
                'entityId' => $code,
                'entityName' => $name,
                'plantCode' => $code,
                'plantName' => $name,
                'status' => strtolower(trim((string) ($record['status'] ?? 'unknown'))),
                'address' => $record['address'] ?? $location['address'] ?? '',
                'latitude' => push_nullable_float($record['latitude'] ?? null),
                'longitude' => push_nullable_float($record['longitude'] ?? null),
            ];
        }
    }
    return $plants;
}

function push_current_devices(array $plants): array
{
    $devices = [];
    $plantIndex = [];
    foreach ($plants as $plant) {
        $plantIndex[$plant['source'] . ':' . $plant['plantCode']] = $plant;
    }

    $solis = api_cache_get_stale('app:normalized:overview:v1', 86400);
    $sections = ['inverters' => 'inverter', 'batteries' => 'battery', 'collectors' => 'datalogger'];
    foreach ($sections as $section => $type) {
        $records = $solis['data'][$section]['records'] ?? [];
        foreach (is_array($records) ? $records : [] as $record) {
            if (!is_array($record)) continue;
            push_add_device($devices, $plantIndex, $record, 'solis', $type);
        }
    }

    foreach (['huawei', 'growatt'] as $source) {
        $snapshot = api_cache_get_stale('monitoring:devices:' . $source, 86400);
        $records = is_array($snapshot['data'] ?? null) ? $snapshot['data'] : [];
        foreach ($records as $record) {
            if (!is_array($record)) continue;
            push_add_device($devices, $plantIndex, $record, $source, push_device_type((string) ($record['deviceType'] ?? $record['type'] ?? 'device')));
        }
    }
    return $devices;
}

function push_add_device(array &$devices, array $plantIndex, array $record, string $source, string $type): void
{
    $id = trim((string) ($record['deviceId'] ?? $record['id'] ?? $record['serialNumber'] ?? $record['deviceSn'] ?? ''));
    if ($id === '') return;
    $plantCode = trim((string) ($record['plantCode'] ?? $record['plantId'] ?? $record['stationId'] ?? ''));
    $plant = $plantIndex[$source . ':' . $plantCode] ?? null;
    $plantName = trim((string) ($record['plantName'] ?? $plant['plantName'] ?? 'Unknown Plant'));
    $name = trim((string) ($record['deviceName'] ?? $record['name'] ?? $record['serialNumber'] ?? $record['deviceSn'] ?? $id));
    $key = $source . ':' . $type . ':' . $id;
    $devices[$key] = [
        'key' => $key,
        'source' => $source,
        'entityType' => $type,
        'entityId' => $id,
        'entityName' => $name,
        'plantCode' => $plantCode,
        'plantName' => $plantName,
        'status' => strtolower(trim((string) ($record['status'] ?? 'unknown'))),
        'address' => $plant['address'] ?? '',
        'latitude' => $plant['latitude'] ?? null,
        'longitude' => $plant['longitude'] ?? null,
    ];
}

function push_device_type(string $raw): string
{
    $value = strtolower($raw);
    if (str_contains($value, 'battery') || str_contains($value, 'storage') || str_contains($value, 'ess')) return 'battery';
    if (str_contains($value, 'logger') || str_contains($value, 'collector') || str_contains($value, 'dongle')) return 'datalogger';
    return 'inverter';
}

function push_entity_label(string $type): string
{
    return match ($type) {
        'inverter' => 'Inverter',
        'battery' => 'Baterai',
        'datalogger' => 'Datalogger',
        default => 'Plant',
    };
}

function push_duration(int $seconds): string
{
    if ($seconds >= 3600) return floor($seconds / 3600) . ' jam ' . floor(($seconds % 3600) / 60) . ' menit';
    return max(1, (int) floor($seconds / 60)) . ' menit';
}

function push_nullable_float(mixed $value): ?float
{
    return is_numeric($value) ? (float) $value : null;
}
