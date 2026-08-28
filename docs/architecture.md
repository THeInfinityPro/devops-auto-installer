# DevOps Auto Installer – Architecture

## Overview

The DevOps Auto Installer is a Bash-based automation project designed to simplify the installation, configuration, verification, health checking, Kubernetes cluster setup, monitoring, and removal of commonly used DevOps tools on Ubuntu.

The project provides an interactive menu-driven interface that allows users to manage the following tools:

- Docker
- Kubernetes
- Jenkins
- Prometheus
- Grafana

The installer also provides:

- System verification
- System health checks
- Kubernetes cluster initialization
- Installation dashboard
- Component uninstallation
- Installation logging

The installer is designed to support:

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Ubuntu 26.04 LTS

---

# Project Architecture

```text
devops-auto-installer/
│
├── .github/
│   └── workflows/
│       └── bash-check.yml
│
├── config/
│   └── installer.conf
│
├── docs/
│   ├── architecture.md
│   ├── installation.md
│   └── troubleshooting.md
│
├── Logs/
│   └── installer.log
│
├── Scripts/
│   │
│   ├── common.sh
│   │
│   ├── dashboard.sh
│   │
│   ├── docker.sh
│   │
│   ├── grafana.sh
│   │
│   ├── health-check.sh
│   │
│   ├── jenkins.sh
│   │
│   ├── kubernetes-cluster.sh
│   │
│   ├── kubernetes.sh
│   │
│   ├── prometheus.sh
│   │
│   ├── uninstall.sh
│   │
│   └── verify.sh
│
├── .gitignore
├── CONTRIBUTING.md
├── install.sh
├── LICENSE
├── README.md
└── set-executable.sh

1. System Architecture


                         ┌──────────────────────┐
                         │        USER          │
                         │   Runs install.sh    │
                         └──────────┬───────────┘
                                    │
                                    ▼
                    ┌───────────────────────────┐
                    │       install.sh          │
                    │ Interactive Whiptail UI   │
                    │      Main Controller      │
                    └──────────┬────────────────┘
                               │
        ┌──────────────────────┼───────────────────────┐
        │                      │                       │
        ▼                      ▼                       ▼
  Install Components      System Management       Remove Components
        │                      │                       │
        │                      │                       │
        ▼                      ▼                       ▼

 ┌───────────────┐     ┌───────────────────┐    ┌─────────────────┐
 │ docker.sh     │     │ verify.sh         │    │ uninstall.sh    │
 │ kubernetes.sh │     │ health-check.sh   │    │                 │
 │ k8s-cluster   │     │ dashboard.sh      │    │ Remove Docker   │
 │ jenkins.sh    │     └───────────────────┘    │ Remove K8s      │
 │ prometheus.sh │              │               │ Remove Jenkins  │
 │ grafana.sh    │              ▼               │ Remove Prom     │
 └───────────────┘      System Status Summary   │ Remove Grafana  │
                              │                 │ Remove All      │
                              ▼                 └─────────────────┘
                    ┌─────────────────────┐
                    │ PASS / WARN / FAIL  │
                    └─────────────────────┘



2. Installation Flow


User
 │
 ▼
install.sh
 │
 ▼
System Requirements Check
 │
 ▼
Load Configuration
 │
 ▼
Interactive Menu
 │
 ├── Docker
 ├── Kubernetes
 ├── Kubernetes Cluster
 ├── Jenkins
 ├── Prometheus
 ├── Grafana
 └── Install Everything
          │
          ▼
     Run Scripts
          │
          ▼
     Verify Installation
          │
          ▼
       Complete


3. Component Architecture


Docker

docker.sh
   │
   ├── Dependencies
   ├── Repository
   ├── Docker Engine
   ├── Service
   └── Verification


Kubernetes

kubernetes.sh
   │
   ├── Kernel Modules
   ├── Sysctl Configuration
   ├── Container Runtime
   ├── Kubernetes Repository
   ├── kubeadm
   ├── kubelet
   └── kubectl


Kubernetes Cluster

kubernetes-cluster.sh
   │
   ├── Check Components
   ├── Initialize Control Plane
   ├── Configure kubeconfig
   ├── Install Calico
   └── Verify Cluster


Jenkins

jenkins.sh
   │
   ├── Install Java
   ├── Add Repository
   ├── Install Jenkins
   ├── Enable Service
   └── Verify


Prometheus

prometheus.sh
   │
   ├── Create User
   ├── Download
   ├── Configure
   ├── Systemd Service
   └── Start Service


Grafana

grafana.sh
   │
   ├── Add Repository
   ├── Install Grafana
   ├── Configure Service
   └── Start Service




5. Verification Architecture


verify.sh
    │
    ├── Docker
    ├── Kubernetes
    ├── Jenkins
    ├── Prometheus
    └── Grafana
           │
           ▼
    Verification Summary
           │
     ┌─────┼─────┐
     ▼     ▼     ▼
   PASS   WARN   FAIL


6. Health Check Architecture


health-check.sh
      │
      ├── System Information
      ├── CPU Check
      ├── Memory Check
      ├── Disk Check
      ├── Port Check
      ├── Firewall Check
      ├── Component Check
      └── Service Check
               │
               ▼
        Health Summary


7. Dashboard Architecture

dashboard.sh
      │
      ├── Docker Status
      ├── Kubernetes Status
      ├── Jenkins Status
      ├── Prometheus Status
      └── Grafana Status
               │
               ▼
        Status Dashboard


8. Uninstallation Architecture


uninstall.sh
      │
      ▼
Interactive Removal Menu
      │
      ├── Remove Docker
      ├── Remove Kubernetes
      ├── Remove Jenkins
      ├── Remove Prometheus
      ├── Remove Grafana
      ├── Remove Everything
      ├── Verify Removal
      └── View Installer Log
               │
               ▼
          Cleanup
               │
               ▼
       Verify Removal



9. Logging Architecture


Component Scripts
       │
       ▼
   common.sh
       │
       ▼
 Logging Functions
       │
       ▼
Logs/installer.log
       │
       ├── Installation Logs
       ├── Removal Logs
       ├── Error Logs
       └── Verification Logs



10. User Interface Architecture


                    install.sh
                        │
                        ▼
              Interactive Whiptail UI
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
      Menus        Confirmations      Progress
        │               │               │
        ▼               ▼               ▼
 Component Menu    Yes / No Dialog   Progress Gauge
                        │
                        ▼
                   Result Dialog
                        │
               ┌────────┴────────┐
               ▼                 ▼
            Success             Error



11. Complete End-to-End Architecture





                            USER
                              │
                              ▼
                         install.sh
                              │
                              ▼
                       Load Configuration
                              │
                              ▼
                        Load common.sh
                              │
                              ▼
                     Interactive Whiptail UI
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
     Installation        System Tools         Uninstaller
          │                   │                   │
          │                   │                   │
          ▼                   ▼                   ▼
     docker.sh           verify.sh          uninstall.sh
     kubernetes.sh       health-check.sh
     kubernetes-         dashboard.sh
     cluster.sh
     jenkins.sh
     prometheus.sh
     grafana.sh
          │
          ▼
    Component Installed
          │
          ▼
      Verification
          │
          ▼
      Health Check
          │
          ▼
       Dashboard
          │
          ▼
   Logs/installer.log


12. Architecture Summary


┌──────────────────────────────────────┐
│         DevOps Auto Installer        │
├──────────────────────────────────────┤
│ Main Controller                      │
│ └── install.sh                       │
├──────────────────────────────────────┤
│ Configuration                        │
│ └── config/installer.conf            │
├──────────────────────────────────────┤
│ Shared Functions                     │
│ └── Scripts/common.sh                │
├──────────────────────────────────────┤
│ Component Installers                 │
│ ├── Docker                           │
│ ├── Kubernetes                       │
│ ├── Jenkins                          │
│ ├── Prometheus                       │
│ └── Grafana                          │
├──────────────────────────────────────┤
│ System Management                    │
│ ├── Verification                     │
│ ├── Health Check                     │
│ └── Dashboard                        │
├──────────────────────────────────────┤
│ Removal Management                   │
│ └── uninstall.sh                     │
├──────────────────────────────────────┤
│ Logging                              │
│ └── Logs/installer.log               │
└──────────────────────────────────────┘


