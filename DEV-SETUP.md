# Policy Reporter UI Development Environment

This repository contains the Policy Reporter UI frontend and backend, plus automated scripts to set up a complete development environment.

## 🚀 Quick Setup

### Prerequisites
- **Go** >= 1.22.4
- **Bun** (JavaScript package manager)
- **k3d** (Kubernetes in Docker)
- **kubectl** (Kubernetes CLI)
- **Docker Desktop** (running)

### One-Command Setup
```bash
# Make the script executable and run it
chmod +x setup-dev-environment.sh
./setup-dev-environment.sh
```

This script will:
- ✅ Create k3d Kubernetes cluster with sample data
- ✅ Install PolicyReport CRDs
- ✅ Configure backend and frontend
- ✅ Install all dependencies
- ✅ Create startup and test scripts

## 🏃 Running the Development Environment

### Start All Services
```bash
./start-dev-services.sh
```

This starts:
- **Policy Reporter Core** on port 8081
- **UI Backend** on port 8082  
- **UI Frontend** on port 3000

### Test the Environment
```bash
./test-environment.sh
```

### Access the Application
- **Frontend UI**: http://localhost:3000
- **Backend API**: http://localhost:8082/healthz
- **Core Health**: http://localhost:8081/healthz

## 🧪 API Testing

### Working API Endpoints
```bash
# Get namespaces
curl http://localhost:8082/proxy/default/core/v2/namespaces

# Get policies with violations
curl http://localhost:8082/proxy/default/core/v2/policies

# Get UI configuration
curl http://localhost:8082/api/config/default/layout
```

## 🛠️ Development Workflow

### Backend Development (Go)
```bash
cd backend/
# Edit Go files - auto-reloads with go run
go run main.go run --port 8082
```

### Frontend Development (Vue.js/Nuxt.js)
```bash
cd frontend/
# Edit Vue.js files - auto-reloads with Bun
bun run dev
```

### Kubernetes Testing
```bash
# View sample policy reports
kubectl get policyreports -A

# Check cluster status
kubectl cluster-info

# View cluster resources
k3d cluster list
```

## 📊 Sample Data

The setup creates sample PolicyReport data with violations:
- **disallow-privileged-containers** (Security, Critical)
- **require-labels** (Best Practices, Medium)  
- **require-pod-security-standards** (Pod Security Standards, High)

## 🔧 Manual Setup (Alternative)

If you prefer manual setup, follow these steps:

### 1. Create k3d Cluster
```bash
k3d cluster create policy-reporter-dev --agents 1
kubectl config use-context k3d-policy-reporter-dev
```

### 2. Install CRDs
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/wg-policy-prototypes/master/policy-report/crd/v1alpha2/wgpolicyk8s.io_policyreports.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/wg-policy-prototypes/master/policy-report/crd/v1alpha2/wgpolicyk8s.io_clusterpolicyreports.yaml
```

### 3. Start Services
```bash
# Terminal 1: Policy Reporter Core
cd ../policy-reporter
go run main.go run --kubeconfig ~/.kube/config --port 8081 --rest-enabled --metrics-enabled --dbfile ":memory:"

# Terminal 2: UI Backend  
cd backend/
go run main.go run --port 8082

# Terminal 3: Frontend
cd frontend/
bun run dev
```

## 🐛 Troubleshooting

### Port Conflicts
If ports are in use, modify these in the scripts:
- Policy Reporter Core: `--port 8081`
- UI Backend: `--port 8082`
- Frontend: `bun run dev --port 3001`

### Node.js Version Issues
```bash
# Use Node.js v20+ for frontend compatibility
nvm use 20
```

### Cluster Issues
```bash
# Restart cluster
k3d cluster stop policy-reporter-dev
k3d cluster start policy-reporter-dev
```

## 📚 Project Structure

```
policy-reporter-ui/
├── backend/                 # Go backend (Gin framework)
│   ├── cmd/                # CLI commands
│   ├── pkg/                # Go packages
│   └── config.yaml         # Backend configuration
├── frontend/               # Vue.js frontend (Nuxt.js)
│   ├── components/         # Vue components
│   ├── pages/             # Application pages
│   └── .env               # Frontend configuration
├── setup-dev-environment.sh  # Automated setup script
├── start-dev-services.sh    # Service startup script
└── test-environment.sh      # Environment testing script
```

## 🎯 Ready to Develop!

Your development environment includes:
- ✅ **Full-stack application** running locally
- ✅ **Real Kubernetes data** from k3d cluster
- ✅ **Hot reloading** for both frontend and backend
- ✅ **Working API endpoints** for testing
- ✅ **Sample policy violations** for development

Happy coding! 🚀