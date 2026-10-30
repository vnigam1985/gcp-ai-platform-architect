# The AI gateway image: LiteLLM plus our config. Built by Cloud Build
# (make week4-image) into your Artifact Registry. No Docker needed on your laptop.
FROM ghcr.io/berriai/litellm:main-stable
COPY config.yaml /app/config.yaml
CMD ["--config", "/app/config.yaml", "--port", "8080"]
