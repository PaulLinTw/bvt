#/bin/bash !
if [ -f .disk_resized ]
then
   echo "Disk already resized."
   exit 0
elif [ -f .disk_modified ]
then
   echo "Resizing disk.."
   resize2fs /dev/sda1
   x=$(echo $?)
   if [[ "$x" == "0" ]]; then
	   date > .disk_resized
	   echo "Disk resize completed."
   fi
   exit 0
else
   echo "Modifying Partition Size.."
   fdisk -u /dev/sda <<EOF
d
n
p



w
EOF
   sleep 15
   x=$(echo $?)
   if [[ "$x" == "0" ]]; then
      date > .disk_modified
      echo "Disk modify completed."
   else
      echo "Disk modify failed."
   fi
fi

