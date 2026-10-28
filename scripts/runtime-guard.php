<?php
/**
 * EOL-PHP-SecAuto - Container Runtime Security Guard
 * Part of EOL-PHP-SecAuto by Anton Barinov
 * https://github.com/Anton-Barinov/EOL-PHP-SecAuto
 * 
 * Injected into EOL PHP containers via auto_prepend_file.
 * Prevents exploitation of php2shell, CVE-2024-4577, CVE-2024-2961, CVE-2018-17082.
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

    // 2. Vector 1: php2shell session delimiter and filename inspection
    $progressName = ini_get('session.upload_progress.name');
    if (!$progressName) {
        $progressName = 'PHP_SESSION_UPLOAD_PROGRESS';
    }

    if (isset($_POST[$progressName])) {
        $val = (string)$_POST[$progressName];
        if (strlen($val) > 256 || preg_match('/[\x00-\x1F\x7F|;!]/', $val)) {
            header('HTTP/1.1 403 Forbidden', true, 403);
            header('X-Protected-By: EOL-PHP-SecAuto');
            echo '403 Forbidden - Blocked by EOL-PHP-SecAuto (Vector 1: php2shell)';
            exit(1);
        }
    }

    // 3. Vector 2: CGI Argument Injection & Unicode Best-Fit (CVE-2024-4577 / CVE-2012-1823)
    $queryString = isset($_SERVER['QUERY_STRING']) ? (string)$_SERVER['QUERY_STRING'] : '';
    $requestUri  = isset($_SERVER['REQUEST_URI']) ? (string)$_SERVER['REQUEST_URI'] : '';

    if ($queryString !== '' || $requestUri !== '') {
        $target = $queryString . ' ' . $requestUri;
        if (preg_match('/(%ad|%u00ad|\xad)/i', $target) || preg_match('/(?:^|&|\+|\s)-(?:d|s|w|f|n|c|b)\b/i', $queryString)) {
            header('HTTP/1.1 403 Forbidden', true, 403);
            header('X-Protected-By: EOL-PHP-SecAuto');
            echo '403 Forbidden - Blocked by EOL-PHP-SecAuto (Vector 2: CGI Arg Injection)';
            exit(1);
        }
    }

    // 4. Vector 3: Filter Chains (CVE-2024-2961)
    $checkParam = function($val) use (&$checkParam) {
        if (is_array($val)) {
            foreach ($val as $v) {
                if ($checkParam($v)) return true;
            }
            return false;
        }
        if (!is_string($val) || strlen($val) < 6) return false;
        $decoded = urldecode($val);
        if (stripos($decoded, 'php://filter') !== false) {
            $count = substr_count(strtolower($decoded), 'convert.iconv.') + substr_count(strtolower($decoded), 'convert.base64');
            if ($count >= 3) return true;
            if (preg_match('/convert\.iconv\.(?:ISO[-_]?2022[-_]?CN[-_]?EXT|UTF[-_]?7|CP1361)/i', $decoded)) return true;
        }
        if (stripos($decoded, 'phar://') !== false) return true;
        return false;
    };

    if (!empty($_GET) && $checkParam($_GET)) {
        header('HTTP/1.1 403 Forbidden', true, 403);
        header('X-Protected-By: EOL-PHP-SecAuto');
        echo '403 Forbidden - Blocked by EOL-PHP-SecAuto (Vector 3/4: Filter Chain or Phar wrapper)';
        exit(1);
    }
})();
