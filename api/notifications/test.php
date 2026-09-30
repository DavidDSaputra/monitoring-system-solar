<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/firebase_messaging.php';

push_require_cron_secret();

if (PHP_SAPI !== 'cli' && ($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    api_fail(405, 'Method not allowed');
}

$raw = file_get_contents('php://input');
$payload = json_decode($raw !== false ? $raw : '', true);
if (!is_array($payload)) {
    $payload = [];
}

$title = trim((string) ($payload['title'] ?? 'SolarView test'));
$body = trim((string) ($payload['body'] ?? 'Push notification berhasil terhubung.'));
if ($title === '' || $body === '') {
    api_fail(400, 'Title and body are required');
}

$response = fcm_send_topic(
    substr($title, 0, 120),
    substr($body, 0, 500),
    [
        'type' => 'test',
        'event' => 'manual',
    ]
);

api_json([
    'success' => true,
    'data' => $response,
]);
