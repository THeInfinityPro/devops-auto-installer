# 🚀 DevOps Auto Installer

A Bash-based automation tool that installs, configures, verifies, monitors, and removes a complete DevOps environment on Ubuntu.

## 📦 Current Version

**v1.1.0**

## 🛠️ Supported DevOps Tools

- 🐳 Docker
- ☸️ Kubernetes
- 🔧 Jenkins
- 📊 Prometheus
- 📈 Grafana

---

# 📌 Features

- Interactive Whiptail menu-driven installer
- Automated installation of DevOps tools
- Ubuntu version validation
- System architecture detection
- Internet connectivity checks
- Root privilege validation
- Docker installation
- Docker Compose support
- Kubernetes installation using kubeadm
- Kubernetes cluster initialization
- Calico CNI installation
- Jenkins installation
- Prometheus installation
- Grafana installation
- System health checks
- Complete installation verification
- Interactive system dashboard
- Individual component removal
- Complete DevOps environment removal
- Installer log viewer
- PASS / WARN / FAIL verification summary
- Modular Bash script architecture
- GitHub Actions Bash validation

---

# 🏗️ Architecture

The project follows a modular architecture where `install.sh` acts as the main controller.

```text
                              USER
                                │
                                ▼
                           install.sh
                                │
                                ▼
                      Interactive Whiptail UI
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
   INSTALLATION            SYSTEM TOOLS             UNINSTALL
        │                       │                       │
        │                       │                       │
        ▼                       ▼                       ▼
 ┌───────────────┐      ┌─────────────────┐      ┌───────────────┐
 │ Docker        │      │ Verification    │      │ Remove Docker │
 │ Kubernetes    │      │ Health Check    │      │ Remove K8s    │
 │ K8s Cluster   │      │ Dashboard       │      │ Remove Jenkins│
 │ Jenkins       │      └─────────────────┘      │ Remove Prom   │
 │ Prometheus    │                               │ Remove Grafana│
 │ Grafana       │                               │ Remove All    │
 └───────────────┘                               └───────────────┘
        │
        ▼
   Installation Logs
        │
        ▼
 Logs/installer.log
```

For detailed architecture documentation, see:

📄 [Architecture Documentation](docs/architecture.md)

---

# 📁 Project Structure

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
│   ├── common.sh
│   ├── dashboard.sh
│   ├── docker.sh
│   ├── grafana.sh
│   ├── health-check.sh
│   ├── jenkins.sh
│   ├── kubernetes-cluster.sh
│   ├── kubernetes.sh
│   ├── prometheus.sh
│   ├── uninstall.sh
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

# 💻 Supported Operating Systems

The installer is designed to support:

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Ubuntu 26.04 LTS

---

# ⚙️ System Requirements

Recommended minimum system requirements:

| Resource | Minimum |
|---|---:|
| CPU | 2 Cores |
| RAM | 4 GB |
| Disk Space | 20 GB |
| Internet | Required |
| Operating System | Ubuntu |

For Kubernetes and all DevOps components together, higher resources are recommended.

---

# 🚀 Installation

## Clone the Repository

```bash
git clone https://github.com/THeInfinityPro/devops-auto-installer.git
```

## Navigate to the Project

```bash
cd devops-auto-installer
```

## Make Scripts Executable

```bash
chmod +x install.sh
chmod +x Scripts/*.sh
```

Or use:

```bash
chmod +x set-executable.sh
./set-executable.sh
```

## Start the Installer

```bash
sudo ./install.sh
```

---

# 🖥️ Interactive Menu

The installer provides an interactive Whiptail interface.

```text
┌───────────────────────────────────────┐
│       DEVOPS AUTO INSTALLER           │
├───────────────────────────────────────┤
│ 1. Install Docker                     │
│ 2. Install Kubernetes                 │
│ 3. Initialize Kubernetes Cluster      │
│ 4. Install Jenkins                    │
│ 5. Install Prometheus                 │
│ 6. Install Grafana                    │
│ 7. Install Everything                 │
│ 8. Verify Installation                │
│ 9. System Health Check                │
│10. View Dashboard                     │
│11. Uninstall Components               │
│12. View Installer Log                 │
│13. Exit                               │
└───────────────────────────────────────┘
```

---

# 🐳 Docker

The Docker installer performs:

- Dependency installation
- Docker repository configuration
- Docker Engine installation
- Docker service configuration
- Docker service verification

---

# ☸️ Kubernetes

The Kubernetes installer configures:

- Required kernel modules
- Sysctl parameters
- Container runtime
- Kubernetes repository
- kubeadm
- kubelet
- kubectl

---

# 🌐 Kubernetes Cluster

The Kubernetes cluster installer performs:

```text
Install Kubernetes Components
          │
          ▼
Initialize Control Plane
          │
          ▼
Configure kubectl
          │
          ▼
Install Calico CNI
          │
          ▼
Verify Cluster
```

---

# 🔧 Jenkins

