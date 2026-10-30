#!/usr/bin/env python3
"""Week 8 release gate: ask the deployed bank assistant the golden questions and
fail if any answer breaks a rule. Standard library only, so it runs on a bare VM.

Usage:  python3 eval_gate.py --url https://<app-fqdn> --cases release-gate.json
Exit code 0 = gate passed, 1 = gate failed.
"""
import argparse
import json
import sys
import time
import urllib.request


def ask(url: str, question: str, timeout: int = 90) -> str:
    req = urllib.request.Request(
        url.rstrip("/") + "/ask",
        data=json.dumps({"question": question}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp).get("answer", "")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--url", required=True)
    p.add_argument("--cases", required=True)
    args = p.parse_args()

    cases = json.load(open(args.cases))["cases"]
    results = []
    for c in cases:
        try:
            answer = ask(args.url, c["question"])
        except Exception as e:  # network errors fail the case, never crash the gate
            answer = f"ERROR: {e}"
        low = answer.lower()
        missing = [s for s in c.get("must_contain", []) if s.lower() not in low]
        forbidden = [s for s in c.get("must_not_contain", []) if s.lower() in low]
        ok = not missing and not forbidden and not answer.startswith("ERROR")
        results.append({"id": c["id"], "pass": ok, "missing": missing, "forbidden": forbidden, "answer": answer[:200]})
        print(("PASS " if ok else "FAIL ") + c["id"] + ("" if ok else f"  missing={missing} forbidden={forbidden} answer={answer[:120]!r}"))
        time.sleep(1)  # stay under the gateway's token limit

    passed = sum(r["pass"] for r in results)
    print(f"\nRELEASE GATE: {passed}/{len(results)} passed -> {'GO' if passed == len(results) else 'NO-GO'}")
    # Keep output short: az vm run-command returns only the last 4,096 characters.
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
