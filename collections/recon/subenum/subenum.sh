#!/usr/bin/env bash

# Usage
# ╔══════════╦════════════════════════════════════════════════════════════════╗
# ║ Flags    ║ Description                                                    ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -t       ║ Target you want to scan (e.g: example.com)                     ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -w       ║ Subdomain wordlist (format: one subdomain per line).           ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -r       ║ Rate limit (requests/second, default: 0)                       ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -d       ║ Delay between requests (seconds, default: 0)                   ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -T       ║ Request timeout (seconds, default: 5)                          ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -a       ║ Active scan (default: passive)                                 ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -H       ║ Identity header (e.g: X-HackerOne: abc)                        ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -o       ║ Output file (e.g: result.txt or ../output/result.txt)          ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -k       ║ Chaos API key (optional)                                       ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ --httpx  ║ Run HTTP probing with httpx in active mode                     ║
# ╠══════════╬════════════════════════════════════════════════════════════════╣
# ║ -h       ║ Show this help message                                         ║
# ╚══════════╩════════════════════════════════════════════════════════════════╝

target=""
rate_limit=0
delay=0
timeout=5
active=false
httpx_enabled=false
identity_header=""
output="subdomains.txt"
wordlist=""
chaos_api_key=""

usage() { sed -n '2,30p' "$0"; }

error() {
    echo "[!] Error: $*" >&2
    echo "[!] Use '-h' for help." >&2
    exit 1
}

info() { echo "[*] $*"; }
success() { echo "[+] $*"; }

check_tool() {
    command -v "$1" >/dev/null 2>&1 || error "required tool not found: $1"
}

check_dependencies() {
    check_tool subfinder
    [[ -n "$chaos_api_key" ]] && check_tool chaos-client

    if [[ "$active" == true ]]; then
        local tools=(dnsx ffuf naabu)
        [[ "$httpx_enabled" == true ]] && tools+=(httpx)

        for tool in "${tools[@]}"; do check_tool "$tool"; done
        [[ -n "$wordlist" ]] || error "active mode requires -w <wordlist>"
        [[ -f "$wordlist" ]] || error "wordlist not found: $wordlist"
    fi

    [[ "$httpx_enabled" == true && "$active" != true ]] && error "--httpx requires active mode (-a)"
}

