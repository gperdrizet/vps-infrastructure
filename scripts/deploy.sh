#!/bin/bash
#
# VPS Deployment Script
# Deploys infrastructure and application services
#
# Usage: ./deploy.sh [service]
#   service: all, core, logkeep, bench, monitoring (default: all)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="${1:-all}"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Pre-deployment checks
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if .env exists
    if [[ ! -f "$REPO_DIR/.env" ]]; then
        log_error ".env file not found. Copy .env.template and configure it."
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check docker compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Deploy core infrastructure
deploy_core() {
    log_info "Deploying core infrastructure..."
    
    cd "$REPO_DIR"
    docker compose -f docker-compose.core.yml up -d
    
    log_success "Core infrastructure deployed"
}

# Deploy LogKeep
deploy_logkeep() {
    log_info "Deploying LogKeep..."
    
    if [[ -d "/opt/logkeep/docker" ]]; then
        cd /opt/logkeep/docker
        docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
        log_success "LogKeep deployed"
    else
        log_warn "LogKeep directory not found, skipping"
    fi
}

# Deploy Bench
deploy_bench() {
    log_info "Deploying Bench..."
    
    if [[ -d "/opt/bench/docker" ]]; then
        cd /opt/bench/docker
        docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
        log_success "Bench deployed"
    else
        log_warn "Bench directory not found, skipping"
    fi
}

# Deploy monitoring only
deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    
    cd "$REPO_DIR"
    docker compose -f docker-compose.core.yml up -d prometheus grafana alertmanager loki promtail blackbox-exporter node-exporter cadvisor
    
    log_success "Monitoring stack deployed"
}

# Main deployment logic
main() {
    echo "----------------------------------------"
    echo "  VPS Infrastructure Deployment"
    echo "----------------------------------------"
    echo ""
    
    check_prerequisites
    
    case "$SERVICE" in
        all)
            deploycore()
            deploy_logkeep()
            deploy_bench()
            ;;
        core)
            deploy_core()
            ;;
        monitoring)
            deploy_monitoring()
            ;;
        logkeep)
            deploy_logkeep()
            ;;
        bench)
            deploy_bench()
            ;;
        *)
            log_error "Unknown service: $SERVICE"
            echo "Usage: $0 [all|core|monitoring|logkeep|bench]"
            exit 1
            ;;
    esac
    
    echo ""
    echo "----------------------------------------"
    log_success "Deployment complete!"
    echo "----------------------------------------"
    echo ""
    log_info "Run './scripts/health-check.sh' to verify services"
}

main "$@"
