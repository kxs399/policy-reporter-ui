#!/bin/bash

# Policy Reporter UI Development Environment Setup Script
# This script sets up a complete development environment with:
# - k3d Kubernetes cluster
# - Policy Reporter Core
# - Policy Reporter UI Backend  
# - Policy Reporter UI Frontend
# - Sample PolicyReport data for testing

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
CLUSTER_NAME="policy-reporter-dev"
POLICY_REPORTER_CORE_PORT=8081
UI_BACKEND_PORT=8082
UI_FRONTEND_PORT=3000

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    if ! command -v go &> /dev/null; then
        missing+=("go")
    fi
    
    if ! command -v bun &> /dev/null; then
        missing+=("bun")
    fi
    
    if ! command -v k3d &> /dev/null; then
        missing+=("k3d")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Please install the missing tools and run the script again"
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

# Check if we're in the right directory
check_directory() {
    if [ ! -d "backend" ] || [ ! -d "frontend" ]; then
        log_error "Please run this script from the policy-reporter-ui root directory"
        log_info "Expected structure: policy-reporter-ui/{backend,frontend}"
        exit 1
    fi
    log_success "Running from correct directory"
}

# Create k3d cluster
setup_k3d_cluster() {
    log_info "Setting up k3d cluster: $CLUSTER_NAME"
    
    # Check if cluster already exists
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        log_warning "Cluster $CLUSTER_NAME already exists"
        read -p "Do you want to delete and recreate it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            k3d cluster delete $CLUSTER_NAME
        else
            log_info "Using existing cluster"
            kubectl config use-context k3d-$CLUSTER_NAME
            return
        fi
    fi
    
    # Create cluster
    k3d cluster create $CLUSTER_NAME \
        --port "8080:30080@loadbalancer" \
        --port "8443:30443@loadbalancer" \
        --agents 1
    
    # Set context
    kubectl config use-context k3d-$CLUSTER_NAME
    
    log_success "k3d cluster created and configured"
}

# Install PolicyReport CRDs
install_crds() {
    log_info "Installing PolicyReport CRDs..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/wg-policy-prototypes/master/policy-report/crd/v1alpha2/wgpolicyk8s.io_policyreports.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/wg-policy-prototypes/master/policy-report/crd/v1alpha2/wgpolicyk8s.io_clusterpolicyreports.yaml
    
    log_success "PolicyReport CRDs installed"
}

# Create sample PolicyReport data
create_sample_data() {
    log_info "Creating sample PolicyReport data..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: kyverno-sample-report
  namespace: default
spec: {}
status:
  results:
  - policy: disallow-privileged-containers
    rule: check-privileged
    message: "Privileged containers are not allowed"
    result: fail
    severity: critical
    category: Security
    source: kyverno
    scored: true
    resources:
    - apiVersion: v1
      kind: Pod
      name: nginx-privileged
      namespace: default
  - policy: require-labels
    rule: check-labels
    message: "Required label 'app' is missing"
    result: fail
    severity: medium
    category: Best Practices
    source: kyverno
    scored: true
    resources:
    - apiVersion: v1
      kind: Pod
      name: unlabeled-pod
      namespace: default
  - policy: require-pod-security-standards
    rule: baseline
    message: "Pod does not meet baseline security standards"
    result: fail
    severity: high
    category: Pod Security Standards
    source: kyverno
    scored: true
    resources:
    - apiVersion: v1
      kind: Pod
      name: insecure-pod
      namespace: default
EOF
    
    log_success "Sample PolicyReport created"
}

# Setup backend configuration
setup_backend_config() {
    log_info "Setting up backend configuration..."
    
    if [ ! -f "backend/config.yaml" ]; then
        cat > backend/config.yaml <<EOF
clusters:
- name: Default
  host: http://localhost:$POLICY_REPORTER_CORE_PORT

server:
  cors: true
  overwriteHost: true

tempDir: /tmp
EOF
        log_success "Backend config.yaml created"
    else
        log_warning "Backend config.yaml already exists"
    fi
}

# Setup frontend configuration  
setup_frontend_config() {
    log_info "Setting up frontend configuration..."
    
    if [ ! -f "frontend/.env" ]; then
        cat > frontend/.env <<EOF
NUXT_PUBLIC_CORE_API=http://localhost:$UI_BACKEND_PORT
EOF
        log_success "Frontend .env created"
    else
        log_warning "Frontend .env already exists"
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing Go dependencies for backend..."
    cd backend && go mod download && cd ..
    
    log_info "Installing frontend dependencies..."
    cd frontend && bun install && cd ..
    
    log_success "Dependencies installed"
}

# Check if Policy Reporter Core exists
check_policy_reporter_core() {
    local core_path="../policy-reporter"
    if [ ! -d "$core_path" ]; then
        log_error "Policy Reporter Core not found at $core_path"
        log_info "Please clone the policy-reporter repository:"
        log_info "git clone https://github.com/kyverno/policy-reporter.git ../policy-reporter"
        exit 1
    fi
    log_success "Policy Reporter Core found"
}

