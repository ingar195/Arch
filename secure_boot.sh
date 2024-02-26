

paru -S --noconfirm --needed  efitools sbctl

sudo chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}*

sudo sbctl create-keys
sudo sbctl enroll-keys -m 

sudo sbctl sign -s /boot/vmlinuz-linux
sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI

sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi

sudo bootctl install