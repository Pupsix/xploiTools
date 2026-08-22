# Third-Party Tools

`subenum` relies on several third-party security tools to perform
subdomain enumeration, DNS resolution, fuzzing, port scanning, and
HTTP probing.

## Required

The following tools are required for `subenum`:

- `subfinder` — passive subdomain enumeration
- `dnsx` — DNS resolution
- `ffuf` — subdomain fuzzing
- `naabu` — port scanning

## Optional

The following tools are optional:

- `chaos-client` — additional passive subdomain enumeration
- `asnmap` — ASN and CIDR mapping
- `httpx` — HTTP service probing, enabled with `--httpx`

> `chaos-client` and `asnmap` are optional because `subenum` can
> continue without them. If they are unavailable or not configured,
> the corresponding steps are skipped.

## Third-Party Tool Usage

`subenum` acts as an orchestration layer around these external tools.
It does not replace or reimplement their functionality.

The results produced by `subenum` depend on the availability and
behavior of the underlying third-party tools.

### Tools Used

| Tool           | Purpose                            | Status   |
|----------------|------------------------------------|----------|
| `subfinder`    | Passive subdomain enumeration      | Required |
| `chaos-client` | Additional passive enumeration     | Optional |
| `asnmap`       | ASN and CIDR mapping               | Optional |
| `dnsx`         | DNS resolution                     | Required |
| `ffuf`         | Subdomain fuzzing                  | Required |
| `naabu`        | Port scanning                      | Required |
| `httpx`        | HTTP service probing               | Optional |

## Chaos API Key

You can provide the Chaos API key directly:

`subenum -t example.com -k "your_api_key"`

Or through an environment variable:

`export CHAOS_API_KEY="your_api_key"`

If both are provided, `-k` takes priority.

If no Chaos API key is provided, `chaos-client` is skipped.

## ASNMap

`asnmap` uses a ProjectDiscovery Cloud Platform API key.

Configure it once:

`asnmap -auth`

After authentication, `subenum` can use `asnmap` automatically.

If `asnmap` is not installed or has not been authenticated,
ASN mapping is skipped.

## Usage

╔══════════╦════════════════════════════════════════════════════════════════╗
║ Flags    ║ Description                                                    ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -t       ║ Target you want to scan (e.g: example.com)                     ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -w       ║ Subdomain wordlist (format: one subdomain per line).           ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -r       ║ Rate limit (requests/second, default: 0)                       ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -d       ║ Delay between requests (seconds, default: 0)                    ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -T       ║ Request timeout (seconds, default: 5)                          ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -a       ║ Active scan (default: passive)                                 ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -H       ║ Identity header (e.g: X-HackerOne: abc)                        ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -o       ║ Output file (e.g: result.txt or ../output/result.txt)          ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -k       ║ Chaos API key (optional)                                       ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ --httpx  ║ Run httpx (optional)                                           ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -h       ║ Show this help message                                         ║
╚══════════╩════════════════════════════════════════════════════════════════╝
