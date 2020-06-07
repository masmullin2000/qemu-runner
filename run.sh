RAM=8G
SMP=8
FOLDER_AMT=0

SPICE="-vga qxl -device virtio-serial-pci -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 "
SPICE+="-chardev spicevmc,id=spicechannel0,name=vdagent -spice unix,addr=/tmp/vm_spice.socket,disable-ticketing "
SPICE_CMD=""

DRVCNT=0
PAUSE=0

cmd="qemu-system-x86_64 -enable-kvm -serial stdio -soundhw hda "

cmdline_pre="\"console=ttyS0 "
cmdline_post=" rw nokaslr\" "
cmdline=""
kernel_cmd=""
net_cmd+="-net user,hostfwd=tcp::2222-:22"

while [ ! -z "$1" ]
do
	case "$1" in
		-a|--adddrv)
			case $DRVCNT in
				0)
					echo "0"
					cmd+="-hdb $2 "
					DRVCNT=$(($DRVCNT + 1))
					;;
				1)
					echo "1"
					cmd+="-hdc $2 "
					DRVCNT=$(($DRVCNT + 1))
					;;
				2)
					echo "2"
					cmd+="-hdd $2 "
					DRVCNT=$(($DRVCNT + 1))
					;;
				*)
					echo "Subsequent Drives currently not supported"
			esac
			shift
			;;
		-cd|--cdrom)
			cmd+="-cdrom $2 "
			shift
			;;
		-kl|--kernel-locate)
			kernel_cmd+="-kernel $2 "
			shift
			;;
		-k|--kernel)
			#cmd+="-kernel linux/arch/x86/boot/bzImage -append \"root=/dev/sda1 console=ttyS0 rw nokaslr\" "

			kernel_cmd+="-kernel linux/arch/x86/boot/bzImage "
			;;
		-i|--init)
			cmd+="-initrd $2 "
			shift
			;;
		-c|--cmdline)
			cmdline=$2
			shift
			;;
		-cf|--fedora)
			cmdline="root=/dev/mapper/fedora-root ro resume=/dev/mapper/fedora-swap rd.lvm.lv=fedora/root rd.lvm.lv=fedora/swap rhgb"
			;;
		-p|--port)
			net_cmd+=",hostfwd=tcp::$2-:$3"
			shift
			shift
			;;
		-n|--nodisplay)
			cmd+="-display none "
			;;
		-d|--debug)
			cmd+="-s "
			;;
		-b|--break)
			cmd+="-S "
			;;
		-r|--ram)
			RAM="$2"
			RAM+="G"
			shift
			;;
		-j|--threads)
			SMP="$2"
			shift
			;;
		-f|--folder)
			PAUSE=1
			FOLDER=`realpath $2`
			cmd+="-virtfs local,path=$FOLDER,mount_tag=host$FOLDER_AMT,security_model=passthrough,id=host$FOLDER_AMT "
			FOLDER_AMT=$(($FOLDER_AMT + 1))
			shift
			;;
		-v|--viewer)
			PAUSE=1
			cmd+="$SPICE"
			SPICE_CMD="Connect to Viewer via Spice\nremote-viewer spice+unix:///tmp/vm_spice.socket"
			;;
		*)
			cmd+="-hda $1 "
			;;
	esac
	shift
done

if [ -z "$cmdline" ]
then
	cmdline="root=/dev/sda1"
fi
cmdline_full=$cmdline_pre
cmdline_full+=$cmdline
cmdline_full+=$cmdline_post

net_cmd+=" -net nic "


cmd+=$net_cmd
cmd+="-m $RAM -smp $SMP "

if [ ! -z "$kernel_cmd" ]
then
	cmd+=$kernel_cmd
	cmd+="-append "
	cmd+=$cmdline_full
fi

echo $cmd
while [ "$FOLDER_AMT" -gt 0 ]
do
	FOLDER_AMT=$(($FOLDER_AMT - 1))
	echo
	echo "==========================================================================="
	echo "to mount your folder in the guest run the following command"
	echo "mount -t 9p -o trans=virtio,version=9p2000.L host$FOLDER_AMT <desired path>"
	echo "==========================================================================="
done

if [ "$SPICE_CMD" != "" ]
then
	echo "==========================================================================="
	echo -e $SPICE_CMD
	echo "==========================================================================="
fi

if [ $PAUSE -eq 1 ]
then
	sleep 3
fi

eval $cmd