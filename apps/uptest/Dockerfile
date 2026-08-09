FROM golang:1.25-alpine AS builder
WORKDIR /src
COPY go.mod .
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o uptest .

# checkov:skip=CKV_DOCKER_2: kubelet drives liveness/readinessProbe (see k8s/apps/*/uptest/deployment.yaml), not Docker HEALTHCHECK -- and scratch has no shell/curl to run one with
# scratch keeps the image under 5 MB — no shell, no OS, just the binary.
FROM scratch
COPY --from=builder /src/uptest /uptest
EXPOSE 8080
# No /etc/passwd on scratch, but a numeric UID doesn't need one.
USER 65532:65532
ENTRYPOINT ["/uptest"]
