# syntax=docker/dockerfile:1

FROM python:3.13-alpine

WORKDIR /app

# hadolint ignore=DL3018
RUN apk add --no-cache gcc musl-dev linux-headers

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

ENV PORT=8080
ENV CPU_PERCENT=80
ENV RAM_PERCENT=0
ENV BURN_DURATION=30

EXPOSE 8080

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "8", "app:app"]
