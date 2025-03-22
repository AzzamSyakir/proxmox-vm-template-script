#!/bin/bash

vmDiskStorage="vmc-pool"
backupStorage="bckp-pool"
isoStorage="iso-pool"
snippetPath="/server-storage-pool/${backupStorage}/snippets"
snippetStorageID="${backupStorage}"

imageURL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
imageName="noble-server-cloudimg-amd64.img"

virtualMachineId="9000"
templateName="ubuntu-24.04-template"
tmp_cores="2"
tmp_memory="2048"
rootPasswd="rootpassword"
cpuTypeRequired="host"
userVmPassword="userpassword"
ghToken=""
vmSize="10G"
sshKey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCbD+rEp2nhup4QDDeO/+mmCidCfPJ1O9qzRx5ON3/HQFkjsachM19RY6nXKi3ZwADQAHUYgsv1xE70vW7A5m6z9FaJRaW/qCVP8E1Ay7xN2FVg+4LDWvYZcRZ+ldb/KgJpDRvmNIO00MrSOgKoqZN7a4resM/kGI/OnbZ2NM635aMg0RUXJUhC6299Sat8r2+nzxoUxrqLChlGlmMnqEEMlrzyjkcWmjj1UUF4hvdvXMeSgpOAlc2QSZKyh4quUbOPiN0nRPq/IYU8mfRYJOeGUDE0zDMsZS302fZ/Y2vEi/rdGSMFe09zEk1OHgqAm6t7wnOJShu/4dcc06SZGz8NA7WNfM5omuUchMRyx2/aZEYZd7ZbAS5Hj2SV4vWOl+c9AXabLD2P+ZzjyFCL7BMFOb2p6Mp/59X35Uc+dBOVqhBmfwROmceqdaBad5FQk4L892d4AYrCVw5shepEp5yf4KGqyIQx12SH7hkRWTKFgis1lfMKH2LJW2c1h5CZpEIPe3VB+f2ojjK6OoPb32FtmcnEkqkp1uKw2j7bmHiOg7+CqZ7qYikcSRVAiLzjJJHUEbKDbb/hT2m5Qj8mG9j0EqEGzxy7L0KTGg8QAu9yx1s36Q+eMGBZHiDYiuwi9OBVSsb2OyYIBBNClUNUycU4RqWfKFIMkwIHnItY+Bquhw== asakusa@archangel"

apt update
apt install -y libguestfs-tools

rm -f *.img
wget -O "$imageName" "$imageURL"

cat <<EOF > user-data
#cloud-config
runcmd:
  - useradd -m -s /bin/bash user-vm
  - echo "user-vm:${userVmPassword}" | chpasswd
  - usermod -aG sudo user-vm
  - echo "user-vm ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user-vm
  - chmod 0440 /etc/sudoers.d/user-vm
  - apt-get update
  - apt-get install -y qemu-guest-agent ca-certificates curl apt-transport-https gnupg lsb-release
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc
  - echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \$VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin gh
  - usermod -aG docker user-vm
  - systemctl enable docker.service
  - systemctl enable containerd.service
  - echo "${ghToken}" | gh auth login --with-token
  - git config --global user.name "Azzamsyakir"
  - git config --global user.email "azzamsykir@gmail.com"
  - mkdir -p /home/user-vm/.ssh
  - echo "${sshKey}" > /home/user-vm/.ssh/authorized_keys
  - chown -R user-vm:user-vm /home/user-vm/.ssh
  - chmod 700 /home/user-vm/.ssh
  - chmod 600 /home/user-vm/.ssh/authorized_keys
  - su - user-vm -c "sudo apt-get update && sudo apt-get install -y zsh"
  - su - user-vm -c "sudo apt-get install -y zsh-autosuggestions zsh-syntax-highlighting"
  - su - user-vm -c 'sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended'
  - su - user-vm -c 'git clone https://github.com/zsh-users/zsh-autosuggestions.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
  - su - user-vm -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'
  - su - user-vm -c 'git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting'
  - su - user-vm -c 'git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete'
  - su - user-vm -c 'if grep -q "plugins=(" \$HOME/.zshrc; then sudo sed -i "s/^plugins=(.*)\$/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)/" \$HOME/.zshrc; else echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)" | sudo tee -a \$HOME/.zshrc; fi'
  - su - user-vm -c "sudo chsh -s \$(which zsh)"
EOF

mkdir -p "$snippetPath"
mv user-data "$snippetPath/user-data"

qm destroy "$virtualMachineId"

# Pasang qemu-guest-agent & atur root password
virt-customize -a "$imageName" --install qemu-guest-agent
virt-customize -a "$imageName" --root-password password:"$rootPasswd"
# Resize disk sebelum impor (opsional)
cp "$imageName" old.img
qemu-img create -f qcow2 new.img "$vmSize"
virt-resize --expand /dev/sda1 old.img new.img

# Cek apakah new.img berhasil dibuat
if [ ! -f new.img ]; then
  echo "Error: new.img tidak ditemukan setelah virt-resize."
  exit 1
fi

# Update GRUB pada new.img menggunakan path absolut
virt-customize -a "$(pwd)/new.img" --run-command "grub-install /dev/sda && update-grub"

mv new.img "$imageName"
rm old.img


qm create "$virtualMachineId" \
  --name "$templateName" \
  --memory "$tmp_memory" \
  --cores "$tmp_cores" \
  --net0 virtio,bridge=vmbr1 \
  --scsihw virtio-scsi-pci \
  --ide0 none \
  --ostype l26

# 1. Import disk
qm importdisk "$virtualMachineId" "$imageName" "$vmDiskStorage" --format qcow2

# 2. Ambil nama volume
VOL_NAME=$(pvesm list "$vmDiskStorage" | grep "$virtualMachineId" | grep '\.qcow2' | awk '{print $1}' | tail -n 1)
echo "Nilai VOL_NAME: ${VOL_NAME}"
# Hapus device IDE dan SCSI yang ada (jika ada)
qm set "$virtualMachineId" --delete ide0
qm set "$virtualMachineId" --delete ide1

# 5. Pasang disk utama langsung ke scsi0
qm set "$virtualMachineId" --scsi0 "${VOL_NAME}",ssd=1
qm set "$virtualMachineId" --boot c --bootdisk scsi0

# 6. Pasang CloudInit drive ke ide0
qm set "$virtualMachineId" --ide0 "${vmDiskStorage}:cloudinit"

# Console & VGA
qm set "$virtualMachineId" --serial0 socket --vga serial0

# DHCP
qm set "$virtualMachineId" --ipconfig0 ip=dhcp

# CPU
qm set "$virtualMachineId" --cpu cputype="$cpuTypeRequired"

# Custom CloudInit config
qm set "$virtualMachineId" --cicustom "user=${snippetStorageID}:snippets/user-data"

# Jadikan template
qm template "$virtualMachineId"

echo "VM template '$templateName' created with disk size = $vmSize (no qm resize needed)."
rm "$imageName"
