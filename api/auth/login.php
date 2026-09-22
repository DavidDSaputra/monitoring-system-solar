<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/bootstrap.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    api_fail(405, 'Method not allowed');
}

$raw = file_get_contents('php://input');
$payload = json_decode($raw !== false ? $raw : '', true);
if (!is_array($payload)) {
    api_fail(400, 'Invalid JSON body');
}

$expectedUsername = (string) api_env('APP_LOGIN_USERNAME', '');
$expectedPassword = (string) api_env('APP_LOGIN_PASSWORD', '');
if ($expectedUsername === '' || $expectedPassword === '') {
    api_fail(500, 'App login credentials are missing on the server');
}

$username = trim((string) ($payload['username'] ?? ''));
$password = (string) ($payload['password'] ?? '');

if (
    hash_equals($expectedUsername, $username) &&
    hash_equals($expectedPassword, $password)
) {
    api_json([
        'success' => true,
        'data' => [
            'authenticated' => true,
        ],
    ]);
}

api_fail(401, 'Invalid username or password');
