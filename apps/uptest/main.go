package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
)

func clientIP(r *http.Request) string {
	// X-Forwarded-For is set by the nginx LB and may be a comma-separated list;
	// the first entry is the original client IP.
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return strings.TrimSpace(strings.SplitN(xff, ",", 2)[0])
	}
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return strings.TrimSpace(xri)
	}
	// Strip port from RemoteAddr as a last resort.
	addr := r.RemoteAddr
	if i := strings.LastIndex(addr, ":"); i >= 0 {
		addr = addr[:i]
	}
	return strings.Trim(addr, "[]")
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	ip := clientIP(r)
	pod := os.Getenv("POD_NAME")
	if pod == "" {
		pod = "unknown"
	}
	cluster := os.Getenv("CLUSTER_NAME")
	if cluster == "" {
		cluster = "unknown"
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>uptest</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: "Courier New", monospace;
      background: #0d0d0d;
      color: #c9c9c9;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
    }
    .card {
      background: #1e1e2e;
      border: 1px solid #313244;
      border-radius: 6px;
      padding: 2.5rem 3.5rem;
      text-align: center;
      max-width: 480px;
      width: 100%%;
    }
    .label { color: #cdd6f4; font-size: .75rem; letter-spacing: .12em; text-transform: uppercase; }
    .ip {
      font-size: 2.25rem;
      font-weight: bold;
      color: #a6e3a1;
      margin: 1rem 0 .5rem;
      word-break: break-all;
    }
    .status { color: #a6e3a1; font-size: .85rem; margin-top: 1.5rem; }
    .meta { color: #cdd6f4; font-size: .7rem; margin-top: 2rem; border-top: 1px solid #585b70; padding-top: 1rem; }
  </style>
</head>
<body>
  <div class="card">
    <div class="label">your public ip address</div>
    <div class="ip">%s</div>
    <div class="status">&#10003; cluster is up</div>
    <div class="meta">cluster&nbsp;/&nbsp;%s &nbsp;&bull;&nbsp; pod&nbsp;/&nbsp;%s</div>
  </div>
</body>
</html>
`, ip, cluster, pod)
}

func handleHealthCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", handleHealthCheck)
	mux.HandleFunc("/", handleRoot)

	addr := ":8080"
	log.Printf("uptest listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
