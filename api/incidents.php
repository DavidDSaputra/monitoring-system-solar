<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/incident_store.php';

$status = strtolower(trim((string) ($_GET['status'] ?? 'all')));
$source = strtolower(trim((string) ($_GET['source'] ?? 'all')));
$store = incident_store_read();
$records = array_values(array_filter(
    array_map('incident_with_sla_state', $store['incidents'] ?? []),
    static function (array $incident) use ($status, $source): bool {
        $statusMatches = $status === 'all'
            || ($status === 'open' && ($incident['isOpen'] ?? false))
            || ($status === 'resolved' && !($incident['isOpen'] ?? true));
        $sourceMatches = $source === 'all' || ($incident['source'] ?? '') === $source;
        return $statusMatches && $sourceMatches;
    }
));

api_json([
    'success' => true,
    'data' => [
        'records' => $records,
        'total' => count($records),
        'updatedAt' => $store['updatedAt'] ?? null,
    ],
]);
