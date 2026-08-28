# DevOps Auto Installer – Architecture

## Overview

The DevOps Auto Installer is a Bash-based automation project designed to simplify the installation, configuration, verification, health checking, Kubernetes cluster setup, monitoring, and removal of commonly used DevOps tools on Ubuntu.

The project provides an interactive menu-driven interface for managing:

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
- Interactive Whiptail user interface

The installer is designed to support:

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Ubuntu 26.04 LTS

---

# 1. Project Architecture

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
```

---

# 2. System Architecture

```text
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
        ▼                      ▼                       ▼
 ┌───────────────┐     ┌───────────────────┐    ┌─────────────────┐
 │ docker.sh     │     │ verify.sh         │    │ uninstall.sh    │
 │ kubernetes.sh │     │ health-check.sh   │    │                 │
 │ cluster.sh    │     │ dashboard.sh      │    │ Remove Docker   │
 │ jenkins.sh    │     └───────────────────┘    │ Remove K8s      │
 │ prometheus.sh │              │               │ Remove Jenkins  │
 │ grafana.sh    │              ▼               │ Remove Prom     │
 └───────────────┘      System Status Summary   │ Remove Grafana  │
                              │                 │ Remove All      │
                              ▼                 └─────────────────┘
                    ┌─────────────────────┐
                    │ PASS / WARN / FAIL  │
                    └─────────────────────┘
```

---

# 3. Main Controller Architecture

The `install.sh` file is the main entry point of the project.

```text
                         USER
                           │
                           ▼
                      install.sh
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
 Load Configuration   Load common.sh    Initialize System
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
                 Interactive Whiptail Menu
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
   Install Tools      System Tools       Uninstall Tools
```

The main controller is responsible for:

- Loading configuration
- Loading shared functions
- Initializing the environment
- Displaying the interactive menu
- Running component installation scripts
- Running verification
- Running health checks
- Opening the dashboard
- Opening the uninstaller

---

# 4. Installation Flow

```text
User
 │
 ▼
install.sh
 │
 ▼
Check System Requirements
 │
 ▼
Load Configuration
 │
 ▼
Load Shared Functions
 │
 ▼
Display Interactive Menu
 │
 ├── Install Docker
 │
 ├── Install Kubernetes
 │
 ├── Initialize Kubernetes Cluster
 │
 ├── Install Jenkins
 │
 ├── Install Prometheus
 │
 ├── Install Grafana
 │
 └── Install Everything
          │
          ▼
     Run Component Scripts
          │
          ▼
     Save Output to Logs
          │
          ▼
     Verify Installation
          │
          ▼
       Complete
```

---

# 5. Configuration Architecture

The project uses `config/installer.conf` to store configurable values.

```text
install.sh
    │
    ▼
config/installer.conf
    │
    ├── Kubernetes Version
    ├── Pod CIDR
    ├── Calico Version
    ├── Installer Settings
    └── Future Configuration
```

Using a centralized configuration file allows settings and versions to be updated without changing multiple installation scripts.

---

# 6. Shared Functions Architecture

The `Scripts/common.sh` file provides reusable functions used across the project.

```text
                    common.sh
                        │
        ┌───────────────┼────────────────┐
        │               │                │
        ▼               ▼                ▼
     Logging         Messages         Utilities
        │               │                │
        ▼               ▼                ▼
 installer.log     INFO             command_exists
                   SUCCESS          initialize
                   WARNING          system checks
                   ERROR            helper functions
```

Shared functionality includes:

- Logging
- Information messages
- Success messages
- Warning messages
- Error messages
- Command checks
- Initialization
- Common helper functions

---

# 7. Docker Architecture

The `Scripts/docker.sh` script manages Docker installation.

```text
docker.sh
   │
   ├── Install Dependencies
   │
   ├── Add Docker Repository
   │
   ├── Install Docker Engine
   │
   ├── Configure Docker Service
   │
   └── Verify Installation
```

Docker provides the container runtime environment for containerized applications.

---

# 8. Kubernetes Architecture

The `Scripts/kubernetes.sh` script installs the required Kubernetes components.

```text
kubernetes.sh
   │
   ├── Configure Kernel Modules
   │
   ├── Configure Sysctl Settings
   │
   ├── Configure Container Runtime
   │
   ├── Add Kubernetes Repository
   │
   ├── Install kubeadm
   │
   ├── Install kubelet
   │
   └── Install kubectl
