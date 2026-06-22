FROM golang:1.25-alpine AS builder
WORKDIR /src
COPY go.mod .
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o uptest .

# scratch keeps the image under 5 MB — no shell, no OS, just the binary.
FROM scratch
COPY --from=builder /src/uptest /uptest
EXPOSE 8080
ENTRYPOINT ["/uptest"]
