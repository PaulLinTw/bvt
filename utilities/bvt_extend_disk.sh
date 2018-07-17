set -e
set -x

if [ -f .disk_extended ]
then
   echo "disk already extended so exiting."
   exit 0
fi

echo "Creating partition..."
sudo fdisk -u /dev/sda <<EOF
n
p


t
4
8e
w
EOF

echo "wait 10 seconds"
sleep 10

echo "Rescan partition..."
sudo partprobe

echo "Adding partion to volume group..."
sudo pvcreate /dev/sda4
sudo vgextend VolGroup00 /dev/sda4
sudo lvextend -l  +100%FREE /dev/mapper/VolGroup00-LogVol00
sudo xfs_growfs /dev/mapper/VolGroup00-LogVol00

date > .disk_extended

echo "disk extended"