```

Main Kubernetes components:

- kubeadm
- kubelet
- kubectl
- Kubernetes CNI components

---

# 9. Kubernetes Cluster Architecture

The `Scripts/kubernetes-cluster.sh` script initializes and configures the Kubernetes cluster.

```text
kubernetes-cluster.sh
        │
        ▼
Check Kubernetes Components
        │
        ▼
Initialize Control Plane
        │
        ▼
Configure kubeconfig
        │
        ▼
Install Calico Network
        │
        ▼
Verify Cluster Status
```

The cluster setup creates the Kubernetes control plane and configures networking.

---

# 10. Jenkins Architecture

The `Scripts/jenkins.sh` script installs Jenkins.

```text
jenkins.sh
   │
   ├── Install Java
   │
   ├── Add Jenkins Repository
   │
   ├── Install Jenkins
   │
   ├── Enable Jenkins Service
   │
   └── Verify Jenkins
```

Jenkins can be used for:

- Continuous Integration
- Continuous Delivery
- Build automation
- Deployment automation
- Pipeline management

---

# 11. Prometheus Architecture

The `Scripts/prometheus.sh` script installs Prometheus.

```text
prometheus.sh
      │
      ▼
Create Prometheus User
      │
      ▼
Download Prometheus
      │
      ▼
Configure Prometheus
      │
      ▼
Create Systemd Service
      │
      ▼
Start Prometheus
      │
      ▼
Verify Service
```

Prometheus provides:

- Metrics collection
- Infrastructure monitoring
- Service monitoring
- Time-series data storage

---

# 12. Grafana Architecture

The `Scripts/grafana.sh` script installs Grafana.

```text
grafana.sh
     │
     ▼
Add Grafana Repository
     │
     ▼
Install Grafana
     │
     ▼
Configure Grafana Service
     │
     ▼
Start Grafana
     │
     ▼
Verify Service
```

Grafana provides:

- Monitoring dashboards
- Metric visualization
- Data visualization
- Prometheus integration

---

# 13. Verification Architecture

The `Scripts/verify.sh` script verifies installed DevOps components.

```text
verify.sh
    │
    ├── Check Docker
    │
    ├── Check Kubernetes
    │
    ├── Check Jenkins
    │
    ├── Check Prometheus
    │
    └── Check Grafana
           │
           ▼
    Verification Summary
           │
     ┌─────┼─────┐
     │     │     │
     ▼     ▼     ▼
   PASS   WARN   FAIL
```

The verification process checks whether required commands, packages, and services are available.

---

# 14. Health Check Architecture

The `Scripts/health-check.sh` script checks system resources and DevOps component status.

```text
health-check.sh
      │
      ├── System Information
      │
      ├── CPU Check
      │
      ├── Memory Check
      │
      ├── Disk Space Check
      │
      ├── Port Status Check
      │
      ├── Firewall Check
      │
      ├── Existing Component Check
      │
      └── Service Status Check
               │
               ▼
        System Health Summary
```

The health check provides an overview of:

- System resources
- Available disk space
- Memory status
- Service status
- Required ports
- Firewall configuration
- Installed DevOps components

---

# 15. Dashboard Architecture

The `Scripts/dashboard.sh` script provides a quick overview of the DevOps environment.

```text
dashboard.sh
      │
      ├── Docker Status
      │
      ├── Kubernetes Status
      │
      ├── Jenkins Status
      │
      ├── Prometheus Status
      │
      └── Grafana Status
               │
               ▼
        Interactive Status Dashboard
```

The dashboard provides a centralized view of component availability and service status.

---

# 16. Uninstallation Architecture

The `Scripts/uninstall.sh` script provides an interactive interface for removing DevOps components.

```text
uninstall.sh
      │
      ▼
Interactive Removal Menu
      │
      ├── Remove Docker
      │
      ├── Remove Kubernetes
      │
      ├── Remove Jenkins
      │
      ├── Remove Prometheus
      │
      ├── Remove Grafana
      │
      ├── Remove Everything
      │
      ├── Verify Removal
      │
      └── View Installer Log
               │
               ▼
        Stop Services
               │
               ▼
        Remove Packages
               │
               ▼
      Remove Configuration
               │
               ▼
        Verify Removal