The Jenkins installer performs:

- Java installation
- Jenkins repository configuration
- Jenkins installation
- Service configuration
- Service startup
- Installation verification

Jenkins can be accessed through:

```text
http://SERVER-IP:8080
```

---

# 📊 Prometheus

The Prometheus installer performs:

- Prometheus user creation
- Prometheus binary installation
- Configuration setup
- Data directory configuration
- Systemd service creation
- Service startup

Prometheus can be accessed through:

```text
http://SERVER-IP:9090
```

---

# 📈 Grafana

The Grafana installer performs:

- Grafana repository configuration
- Grafana installation
- Service configuration
- Service startup
- Installation verification

Grafana can be accessed through:

```text
http://SERVER-IP:3000
```

---

# 🔍 Installation Verification

The verification module checks:

```text
Docker
   │
Kubernetes
   │
Jenkins
   │
Prometheus
   │
Grafana
   │
   ▼
Verification Summary
   │
┌──┼──┐
▼  ▼  ▼
PASS WARN FAIL
```

Run verification from the interactive menu.

---

# ❤️ System Health Check

The health check verifies:

- System information
- CPU resources
- Memory usage
- Disk usage
- Important ports
- Local firewall configuration
- Installed components
- Service status

Example components checked:

```text
Docker
Kubernetes kubeadm
Kubernetes kubectl
Kubernetes kubelet
Jenkins
Prometheus
Grafana
```

---

# 📊 Dashboard

The dashboard provides a quick overview of:

- Docker status
- Kubernetes status
- Jenkins status
- Prometheus status
- Grafana status

This allows users to quickly check the current DevOps environment.

---

# 🗑️ Uninstallation

The interactive uninstaller supports:

- Remove Docker
- Remove Kubernetes
- Remove Jenkins
- Remove Prometheus
- Remove Grafana
- Remove Everything
- Verify removal
- View installer log

The uninstaller attempts to remove:

- Services
- Packages
- Repositories
- Configuration files
- Application data
- Systemd services

---

# 📄 Logging

All installer operations can be logged for troubleshooting.

Log location:

```text
Logs/installer.log
```

The log may contain:

- Installation activity
- Service information
- Errors
- Warnings
- Verification results
- Uninstallation activity

---

# 🔐 Important Ports

| Service | Port |
|---|---:|
| SSH | 22 |
| Grafana | 3000 |
| Kubernetes API | 6443 |
| Jenkins | 8080 |
| Prometheus | 9090 |

If you are using a cloud provider, ensure the required inbound firewall or security group rules are configured.

---

# 🧩 Architecture Components

```text
install.sh
    │
    ├── config/installer.conf
    │
    ├── Scripts/common.sh
    │
    ├── Installation Scripts
    │     ├── docker.sh
    │     ├── kubernetes.sh
    │     ├── kubernetes-cluster.sh
    │     ├── jenkins.sh
    │     ├── prometheus.sh
    │     └── grafana.sh
    │
    ├── System Tools
    │     ├── verify.sh
    │     ├── health-check.sh
    │     └── dashboard.sh
    │
    ├── Removal Tools
    │     └── uninstall.sh
    │
    └── Logs
          └── installer.log
```

---

# 🔄 Complete Workflow

```text
USER
 │
 ▼
sudo ./install.sh
 │
 ▼
System Validation
 │
 ▼
Load Configuration
 │
 ▼
Interactive Whiptail Menu
 │
 ├── Install Components
 │
 ├── Verify System
 │
 ├── Run Health Check
 │
 ├── View Dashboard
 │
 └── Uninstall Components
          │
          ▼
      Execute Script
          │
          ▼
       Log Output
          │
          ▼
       Show Result
```

---

# 🤝 Contributing

Contributions are welcome.

You can contribute by:

1. Forking the repository
2. Creating a new branch
3. Making your changes
4. Testing the scripts
5. Committing your changes
6. Creating a Pull Request

Please see:

📄 [CONTRIBUTING.md](CONTRIBUTING.md)

---

# 🛣️ Future Improvements

Possible future improvements include:

- Multi-node Kubernetes cluster support
- Worker node join automation
- Node Exporter installation
- Alertmanager installation
- Prometheus + Grafana automatic dashboard configuration
- Backup and restore functionality
- YAML configuration support
- Remote server installation support
- Ansible integration
- Terraform integration
- Web-based dashboard
- Additional Linux distribution support

---

# 👨‍💻 Author

**Jagadish V**

GitHub: [THeInfinityPro](https://github.com/THeInfinityPro)

---

# 📜 License

This project is licensed under the terms of the repository's `LICENSE` file.

---

# ⭐ Support

If you find this project useful:

- ⭐ Star the repository
- 🍴 Fork the repository
- 🐛 Report issues
- 💡 Suggest improvements

---

## 🚀 DevOps Auto Installer

Automating DevOps environment setup using Bash, Linux, Kubernetes, Monitoring, and CI/CD tools.