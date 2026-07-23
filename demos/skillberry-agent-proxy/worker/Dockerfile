FROM python:3.11-slim

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone https://github.com/skillberry-ai/skillberry-agent-praxis-poc.git .
RUN pip install --no-cache-dir ./worker/

EXPOSE 7010
CMD ["uvicorn", "worker.main:app", "--host", "0.0.0.0", "--port", "7010"]
