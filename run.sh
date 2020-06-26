RAM=8G
SMP=8
FOLDER_AMT=0

SPICE="-device virtio-serial-pci -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 "
SPICE+="-chardev spicevmc,id=spicechannel0,name=vdagent -spice unix,addr=/tmp/vm_spice.socket,disable-ticketing "
SPICE_CMD=""

DRVCNT=0
PAUSE=0
FAKE=0

APP=qemu-system-x86_64
#APP=kvm

cmd="$APP -cpu host -vga virtio -enable-kvm -serial stdio -soundhw hda -usb -device usb-tablet "

cmdline_pre="\"console=ttyS0 earlyprintk=serial "
cmdline_post=" rw nokaslr\" "
cmdline=""
kernel_cmd=""
net_cmd=""
port_cmd=""
ssh_cmd=""

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
			kernel_cmd+="-kernel linux/arch/x86/boot/bzImage "
			;;
		-i|--init)
			cmd+="-initrd $2 "
			shift
			;;
		-c|--cmdline)
			cmdline+=$2
			shift
			;;
		-fs|--fedora-server)
			cmdline+="root=/dev/mapper/fedora-root ro rd.lvm.lv=fedora/root "
			cmd+="-initrd fedora-server/initramfs.img "
			;;
		-fd|--fedora-desktop)
			cmdline+="root=/dev/mapper/fedora_localhost--live-root ro rd.lvm.lv=fedora_localhost-live/root "
			cmd+="-initrd fedora-desktop/initramfs.img "
			;;
		-p|--port)
			port_cmd+=",hostfwd=tcp::$2-:$3"
			shift
			shift
			;;
		-s|--ssh)
			ssh_cmd+=",hostfwd=tcp::$2-:22"
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
		--syzrepro)
			cmd+="-no-reboot "
			cmdline+="oops=panic nmi_watchdog=panic panic_on_warn=1 panic=1 "
			cmdline+="ftrace_dump_on_oops=orig_cpu rodata=n vsyscall=native "
			cmdline+="net.ifnames=0 biosdevname=0 kvm-intel.nested=1 "
			cmdline+="kvm-intel.unrestricted_guest=1 kvm-intel.vmm_exclusive=1 "
			cmdline+="kvm-intel.fasteoi=1 kvm-intel.ept=1 kvm-intel.flexpriority=1 "
			cmdline+="kvm-intel.vpid=1 kvm-intel.emulate_invalid_guest_state=1 "
			cmdline+="kvm-intel.eptad=1 kvm-intel.enable_shadow_vmcs=1 kvm-intel.pml=1 kvm-intel.enable_apicv=1 "
			cmdline_post=" rw\" "
			;;
		--fake)
			FAKE=1
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

fwd_cmd=$ssh_cmd
fwd_cmd+=$port_cmd

if [ ! -z $fwd_cmd ]
then
	net_cmd="-net user"
	net_cmd+=$fwd_cmd
	net_cmd+=" -net nic "
fi

cmdline_full=$cmdline_pre
cmdline_full+=$cmdline
cmdline_full+=$cmdline_post

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

if [ $FAKE -eq 0 ]
then
	eval $cmd
fi
