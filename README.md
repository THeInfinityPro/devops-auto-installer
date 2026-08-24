# 🚀 DevOps Auto Installer

A Bash-based automation tool that installs, configures, verifies, and removes a complete DevOps environment on Ubuntu.

The project provides a simple interactive menu for managing commonly used DevOps tools:

- 🐳 Docker
- ☸️ Kubernetes
- 🔧 Jenkins
- 📊 Prometheus
- 📈 Grafana

---

## 📌 Features

- Interactive menu-driven installer
- Automated installation of DevOps tools
- Ubuntu version validation
- System architecture detection
- Internet connectivity checks
- Root privilege validation
- Docker and Docker Compose installation
- Kubernetes installation using kubeadm
- Kubernetes cluster initialization
- Calico CNI installation
- Jenkins installation
- Prometheus installation
- Grafana installation
- Service health checks
- Complete installation verification
- Individual component removal
- Complete DevOps environment removal
- PASS / WARN / FAIL verification summary
- Modular Bash script architecture

---

# 🏗️ Architecture

The project follows a modular architecture.

```text
                         USER
                          │
                          ▼
                    ┌─────────────┐
                    │   main.sh   │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
    INSTALL             VERIFY            UNINSTALL
        │                  │                  │
        ▼                  ▼                  ▼
 ┌────────────┐      ┌────────────┐    ┌────────────┐
 │ Docker     │      │ Docker     │    │ Docker     │
 │ Kubernetes │      │ Kubernetes │    │ Kubernetes │
 │ Jenkins    │      │ Jenkins    │    │ Jenkins    │
 │ Prometheus │      │ Prometheus │    │ Prometheus │
 │ Grafana    │      │ Grafana    │    │ Grafana    │
 └────────────┘      └────────────┘    └────────────┘