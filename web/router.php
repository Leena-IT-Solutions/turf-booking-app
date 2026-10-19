<?php
$uri = urldecode(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));

// Proxy /storage/ requests to live server with permissive CORS for local web dev
if (str_starts_with($uri, '/storage/')) {
    $remoteUrl = 'https://turf.infoleena.com' . $uri;
    $ch = curl_init($remoteUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    $data = curl_exec($ch);
    $contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE) ?: 'image/jpeg';
    curl_close($ch);

    header("Access-Control-Allow-Origin: *");
    header("Content-Type: " . $contentType);
    header("Cache-Control: max-age=86400");
    echo $data;
    exit;
}

$file = __DIR__ . $uri;
if ($uri !== '/' && file_exists($file) && !is_dir($file)) {
    return false; // serve static file natively
}

include __DIR__ . '/index.html';
