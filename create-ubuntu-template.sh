#!/bin/bash
vmDiskStorage="local-lvm"
imageURL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
imageName="noble-server-cloudimg-amd64.img"
tmpId="9000"
tmpName="ubuntu-24.04-template"
tmpCores="2"
tmpMemory="512"
tmpSize="5G"
rootPasswd="rootpassword"
userPassword="userpassword"
sshKey="ssh...."

apt update
apt install -y libguestfs-tools wget

rm -f *.img

wget -O "$imageName" "$imageURL"

cat <<'EOF' > firstboot.sh
#!/bin/bash
useradd -m -s /bin/bash user-vm
echo "user-vm:__USERVM_PASSWORD__" | chpasswd
usermod -aG sudo user-vm
echo "user-vm ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user-vm
chmod 0440 /etc/sudoers.d/user-vm
apt-get update
apt-get install -y qemu-guest-agent ca-certificates curl apt-transport-https gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin gh
usermod -aG docker user-vm
systemctl enable docker.service
systemctl enable containerd.service
mkdir -p /home/user-vm/.ssh
echo "__SSH_KEY__" > /home/user-vm/.ssh/authorized_keys
chown -R user-vm:user-vm /home/user-vm/.ssh
chmod 700 /home/user-vm/.ssh
chmod 600 /home/user-vm/.ssh/authorized_keys
su - user-vm -c "sudo apt-get update && sudo apt-get install -y zsh"
su - user-vm -c "sudo apt-get install -y zsh-autosuggestions zsh-syntax-highlighting"
su - user-vm -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended'
su - user-vm -c 'git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
su - user-vm -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'
su - user-vm -c 'git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting'
su - user-vm -c 'git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete'
su - user-vm -c 'if grep -q "plugins=(" $HOME/.zshrc; then sudo sed -i "s/^plugins=(.*)$/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)/" $HOME/.zshrc; else echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)" >> $HOME/.zshrc; fi'
chsh -s $(which zsh) user-vm
EOF

sed -i "s/__USERVM_PASSWORD__/${userPassword}/g" firstboot.sh
sed -i "s#__SSH_KEY__#${sshKey}#g" firstboot.sh

cat <<'EOF' > firstboot.service
[Unit]
Description=First Boot Configuration Script
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/firstboot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

virt-customize -a "$imageName" --install qemu-guest-agent --root-password password:"$rootPasswd" --upload firstboot.sh:/usr/local/bin/firstboot.sh --chmod 0755:/usr/local/bin/firstboot.sh --upload firstboot.service:/etc/systemd/system/firstboot.service --run-command "systemctl enable firstboot.service"

cp "$imageName" old.img
qemu-img create -f qcow2 new.img "$tmpSize"
virt-resize --expand /dev/sda1 old.img new.img
if [ ! -f new.img ]; then
  exit 1
fi
virt-customize -a "$(pwd)/new.img" --run-command "grub-install /dev/sda && update-grub"
mv new.img "$imageName"
rm old.img

qm destroy "$tmpId"
qm create "$tmpId" --name "$tmpName" --memory "$tmpMemory" --cores "$tmpCores" --net0 virtio,bridge=vmbr1 --scsihw virtio-scsi-pci
qm importdisk "$tmpId" "$imageName" "$vmDiskStorage" --format qcow2
VOL_NAME=$(pvesm list "$vmDiskStorage" | grep "$tmpId" | grep '\.qcow2' | awk '{print $1}' | tail -n 1)
qm set "$tmpId" --scsi0 "${VOL_NAME}",ssd=1
qm set "$tmpId" --boot c --bootdisk scsi0
qm set "$tmpId" --ide0 "${vmDiskStorage}:cloudinit"
qm set "$tmpId" --serial0 socket --vga serial0
qm set "$tmpId" --ipconfig0 ip=dhcp
qm set "$tmpId" --agent enabled=1
qm template "$tmpId"
rm "$imageName" firstboot.sh firstboot.service
