# DevOps Auto Installer – Architecture

## Overview

The DevOps Auto Installer is a Bash-based automation project designed to simplify the installation, configuration, verification, Kubernetes cluster setup, and removal of commonly used DevOps tools on Ubuntu.

The project provides an interactive menu-driven interface that allows users to manage the following tools:

- Docker
- Kubernetes
- Jenkins
- Prometheus
- Grafana

The installer is designed to support Ubuntu:

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Ubuntu 26.04 LTS

---

# System Architecture

```text
                         ┌──────────────────────┐
                         │       USER           │
                         │   Runs Installer     │
                         └──────────┬───────────┘
                                    │
                                    ▼
                    ┌───────────────────────────┐
                    │     main.sh               │
                    │  Interactive Menu System  │
                    └──────────┬────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
    Install Tools        Verify System        Uninstall Tools
          │                    │                    │
          │                    │                    │
          ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ docker.sh       │  │ verify.sh       │  │ uninstall.sh    │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ kubernetes.sh   │  │ Docker          │  │ Remove Docker   │
│ jenkins.sh      │  │ Kubernetes      │  │ Remove K8s      │
│ prometheus.sh   │  │ Jenkins         │  │ Remove Jenkins  │
│ grafana.sh      │  │ Prometheus      │  │ Remove Prom     │
└─────────────────┘  │ Grafana         │  │ Remove Grafana  │
                     └─────────────────┘  └─────────────────┘
                               │
                               ▼
                     Verification Summary
                     PASS / WARN / FAIL