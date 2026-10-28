<?php
/**
 * EOL-PHP-SecAuto - Container Runtime Security Guard
 * Part of EOL-PHP-SecAuto by Anton Barinov
 * https://github.com/Anton-Barinov/EOL-PHP-SecAuto
 * 
 * Injected into EOL PHP containers via auto_prepend_file.
 * Prevents exploitation of php2shell, CVE-2024-4577, CVE-2024-2961, CVE-2018-17082, CVE-2016-10033.
 */

if (defined('EOL_SECAUTO_GUARD_ACTIVE')) {
    return;
}
define('EOL_SECAUTO_GUARD_ACTIVE', true);

(function() {
    // 1. Proactively disable session upload progress in unpatched runtimes
    if (ini_get('session.upload_progress.enabled')) {
        @ini_set('session.upload_progress.enabled', '0');
    }

    // Fast exit helper
    $terminate = function($code, $reason) {
        if (!headers_sent()) {
            header('HTTP/1.1 ' . $code . ' Forbidden', true, $code);
            header('X-Protected-By: EOL-PHP-SecAuto');
            header('Content-Type: text/plain; charset=utf-8');
        }
        echo "403 Forbidden - Blocked by EOL-PHP-SecAuto ({$reason})";
        exit(1);
    };

    // 2. Host Header Validation
    if (isset($_SERVER['HTTP_HOST'])) {
        $host = (string)$_SERVER['HTTP_HOST'];
        if ($host !== '' && (preg_match('/[\r\n\0]/', $host) || !preg_match('/^[a-zA-Z0-9.\-_]+(?::\d{1,5})?$/', $host))) {
            $terminate(400, 'Host Header Malformed');
        }
    }

    // 3. Vector 1: php2shell session delimiter and filename inspection
    $progressName = ini_get('session.upload_progress.name');
    if (!$progressName) {
        $progressName = 'PHP_SESSION_UPLOAD_PROGRESS';
    }

    if (isset($_POST[$progressName])) {
        $val = (string)$_POST[$progressName];
        if (strlen($val) > 256 || preg_match('/[\x00-\x1F\x7F|;!]/', $val)) {
            $terminate(403, 'Vector 1: php2shell');
        }
    }

    // 4. Vector 2: CGI Argument Injection & Unicode Best-Fit (CVE-2024-4577 / CVE-2012-1823)
    $queryString = isset($_SERVER['QUERY_STRING']) ? (string)$_SERVER['QUERY_STRING'] : '';
    $requestUri  = isset($_SERVER['REQUEST_URI']) ? (string)$_SERVER['REQUEST_URI'] : '';

    if ($queryString !== '' || $requestUri !== '') {
        $target = $queryString . ' ' . $requestUri;
        if (preg_match('/(%ad|%u00ad|\xad)/i', $target) || preg_match('/(%c0%af|%c1%9c)/i', $target) || preg_match('/(?:^|&|\+|\s)-(?:d|s|w|f|n|c|b)\b/i', $queryString)) {
            $terminate(403, 'Vector 2: CGI Arg Injection');
        }
    }

    // 5. Recursive inspector for GET, POST, COOKIE (Filter Chains, Phar, Null-Byte, Shellshock)
    $inspect = function($val) use (&$inspect, $terminate) {
        if (is_array($val)) {
            foreach ($val as $k => $v) {
                $inspect($k);
                $inspect($v);
            }
            return;
        }

        if (!is_string($val) || strlen($val) < 2) {
            return;
        }

        // Null-byte poisoning
        if (strpos($val, "\0") !== false || stripos($val, '%00') !== false) {
            $terminate(403, 'Vector 5: Null-Byte Poisoning');
        }

        $decoded = urldecode($val);

        // Vector 3: Filter Chains (CVE-2024-2961)
        if (stripos($decoded, 'php://filter') !== false) {
            $count = substr_count(strtolower($decoded), 'convert.iconv.') + substr_count(strtolower($decoded), 'convert.base64');
            if ($count >= 3 || preg_match('/convert\.iconv\.(?:ISO[-_]?2022[-_]?CN[-_]?EXT|UTF[-_]?7|CP1361)/i', $decoded)) {
                $terminate(403, 'Vector 3: Filter Chain');
            }
        }

        // Vector 4: Phar Deserialization (CVE-2018-17082) & POP gadgets
        if (stripos($decoded, 'phar://') !== false) {
            $terminate(403, 'Vector 4: Phar Deserialization');
        }
        if (preg_match('/O:\d+:"(?:GuzzleHttp|Monolog|Symfony|Laminas|Zend|Swift|Illuminate)\\\\/i', $decoded)) {
            $terminate(403, 'Vector 4: Object Injection POP Gadget');
        }

        // Vector 5: Sendmail parameter injection
        if (strlen($decoded) > 3 && preg_match('/(?:^|\s)-(?:X|OQueueDirectory|C)\b/i', $decoded)) {
            $terminate(403, 'Vector 5: Sendmail Parameter Abuse');
        }
    };

    if (!empty($_GET)) $inspect($_GET);
    if (!empty($_POST)) $inspect($_POST);
    if (!empty($_COOKIE)) $inspect($_COOKIE);
})();
