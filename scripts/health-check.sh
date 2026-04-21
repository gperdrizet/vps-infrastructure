#!/bin/bash
#
# VPS Health Check Script
# Verifies that all services are running and healthy
#
# Usage: ./health-check.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0

check_container() {
    local container=$1
    local required=${2:-true}
    
    TOTAL=$((TOTAL + 1))
    
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        local running=$(docker inspect --format='{{.State.Running}}' "$container")
        
        if [[ "$running" == "true" ]]; then
            if [[ "$status" == "healthy" ]] || [[ "$status" == "none" ]]; then
                echo -e "${GREEN}[OK]${NC} $container is running"
                PASSED=$((PASSED + 1))
            else
                echo -e "${YELLOW}[WARN]${NC} $container is running but status: $status"
                WARNINGS=$((WARNINGS + 1))
            fi
        else
            echo -e "${RED}[ERROR]${NC} $container exists but not running"
            FAILED=$((FAILED + 1))
        fi
    else
        if [[ "$required" == "true" ]]; then
            echo -e "${RED}[ERROR]${NC} $container not found"
            FAILED=$((FAILED + 1))
        else
            echo -e "${BLUE}[INFO]${NC} $container not found (optional)"
            PASSED=$((PASSED + 1))
        fi
    fi
}

check_http_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    TOTAL=$((TOTAL + 1))
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected_code" ]]; then
        echo -e "${GREEN}[OK]${NC} $name responds with HTTP $response"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}[ERROR]${NC} $name responds with HTTP $response (expected $expected_code)"
        FAILED=$((FAILED + 1))
    fi
}

check_port() {
    local name=$1
    local host=$2
    local port=$3
    
    TOTAL=$((TOTAL + 1))
    
    if nc -z -w 2 "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}[OK]${NC} $name port $port is open on $host"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}[ERROR]${NC} $name port $port is not accessible on $host"
        FAILED=$((FAILED + 1))
    fi
}

main() {
    echo "----------------------------------------"
    echo "  VPS Health Check"
    echo "----------------------------------------"
    echo ""
    
    echo "=== Core Containers ==="
    check_container "monitoring-prometheus"
    check_container "monitoring-grafana"
    check_container "monitoring-alertmanager"
    check_container "monitoring-loki"
    check_container "monitoring-promtail"
    check_container "monitoring-blackbox-exporter"
    check_container "monitoring-node-exporter"
    check_container "monitoring-cadvisor"
    echo ""
    
    echo "=== Application Containers ==="
    check_container "logkeep-blue" false
    check_container "logkeep-green" false
    check_container "logkeep-staging" false
    check_container "logkeep-postgres" false
    check_container "bench-web" false
    check_container "bench-celery" false
    check_container "bench-celery-beat" false
    check_container "bench-postgres" false
    check_container "bench-redis" false
    echo ""
    
    echo "=== HTTP Endpoints ==="
    check_http_endpoint "Prometheus" "http://localhost:9090/-/healthy"
    check_http_endpoint "Grafana" "http://localhost:3000/api/health"
    check_http_endpoint "Alertmanager" "http://localhost:9093/-/healthy"
    check_http_endpoint "Loki" "http://localhost:3100/ready"
    echo ""
    
    echo "=== Network Connectivity ==="
    check_port "Pyrite PostgreSQL" "100.64.0.2" 5432
    check_port "Pyrite llama.cpp" "100.64.0.2" 8502
    echo ""
    
    echo "=== Summary ==="
    echo -e "Total checks: $TOTAL"
    echo -e "${GREEN}Passed:${NC} $PASSED"
    
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
    fi
    
    if [[ $FAILED -gt 0 ]]; then
        echo -e "${RED}Failed:${NC} $FAILED"
        echo ""
        exit 1
    else
        echo ""
        echo -e "${GREEN}✓ All checks passed!${NC}"
        exit 0
    fi
}

main "$@"