```

The uninstaller performs cleanup operations such as:

- Stopping services
- Disabling services
- Removing packages
- Removing repositories
- Removing configuration files
- Removing application data
- Removing systemd services
- Verifying component removal

---

# 17. Logging Architecture

The project uses centralized logging.

```text
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
       ├── Verification Logs
       └── System Information
```

The log file helps troubleshoot installation, verification, and removal issues.

Log location:

```text
Logs/installer.log
```

---

# 18. User Interface Architecture

The project uses Whiptail to provide an interactive terminal interface.

```text
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
               │                 │
               ▼                 ▼
            Success             Error
```

The user interface provides:

- Component selection menus
- Installation confirmation
- Removal confirmation
- Progress indicators
- Status messages
- Log viewing
- Verification results
- System health information

---

# 19. GitHub Actions Architecture

The project includes GitHub Actions for Bash validation.

```text
Developer
    │
    ▼
Push Code to GitHub
    │
    ▼
GitHub Actions
    │
    ▼
bash-check.yml
    │
    ▼
Check Bash Scripts
    │
    ▼
Validation Result
```

This helps identify Bash syntax or validation issues during development.

---

# 20. Complete End-to-End Architecture

```text
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
                      Initialize Environment
                                │
                                ▼
                      Interactive Whiptail UI
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
          ▼                     ▼                     ▼
     Installation          System Tools          Uninstaller
          │                     │                     │
          │                     │                     │
          ▼                     ▼                     ▼
     docker.sh             verify.sh           uninstall.sh
     kubernetes.sh         health-check.sh
     kubernetes-           dashboard.sh
     cluster.sh
     jenkins.sh
     prometheus.sh
     grafana.sh
          │
          ▼
   Component Installation
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
```

---

# 21. Architecture Summary

```text
┌──────────────────────────────────────────────┐
│             DevOps Auto Installer            │
├──────────────────────────────────────────────┤
│ Main Controller                              │
│ └── install.sh                               │
├──────────────────────────────────────────────┤
│ Configuration                                │
│ └── config/installer.conf                    │
├──────────────────────────────────────────────┤
│ Shared Functions                             │
│ └── Scripts/common.sh                        │
├──────────────────────────────────────────────┤
│ Component Installers                         │
│ ├── Docker                                   │
│ ├── Kubernetes                               │
│ ├── Kubernetes Cluster                       │
│ ├── Jenkins                                  │
│ ├── Prometheus                               │
│ └── Grafana                                  │
├──────────────────────────────────────────────┤
│ System Management                            │
│ ├── Verification                             │
│ ├── Health Check                             │
│ └── Dashboard                                │
├──────────────────────────────────────────────┤
│ Removal Management                           │
│ └── uninstall.sh                             │
├──────────────────────────────────────────────┤
│ Logging                                      │
│ └── Logs/installer.log                       │
├──────────────────────────────────────────────┤
│ Automation                                   │
│ └── GitHub Actions                           │
└──────────────────────────────────────────────┘
```

---

# Design Principles

The DevOps Auto Installer follows these principles:

- Modular Bash scripting
- Separation of components
- Reusable shared functions
- Centralized configuration
- Interactive terminal user interface
- Clear installation feedback
- Progress monitoring
- Centralized logging
- Safe component removal
- Installation verification
- System health monitoring
- Easy troubleshooting
- Easy maintenance
- Scalable architecture
- GitHub-friendly project structure

---

# Summary

The DevOps Auto Installer uses a modular architecture where `install.sh` acts as the main controller and the scripts inside the `Scripts` directory manage specific DevOps components and system operations.

The architecture is divided into the following layers:

1. **Main Controller**
   - `install.sh`

2. **Configuration**
   - `config/installer.conf`

3. **Shared Functions**
   - `Scripts/common.sh`

4. **Component Installation**
   - Docker
   - Kubernetes
   - Kubernetes Cluster
   - Jenkins
   - Prometheus
   - Grafana

5. **System Management**
   - Verification
   - Health Checks
   - Dashboard

6. **Removal Management**
   - Interactive Uninstaller
   - Component Cleanup
   - Removal Verification

7. **Logging**
   - `Logs/installer.log`

8. **Automation**
   - GitHub Actions

This modular architecture keeps the project:

- Modular
- Maintainable
- Scalable
- Easy to troubleshoot
- Easy to extend
- User-friendly
- Suitable for DevOps automation and learning projects