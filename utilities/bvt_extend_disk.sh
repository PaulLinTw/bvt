#/bin/bash !
if [ -f .disk_extended ]
then
   echo "disk already extended so exiting."
   exit 0
fi

echo "Creating volumn..."
sudo fdisk -u /dev/sda <<EOF
n
p


t
4
8e
w
EOF

echo "Rescan partition..."
sleep 10
sudo partprobe

echo "Adding partion to volume group..."
sudo pvcreate /dev/sda4
sudo vgextend VolGroup00 /dev/sda4
sudo lvextend -l  +100%FREE /dev/mapper/VolGroup00-LogVol00
sudo xfs_growfs /dev/mapper/VolGroup00-LogVol00

date > .disk_extended

echo "disk extended"
