# Third-Party Tools

`subenum` relies on several third-party security tools to perform
subdomain enumeration, DNS resolution, fuzzing, port scanning, and
HTTP probing.

## Required

- `subfinder`

## Optional

- `chaos-client`
- `asnmap`

## Active Mode

The following tools are required when using `-a`:

- `dnsx`
- `ffuf`
- `naabu`

`httpx` is optional and is only used when `--httpx` is provided.

## Third-Party Tool Usage

`subenum` acts as an orchestration layer around these external tools.
It does not replace or reimplement their functionality.

The results produced by `subenum` depend on the availability and
behavior of the underlying third-party tools.

### Tools Used

```
| Tool            | Purpose                              | Required    |
|-----------------|--------------------------------------|-------------|
| subfinder       | Passive subdomain enumeration        | Yes         |
| chaos-client    | Chaos passive subdomain enumeration  | Optional    |
| asnmap          | ASN and CIDR mapping                 | Optional    |
| dnsx            | DNS resolution                       | Active mode |
| ffuf            | Subdomain fuzzing                    | Active mode |
| naabu           | Port scanning                        | Active mode |
| httpx           | HTTP service probing                 | --httpx     |
```

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

`
╔══════════╦════════════════════════════════════════════════════════════════╗
║ Flags    ║ Description                                                    ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -t       ║ Target you want to scan (e.g: example.com)                     ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -w       ║ Subdomain wordlist (format: one subdomain per line).           ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -r       ║ Rate limit (requests/second, default: 0)                       ║
╠══════════╬════════════════════════════════════════════════════════════════╣
║ -d       ║ Delay between requests (seconds, default: 0)                   ║
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
`