# Create startup script
create_startup_script() {
    log_info "Creating startup script..."
    
    cat > start-dev-services.sh <<'EOF'
#!/bin/bash

# Start all development services for Policy Reporter UI
# Run this script to start the complete development stack

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if k3d cluster is running
if ! kubectl cluster-info &> /dev/null; then
    log_info "Starting k3d cluster..."
    k3d cluster start policy-reporter-dev
    kubectl config use-context k3d-policy-reporter-dev
fi

log_info "Starting development services..."
log_info "Press Ctrl+C to stop all services"

# Function to kill all background processes on exit
cleanup() {
    log_info "Stopping all services..."
    jobs -p | xargs -r kill
    exit 0
}
trap cleanup EXIT INT TERM

# Start Policy Reporter Core
cd ../policy-reporter
log_info "Starting Policy Reporter Core on port 8081..."
go run main.go run --kubeconfig ~/.kube/config --port 8081 --rest-enabled --metrics-enabled --dbfile ":memory:" &
CORE_PID=$!

# Wait a moment for core to start
sleep 3

# Start UI Backend
cd ../policy-reporter-ui/backend
log_info "Starting Policy Reporter UI Backend on port 8082..."
go run main.go run --port 8082 &
BACKEND_PID=$!

# Wait a moment for backend to start
sleep 3

# Start Frontend
cd ../frontend
log_info "Starting Policy Reporter UI Frontend on port 3000..."
bun run dev &
FRONTEND_PID=$!

log_success "All services started!"
echo ""
echo "🚀 Policy Reporter UI Development Environment Ready!"
echo ""
echo "📊 Frontend:  http://localhost:3000"
echo "🔧 Backend:   http://localhost:8082/healthz"
echo "💾 Core API:  http://localhost:8081/healthz"
echo ""
echo "🧪 Test API endpoints:"
echo "curl http://localhost:8082/proxy/default/core/v2/namespaces"
echo "curl http://localhost:8082/proxy/default/core/v2/policies"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for all background processes
wait
EOF

    chmod +x start-dev-services.sh
    log_success "Startup script created: start-dev-services.sh"
}

# Create test script
create_test_script() {
    log_info "Creating test script..."
    
    cat > test-environment.sh <<'EOF'
#!/bin/bash

# Test script for Policy Reporter UI development environment

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

test_endpoint() {
    local url=$1
    local description=$2
    
    echo -n "Testing $description... "
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|404"; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

echo "🧪 Testing Policy Reporter UI Development Environment"
echo ""

# Test services
test_endpoint "http://localhost:8081/healthz" "Policy Reporter Core health"
test_endpoint "http://localhost:8082/healthz" "UI Backend health"  
test_endpoint "http://localhost:3000" "Frontend"

echo ""
echo "🔍 Testing API endpoints:"
test_endpoint "http://localhost:8082/proxy/default/core/v2/namespaces" "Namespaces API"
test_endpoint "http://localhost:8082/proxy/default/core/v2/policies" "Policies API"
test_endpoint "http://localhost:8082/api/config/default/layout" "Layout API"

echo ""
echo "📊 Sample API responses:"
echo ""
echo -e "${BLUE}Namespaces:${NC}"
curl -s http://localhost:8082/proxy/default/core/v2/namespaces | jq 2>/dev/null || curl -s http://localhost:8082/proxy/default/core/v2/namespaces
echo ""
echo ""
echo -e "${BLUE}Policies:${NC}"
curl -s http://localhost:8082/proxy/default/core/v2/policies | jq 2>/dev/null || curl -s http://localhost:8082/proxy/default/core/v2/policies
echo ""
EOF

    chmod +x test-environment.sh
    log_success "Test script created: test-environment.sh"
}

# Main setup function
main() {
    echo "🚀 Policy Reporter UI Development Environment Setup"
    echo "=================================================="
    echo ""
    
    check_prerequisites
    check_directory
    check_policy_reporter_core
    
    setup_k3d_cluster
    install_crds
    create_sample_data
    
    setup_backend_config
    setup_frontend_config
    install_dependencies
    
    create_startup_script
    create_test_script
    
    echo ""
    log_success "🎉 Development environment setup complete!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Start all services: ./start-dev-services.sh"
    echo "2. Test environment: ./test-environment.sh" 
    echo "3. Open browser: http://localhost:3000"
    echo ""
    echo "🔧 Development workflow:"
    echo "- Edit Go code in backend/ - auto-reloads"
    echo "- Edit Vue.js code in frontend/ - auto-reloads"
    echo "- Test APIs via http://localhost:8082/proxy/default/core/v2/*"
    echo ""
    echo "📚 Useful commands:"
    echo "- kubectl get policyreports -A"
    echo "- k3d cluster list"
    echo "- curl http://localhost:8082/proxy/default/core/v2/policies"
}

# Run main function
main "$@"