validate_args() {
    [[ -n "$target" ]] || error "target is required. Use -t <target>"
    if [[ "$rate_limit" != 0 ]] && ! [[ "$rate_limit" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        error "rate limit must be a number"
    fi
    [[ "$delay" =~ ^[0-9]+$ ]] || error "delay must be an integer"
    [[ "$timeout" =~ ^[0-9]+$ ]] || error "timeout must be an integer"
    [[ -n "$output" ]] || error "output file cannot be empty"
}

prepare_output() {
    local dir="$(dirname "$output")"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || error "cannot create output directory: $dir"
    fi
    : > "$output" || error "cannot write output file: $output"
}

asset_file() {
    printf '%s/%s%s\n' "$(dirname "$output")" "$(basename "$output")" "$1"
}

write_if_nonempty() {
    local source="$1" destination="$2"
    if [[ -s "$source" ]]; then
        sort -u "$source" > "$destination"
        success "Saved: $destination"
    fi
}

chaos_scan() {
    local target="$1" output_file="$2"
    [[ -n "$chaos_api_key" ]] || { info "Chaos skipped: no API key provided"; return 0; }

    info "Running chaos-client..."
    chaos-client -d "$target" -silent -key "$chaos_api_key" >> "$output_file" 2>/dev/null || {
        info "chaos-client failed, continuing..."
    }
}

passive_scan() {
    local target="$1" tmp="$(mktemp)"
    trap 'rm -f "$tmp"' RETURN

    info "Passive enumeration: $target"
    info "Running subfinder..."
    subfinder -d "$target" -silent >> "$tmp" 2>/dev/null || info "subfinder failed, continuing..."

    chaos_scan "$target" "$tmp"

    grep -E '^[A-Za-z0-9._-]+\.'"$target"'$' "$tmp" | sort -u > "$output"
    success "Found $(wc -l < "$output") unique subdomains"
    success "Output: $output"
}

fuzz_subdomains() {
    local target="$1" fuzz_json="$2"
    local args=(-w "$wordlist" -u "https://FUZZ.$target" -mc all -timeout "$timeout" -of json -o "$fuzz_json" -s)

    [[ "$rate_limit" != 0 ]] && args+=(-rate "$rate_limit")
    [[ "$delay" != 0 ]] && args+=(-p "$delay")
    [[ -n "$identity_header" ]] && args+=(-H "$identity_header")

    info "Fuzzing subdomains..."
    ffuf "${args[@]}" >/dev/null 2>&1 || info "ffuf failed, continuing..."

    if [[ -s "$fuzz_json" ]]; then
        grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' "$fuzz_json" | \
            sed -E 's/.*"url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' | \
            sed -E 's#^https?://##' | sed 's#/.*$##' | \
            grep -E '^[A-Za-z0-9._-]+\.'"$target"'$' | sort -u >> "$output"
    fi
}

dns_scan() {
    local input="$1" ips="$2" resolved="$3"
    local args=(-l "$input" -silent -a -resp -timeout "${timeout}s")

    [[ "$rate_limit" != 0 ]] && args+=(-rl "${rate_limit%.*}")

    info "Resolving subdomains with dnsx..."
    dnsx "${args[@]}" > "$resolved" 2>/dev/null || info "dnsx failed, continuing..."

    grep -oE '\[[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\]' "$resolved" | tr -d '[]' | sort -u > "$ips"
    success "Resolved $(wc -l < "$ips") unique IPv4 addresses"
}

asn_scan() {
    local target="$1" cidrs="$2"
    if ! command -v asnmap >/dev/null 2>&1; then
        info "ASNMap skipped: asnmap is not installed"
        return 0
    fi

    info "Checking ASNMap authentication..."
    if ! asnmap -d "$target" -silent -o "$cidrs" 2>/dev/null; then
        rm -f "$cidrs"
        info "ASN mapping skipped: ASNMap is not authenticated."
        info "Run 'asnmap -auth' once to configure ASNMap."
        return 0
    fi

    if [[ -s "$cidrs" ]]; then
        success "ASN mapping complete"
    else
        info "ASN mapping returned no CIDR ranges"
    fi
}

port_scan() {
    local ips="$1" ports="$2"
    [[ -s "$ips" ]] || { info "Port scan skipped: no resolved IPs"; return 0; }

    local args=(-list "$ips" -silent -timeout "$timeout")
    [[ "$rate_limit" != 0 ]] && args+=(-rate "${rate_limit%.*}")

    info "Scanning ports with naabu..."
    naabu "${args[@]}" > "$ports" 2>/dev/null || info "naabu failed, continuing..."
    sort -u "$ports" -o "$ports"
}

http_scan() {
    local input="$1" http="$2"
    [[ -s "$input" ]] || { info "HTTP probing skipped: no subdomains"; return 0; }

    local args=(-list "$input" -silent -timeout "$timeout" -mc "200-399")
    [[ "$rate_limit" != 0 ]] && args+=(-rate-limit "${rate_limit%.*}")
    [[ "$delay" != 0 ]] && args+=(-delay "${delay}s")
    [[ -n "$identity_header" ]] && args+=(-H "$identity_header")

    info "Probing HTTP services with httpx..."
    httpx "${args[@]}" > "$http" 2>/dev/null || info "httpx failed, continuing..."
    sort -u "$http" -o "$http"
}

active_scan() {
    local target="$1"
    local base="$(mktemp)" ips="$(mktemp)" cidrs="$(mktemp)" ports="$(mktemp)" http="$(mktemp)" resolved="$(mktemp)" fuzz_json="$(mktemp)"

    trap 'rm -f "$base" "$ips" "$cidrs" "$ports" "$http" "$resolved" "$fuzz_json"' RETURN

    info "Starting active enumeration: $target"
    info "Running subfinder..."
    subfinder -d "$target" -silent >> "$base" 2>/dev/null || info "subfinder failed, continuing..."

    chaos_scan "$target" "$base"
    sort -u "$base" -o "$base"
    cp "$base" "$output"

    fuzz_subdomains "$target" "$fuzz_json"
    sort -u "$output" -o "$output"

    success "Subdomain enumeration complete"
    success "Found $(wc -l < "$output") unique subdomains"

    dns_scan "$output" "$ips" "$resolved"
    [[ -s "$ips" ]] && write_if_nonempty "$ips" "$(asset_file ".ips")"

    asn_scan "$target" "$cidrs"
    [[ -s "$cidrs" ]] && write_if_nonempty "$cidrs" "$(asset_file ".cidrs")"

    port_scan "$ips" "$ports"
    [[ -s "$ports" ]] && write_if_nonempty "$ports" "$(asset_file ".ports")"

    if [[ "$httpx_enabled" == true ]]; then
        http_scan "$output" "$http"
        [[ -s "$http" ]] && write_if_nonempty "$http" "$(asset_file ".http")"
    else
        info "HTTP probing skipped: --httpx not enabled"
    fi

    success "Active enumeration complete"
    success "Subdomains: $output"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t) [[ -z "$2" ]] && error "-t requires a target"; target="$2"; shift 2 ;;
        -r) [[ -z "$2" ]] && error "-r requires a value"; rate_limit="$2"; shift 2 ;;
        -d) [[ -z "$2" ]] && error "-d requires a value"; delay="$2"; shift 2 ;;
        -T) [[ -z "$2" ]] && error "-T requires a value"; timeout="$2"; shift 2 ;;
        -a) active=true; shift ;;
        --httpx) httpx_enabled=true; shift ;;
        -H) [[ -z "$2" ]] && error "-H requires a header"; identity_header="$2"; shift 2 ;;
        -o) [[ -z "$2" ]] && error "-o requires an output file"; output="$2"; shift 2 ;;
        -w) [[ -z "$2" ]] && error "-w requires a wordlist"; wordlist="$2"; shift 2 ;;
        -k) [[ -z "$2" ]] && error "-k requires a Chaos API key"; chaos_api_key="$2"; shift 2 ;;
        -h) usage; exit 0 ;;
        *) error "unknown option: $1" ;;
    esac
done

if [[ -z "$chaos_api_key" && -n "${CHAOS_API_KEY:-}" ]]; then
    chaos_api_key="$CHAOS_API_KEY"
fi

validate_args

if [[ -z "$chaos_api_key" ]]; then
    info "Chaos API key not provided, chaos-client will not be used."
fi

check_dependencies
prepare_output

if [[ "$active" == true ]]; then
    active_scan "$target"
else
    passive_scan "$target"
fi