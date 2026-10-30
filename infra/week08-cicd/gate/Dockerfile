# The release gate as a container: runs the golden questions against the app.
# It runs as a Cloud Run job INSIDE the VPC, because the app only accepts
# internal traffic. Built by Cloud Build (make week8-image), no Docker needed.
FROM python:3.12-slim
COPY scripts/eval_gate.py evals/release-gate.json /gate/
ENTRYPOINT ["python3", "/gate/eval_gate.py", "--cases", "/gate/release-gate.json"]
