# 3nricher

[![tests](https://github.com/nullbyte-sec/3nricher-nullbyte-sec/actions/workflows/test.yml/badge.svg)](https://github.com/nullbyte-sec/3nricher-nullbyte-sec/actions/workflows/test.yml)
[![python](https://img.shields.io/badge/python-3.10%2B-blue)](https://www.python.org/)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**Multi-source IOC enrichment pipeline with MITRE ATT&CK mapping and a web GUI.**

3nricher takes Indicators of Compromise (IPs, domains, file hashes), enriches them
against nine threat intelligence sources in parallel, applies weighted risk scoring
with a per-source rationale, and maps detected malware families to MITRE ATT&CK
techniques.

Includes a one-command web GUI: clone, add your API keys, run `./3nricher.sh`, and a browser dashboard opens with live enrichment logs, risk scoring, source breakdowns, and IP geolocation.

## One-command setup (web GUI)

Requires git, Python 3.10+, Node.js 18+ with npm, Docker (running), and make.

```bash
git clone https://github.com/nullbyte-sec/3nricher-nullbyte-sec.git
cd 3nricher-nullbyte-sec
chmod +x 3nricher.sh
./3nricher.sh
```

First run:

1. Creates a Python virtual environment and installs dependencies
2. Creates `.env` from `.env.example`
3. Stops and asks you to add your API keys:

```bash
nano .env
```

4. Run it again:

```bash
./3nricher.sh
```

It then clones the [web GUI](https://github.com/nullbyte-sec/3nricher-gui), installs its npm dependencies, starts the Flask backend on `http://127.0.0.1:5001`, starts the Vite dev server, and opens `http://localhost:5173` in your browser.

Press `Ctrl+C` to stop both the backend and the GUI.

## Web GUI

The web GUI lives in its own repository: [nullbyte-sec/3nricher-gui](https://github.com/nullbyte-sec/3nricher-gui).

- React + Vite + Tailwind CSS dashboard
- Enter an IP, domain, or hash and click **Run Enrichment**
- Live terminal view streams the full Docker build and enrichment output
- Overview tab shows the risk score, confidence, per-source results, and IP geolocation
- The Flask SSE backend (`server.py` in this repo) runs `make build query IOC=<target>` and streams output to the browser in real time

Manual setup (without the launcher):

```bash
# Terminal 1 - backend
source venv/bin/activate
python3 server.py

# Terminal 2 - GUI
cd ../3nricher-gui
npm install
npm run dev
```

## Configuration

3nricher needs **your own** API keys. Threat intelligence provider terms prohibit
key sharing, and free-tier limits apply per key, so keys are not bundled.

| Source | Sign up | Free tier | Required |
|--------|---------|-----------|----------|
| VirusTotal | https://www.virustotal.com/gui/my-apikey | 4 req/min, 500/day | Yes |
| AbuseIPDB | https://www.abuseipdb.com/account/api | 1,000/day | No |
| abuse.ch (MalwareBazaar, URLhaus, ThreatFox, Feodo) | https://auth.abuse.ch/ | Reasonable use | No |
| AlienVault OTX | https://otx.alienvault.com/ | 10,000/day | No |
| GreyNoise | https://viz.greynoise.io/account/ | 50/week | No |
| IPinfo | https://ipinfo.io/account/token | Unlimited Lite, 50,000/month Core | No |

Create a `.env` file in the repository root (the launcher does this for you):

```ini
VT_API_KEY=your_virustotal_key_here
ABUSE_API_KEY=your_abuseipdb_key_here
ABUSE_CH_API_KEY=your_abuse_ch_key_here
OTX_API_KEY=your_otx_key_here
GREYNOISE_API_KEY=your_greynoise_key_here
IPINFO_API_KEY=your_ipinfo_token_here
LOG_LEVEL=INFO
CACHE_ENABLED=true
CACHE_TTL_HOURS=24
CACHE_PATH=cache/3nricher
DB_PATH=data/3nricher.db
```

Sources without a key are skipped. Only VirusTotal is required.

## CLI usage

### Query a single IOC

```bash
3nricher query 8.8.8.8
3nricher query google.com
3nricher query 84c82835a5d21bbcf75a61706d8ab549
```

### Enrich a file of IOCs

```bash
3nricher enrich -f iocs.txt -o report
```

Writes `report.json` and `report.csv`.

## Sources

| Source | IOC types | Purpose |
|--------|-----------|---------|
| [VirusTotal](https://www.virustotal.com/) | IP, domain, hash | AV verdicts across ~70 engines |
| [AbuseIPDB](https://www.abuseipdb.com/) | IP | Abuse confidence, ISP, geolocation |
| [MalwareBazaar](https://bazaar.abuse.ch/) | Hash | Malware family, tags, first seen |
| [URLhaus](https://urlhaus.abuse.ch/) | Domain, IP | Malicious URL hosting |
| [AlienVault OTX](https://otx.alienvault.com/) | IP, domain, hash | Community threat pulses |
| [GreyNoise](https://www.greynoise.io/) | IP | Mass scanner vs. targeted activity |
| [ThreatFox](https://threatfox.abuse.ch/) | IP, domain, hash | Malware C2 tracking |
| [Feodo Tracker](https://feodotracker.abuse.ch/) | IP | Botnet C2 blocklist |
| [IPinfo](https://ipinfo.io/) | IP | ASN, organization, geolocation, freshness |

## IP Freshness and Geolocation

IPs get a freshness score based on ASN reputation via IPinfo:

- **Bulletproof-hosting ASNs** (M247, Selectel, FlokiNET, and similar) score **0**
  and are flagged `bulletproof_asn`.
- All other IPs score **50**.
- The CLI freshness line shows ASN, organization, city/region/country, and
  lat/long coordinates.

## Risk Scoring

Each IOC gets a weighted score from 0 to 100.

| Score | Label | Suggested action |
|-------|-------|------------------|
| 70-100 | Critical | Block and investigate |
| 45-69 | High | Investigate |
| 20-44 | Medium | Monitor |
| 0-19 | Low | Log |

## Docker

Use the included Makefile. Make sure the Docker daemon is running:

```bash
sudo systemctl start docker
make build
make query IOC=8.8.8.8
make test
```

## Architecture

```text
3nricher.py            CLI orchestrator
enrichment.py          Parallel and sequential dispatcher
scoring.py             Weighted risk scoring
freshness.py           IP ASN freshness scoring
server.py              Flask SSE backend for the web GUI
3nricher.sh            One-command setup and launch script

sources/               9 source modules
storage/               SQLite cache and enrichment history
attck_mappings/        YAML mappings
tests/                 207 tests
```

## Testing

```bash
python -m pytest -v
```

## License

Released under the [MIT License](LICENSE).

## Acknowledgments

- [VirusTotal](https://www.virustotal.com/): malware intelligence
- [AbuseIPDB](https://www.abuseipdb.com/): IP reputation
- [abuse.ch](https://abuse.ch/): MalwareBazaar, URLhaus, ThreatFox, Feodo Tracker
- [AlienVault OTX](https://otx.alienvault.com/): community threat intelligence
- [GreyNoise](https://www.greynoise.io/): scanner classification
- [IPinfo](https://ipinfo.io/): IP geolocation and ASN data
- [MITRE ATT&CK](https://attack.mitre.org/): technique framework
