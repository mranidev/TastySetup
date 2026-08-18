<?php

declare(strict_types=1);

/**
 * mb_split() shim for the Wasmer Edge PHP runtime.
 *
 * The php/php 8.3.4 WebAssembly build registers mbstring's regular-expression
 * functions (mb_split, mb_ereg*) in CLI mode but NOT when running PHP's
 * built-in web server (`php -S`), which is how this app is deployed on Wasmer
 * Edge. mbstring reports as loaded, yet mb_split() does not exist — and
 * Laravel's Str::studly() (called by the session and cache managers) fatals
 * on it. Any `-d` ini flag or custom php.ini (PHPRC) makes this worse.
 *
 * mb_split() splits a multibyte string on a regular expression; PCRE with the
 * 'u' modifier is equivalent for the UTF-8 patterns this application uses.
 */

if (!function_exists('mb_split')) {
    /**
     * Split a multibyte string using a regular expression.
     *
     * Mirrors mb_split(): returns an array of substrings (a maximum of
     * $limit, with the remainder in the last element) or false on failure.
     */
    function mb_split(string $pattern, string $string, int $limit = -1): array|false
    {
        // mb_split patterns are delimiter-free; preg_split() needs delimiters.
        $delimiter = '~';
        $escaped = str_replace($delimiter, '\\'.$delimiter, $pattern);

        return preg_split($delimiter.$escaped.$delimiter.'u', $string, $limit);
    }
}
