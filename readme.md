# Proxmox Cloud-Init Template Script

This repository contains a script that automates the creation of an Ubuntu cloud-init template for Proxmox VE. The script downloads an Ubuntu cloud image, customizes it with first-boot configurations, resizes the disk, and finally creates a Proxmox template for quick virtual machine provisioning.

## Overview

The script performs the following tasks:

- **Update & Install Prerequisites:** Updates the system and installs necessary packages (e.g., `libguestfs-tools`, `wget`).
- **Download Image:** Retrieves an Ubuntu cloud image from the official Ubuntu cloud images repository.
- **Customize Image:** Creates a `firstboot.sh` script that sets up a user account, installs packages (like Docker, zsh, and Git), configures SSH keys, and performs additional customizations.
- **Resize Disk:** Uses `virt-resize` to expand the disk to the desired size.
- **Create Proxmox Template:** Configures a new Proxmox virtual machine, imports the disk, and sets up cloud-init integration.

## Prerequisites

- **Proxmox VE with the following storage pools:**
  - **Virtual machine disks:** Default is usually `local-lvm`, but in my case I named the storage for VMs with `vmc-pool`.
- Root or administrator access to the Proxmox host.
- Required packages:
  - `libguestfs-tools`
  - `wget`
  - Other dependencies as installed by the script

## Variable Configuration

Here is an example of how you might set up the variables at the top of your script:

```bash
# Example variables
imageURL="https://cloud-images.ubuntu.com/jammy/20230830/jammy-server-cloudimg-amd64.img"
imageName="jammy-server-cloudimg-amd64.img"
vmDiskStorage="local-lvm"
virtualMachineId="9000"
templateName="jammy-tpl"
tmp_cores="2"
tmp_memory="2048"
rootPasswd="password"
cpuTypeRequired="host"
userVmPassword="password"
vmSize="5G"
sshKey="ssh-rsa AAAAB3NzaC1ycE..."
```

> **Note:** Adjust these variables to match your own Proxmox environment, desired VM specs, and cloud image URL.

## Installation

### Method 1: Cloning the Repository

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/yourusername/ProxmoxCloudInitScript.git
   cd ProxmoxCloudInitScript
   ```

2. **Make the Script Executable:**

   ```bash
   chmod +x create-ubuntu-template.sh
   ```

3. **Run the Script:**

   ```bash
   ./create-ubuntu-template.sh
   ```

> **Note:** Before running the script, review and modify the variable definitions at the top of the script to match your environment and requirements.

### Method 2: Copying the Script Manually

1. **Copy the Script Contents:**  
   Copy the entire script from this repository (e.g., from the `create-ubuntu-template.sh` file).

2. **Create a File on Your Proxmox Server:**  
   On your Proxmox server, create a new file:

   ```bash
   nano create-ubuntu-template.sh
   ```

   Paste the script contents into this file.

3. **Make the Script Executable:**

   ```bash
   chmod +x create-ubuntu-template.sh
   ```

4. **Run the Script:**

   ```bash
   ./create-ubuntu-template.sh
   ```

> **Note:** Again, make sure to adjust the variables within the script to match your environment.

## Usage

Once the script is executable, simply run it as shown above. The script will:

1. Update the system and install required packages.
2. Download the specified Ubuntu cloud image.
3. Customize the image with user settings, SSH keys, Docker, etc.
4. Resize the disk to the specified size.
5. Create a Proxmox VM and convert it into a template for future deployments.

## How It Works

1. **System Update & Package Installation:**  
   The script updates the package list and installs `libguestfs-tools` and `wget`.

2. **Downloading the Ubuntu Cloud Image:**  
   It downloads the Ubuntu cloud image from the specified `imageURL`.

3. **First Boot Customization:**  
   A `firstboot.sh` script is created, which:
   - Creates a user (`user-vm`)
   - Sets up sudo privileges and SSH keys
   - Installs Docker, zsh (with plugins), Git, and other utilities

4. **Image Customization:**  
   Using `virt-customize`, the script:
   - Uploads the `firstboot.sh` and a corresponding systemd service to the image
   - Configures the image to run the first boot script at startup

5. **Disk Resizing:**  
   The script resizes the disk image using `virt-resize` to meet the desired `vmSize`.

6. **Proxmox VM Creation:**  
   It creates a new Proxmox VM, imports the customized image, configures virtual hardware (e.g., CPU, memory, boot options), and converts the VM into a template.

## Credits

This script is inspired by [andrewglass3](https://github.com/andrewglass3) and builds upon the [ProxmoxCloudInitScript repository](https://github.com/andrewglass3/ProxmoxCloudInitScript).

## Useful Links

- [Proxmox VE](https://proxmox.com/en/) – Official Proxmox VE website.
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/) – Official Ubuntu cloud images.
- [Proxmox Community Forum](https://forum.proxmox.com/) – Get help and discuss Proxmox-related topics.

## License

This project is licensed under the [MIT License](LICENSE).

## Contact

For questions or suggestions, please open an issue in the repository or contact my email that is shown on my GitHub account.
