# Check if swap is configured
if ! grep -Fq "/proc/swapfile" /proc/swaps
then
  # The swap and Hibernation part goes all credit to 
  # https://forum.manjaro.org/t/howto-enable-and-configure-hibernation-with-btrfs/51253
  # Swap
  export fs_uuid=$(findmnt / -o UUID -n) && echo ${fs_uuid}
  sudo mount -m -U $fs_uuid /mnt/system-${fs_uuid}
  sudo btrfs subvolume create /mnt/system-${fs_uuid}/@swap
  sudo umount /mnt/system-${fs_uuid}
  sudo mount -m -U ${fs_uuid} -o subvol=@swap,nodatacow /swap
  sudo touch /swap/swapfile
  sudo chattr +C /swap/swapfile
  export swp_size=$(echo "$(grep "MemTotal" /proc/meminfo | tr -d "[:blank:],[:alpha:],:") * 1.6 / 1000" | bc ) && echo $swp_size
  sudo dd if=/dev/zero of=/swap/swapfile bs=1M count=$swp_size status=progress
  sudo chmod 0600 /swap/swapfile
  sudo mkswap /swap/swapfile
  sudo umount /swap
  echo -e "UUID=$fs_uuid\t/swap\tbtrfs\tsubvol=@swap,nodatacow,noatime,nospace_cache\t0\t0" | sudo tee -a /etc/fstab
  echo -e "/swap/swapfile\tnone\tswap\tdefaults\t0\t0" | sudo tee -a /etc/fstab
  sudo systemctl daemon-reload
  sudo mount /swap
  sudo swapon -a
  swapon -s

  #Hibernate
  export swp_uuid=$(findmnt -no UUID -T /swap/swapfile) && echo $swp_uuid
  curl -s "https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c" > bmp.c
  gcc -O2 -o bmp bmp.c
  swp_offset=$(echo "$(sudo ./bmp /swap/swapfile | egrep "^0\s+" | cut -f9) / $(getconf PAGESIZE)" | bc) && echo $swp_offset
  echo -e "GRUB_CMDLINE_LINUX_DEFAULT+=\" resume=UUID=$swp_uuid resume_offset=$swp_offset \"" | sudo tee -a /etc/default/grub
  echo -e "HOOKS+=( resume )" | sudo tee -a /etc/mkinitcpio.conf
  sudo mkdir -pv /etc/systemd/system/{systemd-logind.service.d,systemd-hibernate.service.d}
  echo -e "[Service]\nEnvironment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1" | sudo tee /etc/systemd/system/systemd-logind.service.d/override.conf
  echo -e "[Service]\nEnvironment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1" | sudo tee /etc/systemd/system/systemd-hibernate.service.d/override.conf
  sudo mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg 
fi