#!/bin/bash
readonly PROG_NAME=$(basename $0)
readonly PROG_DIR=$(dirname $(realpath $0))
readonly INVOKE_DIR=$(pwd)

readonly USAGE="Usage: $PROG_NAME [-h | --help] [--up] [--full] [--halt] [--reload] [--status] [--global-status] [--no-provision] [--provision] [--vbguest] [--clean] [--class] [--names]"
readonly HELP="$(cat <<EOF
Tool to bring up vm on local machine.

    -h | --help      Show this help message
    --up             Bring up vms
    --full           Bring up vms with --no-provision, vbguest and up stages
    --halt           Stop vms
    --reload         Reload vms
    --status         Show vm status
    --global-status  Show vm global-status
    --no-provision   Bring up vms with no-provision
    --provision      Bring up vms with provision
    --vbguest        update vm virtualbox guest additions
    --clean          Destroy all vm and remove directory $PROG_DIR
    --names          vagrant names, can be multiple, seperate by space

EOF
)"

function help {
    echo "$USAGE"
    echo "$HELP"
    exit 0
}

SelectedNames=""

cd $PROG_DIR
while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-h | --help | --up | --full | --provision | --status | --global-status | --clean | --vbguest | --halt | --reload | --no-provision)
			cmd=$key
			shift
			;;
		--names)
			shift
			while [[ $# > 0 ]] && [[ $1 != "-"* ]]; do
				SelectedNames+="$1 "
				shift # past argument or value
			done
			echo "with class name $SelectedNames"
			;;
		*)
			# unknown option
			echo "Unknown option $1"
			exit 1
			;;
	esac
done
case $cmd in
	-h | --help)
		help
		;;
	--up)
		echo Vagrant up
		if [ "$SelectedNames" != "" ]; then
			vagrant up $SelectedNames
		else
			vagrant up
		fi
		echo Complete Up
		;;
	--full)
		echo Vagrant up no-provision
		if [ "$SelectedNames" != "" ]; then
			vagrant up --no-provision $SelectedNames
		else
			vagrant up --no-provision
		fi
		echo Vagrant vbguest
		if [ "$SelectedNames" != "" ]; then
			vagrant vbguest $SelectedNames
		else
			vagrant vbguest
		fi
		echo Vagrant up
		if [ "$SelectedNames" != "" ]; then
			vagrant up $SelectedNames
		else
			vagrant up
		fi
		echo Complete Full
		;;
	--provision)
		echo Vagrant with provision
		if [ "$SelectedNames" != "" ]; then
			vagrant up --provision $SelectedNames
		else
			vagrant up --provision
		fi
		echo Complete Provision
		;;
	--status)
		echo Vagrant Status
		if [ "$SelectedNames" != "" ]; then
			vagrant status $SelectedNames
		else
			vagrant status
		fi
		echo Complete Status
		;;
	--global-status)
		echo Vagrant Status
		if [ "$SelectedNames" != "" ]; then
			vagrant global-status $SelectedNames
		else
			vagrant global-status
		fi
		echo Complete Status
		;;
	--clean)
		echo Destroy all vagrant vm
		if [ "$SelectedNames" != "" ]; then
			vagrant destroy -f $SelectedNames
		else
			vagrant destroy -f
			cd ~
			rm -rf $PROG_DIR
		fi
		echo Complete Destroy
		;;
	--vbguest)
		echo Update virtual box guest additions
		if [ "$SelectedNames" != "" ]; then
			vagrant vbguest $SelectedNames
		else
			vagrant vbguest
		fi
		echo Complete Update
		;;
	--halt)
		echo Halt all vm
		if [ "$SelectedNames" != "" ]; then
			vagrant halt $SelectedNames
		else
			vagrant halt
		fi
		echo Complete Halt
		;;
	--reload)
		echo Reload all vm
		if [ "$SelectedNames" != "" ]; then
			vagrant reload $SelectedNames
		else
			vagrant reload
		fi
		echo Complete Reload
		;;
	--no-provision)
		echo Vagrant up without provision
		if [ "$SelectedNames" != "" ]; then
			vagrant up --no-provision $SelectedNames
		else
			vagrant up --no-provision
		fi
		echo Complete Up without provision
		;;
esac


