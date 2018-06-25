#!/bin/bash
readonly PROG_NAME=$(basename $0)
readonly PROG_DIR=$(dirname $(realpath $0))
readonly INVOKE_DIR=$(pwd)
readonly ARGS="$@"
PRJ_PATH=""
SELECTED_HOST=""
TGT_HOST=""
SRC_HOST=""
SRC_BOX=""
TGT_BOX=""
NO_CLEAN=""
KEY_FILE=""
ACCOUNT=""
SRC_PATH=""

readonly HELP="$(cat <<EOF
Utility to maintain box in all hosts.

	help	Show this help message
	build	Build a box for host(s)
	list	List all boxes in all hosts
	copy	Copy a box from one host to another
	move	Move a box from one host to another
	delete	Delete box from one host
	
EOF
)"
function help {
    echo "Usage: $PROG_NAME [-h | --help] build|copy|delete|move"
    echo "$HELP"
    exit 0
}

readonly HELP_build="$(cat <<EOF
Utility to build or list box in all hosts.

	-h|--help           Show this help message
	-p|--project-path   Specify project path, critical
	--host              Specify single host to build box, optional
	--name              Specify vm name to build box, optional

	-nc|--no-clean      Keep temporary building outputs, optional
	
EOF
)"
function help_build {
    echo "Usage: $PROG_NAME build|list [-h|--help] [-p|--project-path] [--host] [--name] [-nc|--no-clean]"
    echo "$HELP_build"
    exit 0
}

readonly HELP_copy_or_move="$(cat <<EOF
Utility to copy or move box between hosts.

	-h|--help           Show this help message
	-p|--project-path   Specify project path, critical
	-sh|--source-host   Required host name to copy box from
	-sb|--source-box    Required box name to copy box from
	-th|--target-host   Required host name to copy box to
	
EOF
)"
function help_copy_or_move {
    echo "Usage: $PROG_NAME copy|move [-h|--help] [-p|--project-path] [-sh|--source-host] [-sb|--source-box] [-th|--target-host] [-tb|--target-box]"
    echo "$HELP_copy_or_move"
    exit 0
}

readonly HELP_delete="$(cat <<EOF
Utility to delete box from host.

	-h|--help           Show this help message
	-p|--project-path   Specify project path, critical
	-th|--target-host   Required host name to copy box to
	-tb|--target-box    Required box name to copy box to
	
EOF
)"
function help_delete {
    echo "Usage: $PROG_NAME delete [-h|--help] [-p|--project-path] [-th|--target-host] [-tb|--target-box]"
    echo "$HELP_delete"
    exit 0
}

cmd="$1"
shift
case $cmd in
	help)
		help
		;;
	build | list)
		while [[ $# > 0 ]]; do
			key="$1"
			case $key in
				-h | --help)
					help_build
					;;
				--host)
					SELECTED_HOST="$2"
					shift
					;;
				--name)
					SELECTED_NAME="$2"
					shift
					;;
				-p | --project-path)
					PRJ_PATH="$2"
					shift
					;;
				-nc | --no-clean)
					NO_CLEAN="yes"
					shift
					;;
				*)
					# unknown option
					echo "Unknown option $1. Please use $PROG_NAME $cmd --help"
					exit 1
					;;
			esac
			shift # past argument or value
		done
		;;
	copy | move)
		while [[ $# > 0 ]]; do
			key="$1"
			case $key in
				-h | --help)
					help_copy_or_move
					;;
				-p | --project-path)
					PRJ_PATH="$2"
					shift
					;;
				-sh | --source-host)
					SRC_HOST="$2"
					shift
					;;
				-sb | --source-box)
					SRC_BOX="$2"
					shift
					;;
				-th | --target-host)
					TGT_HOST="$2"
					shift
					;;
				*)
					# unknown option
					echo "Unknown option $1. Please use $PROG_NAME $cmd --help"
					exit 1
					;;
			esac
			shift # past argument or value
		done
		if [ "$SRC_HOST" == "" ] || [ "$SRC_BOX" == "" ] || [ "$TGT_HOST" == "" ]; then		
			echo You have to assign source host, source box, target host.
			echo  Please use \"$PROG_NAME $cmd --help\"
			exit 1
		fi
		;;
	delete)
		while [[ $# > 0 ]]; do
			key="$1"
			case $key in
				-h | --help)
					help_delete
					;;
				-p | --project-path)
					PRJ_PATH="$2"
					shift
					;;
				-th | --target-host)
					TGT_HOST="$2"
					shift
					;;
				-tb | --target-box)
					TGT_BOX="$2"
					shift
					;;
				*)
					# unknown option
					echo "Unknown option $1. Please use $PROG_NAME $cmd --help"
					exit 1
					;;
			esac
			shift # past argument or value
		done
		if [ "$TGT_HOST" == ""] ||[ "$TGT_BOX" == "" ]; then		
			echo You have to assign target host and target box.
			echo  Please use \"$PROG_NAME $cmd --help\"
			exit 1
		fi
		;;
	*)
		# unknown option
		echo "Unknown option $1. Please use $PROG_NAME help"
		exit 1
		;;
esac

if [ "$PRJ_PATH" == "" ]; then		
	echo You must assigne a project path
	exit 1
fi

readonly globalfile=$(realpath $PRJ_PATH/global.json)
readonly PROJECT_DIR=$(dirname $globalfile)
readonly PROJECT=$(jq '.project' -r < $globalfile)
readonly configfile=$(echo "$PROJECT_DIR/project.json")
readonly BUILDER_BOX=$(jq '.builder.box' -r < $globalfile)
readonly BUILDER_NIC=$(jq '.builder.nic' -r < $globalfile)
readonly SRC_PATH=$(jq '.|select(.resource!=null)|"\(.resource.site)/raw/\(.resource.tag)"' -r < $globalfile)

echo "Project Path is \"$PROJECT_DIR\""
echo "Global configuration file is \"$globalfile\""
echo "Project configuration file is \"$configfile\""
echo "Builder Box is $BUILDER_BOX"
echo "Builder NIC is $BUILDER_NIC"
if [ "$SRC_PATH" !=  ""  ] ; then
	echo "Resource base url is $SRC_PATH"
fi
if [ "$SELECTED_NAME" !=  ""  ] ; then
	echo "VM name filter is $SELECTED_NAME"
fi
function runsshcmd() {
	hoster=$1
	cmd=$2
	ssh $KEY_FILE $ACCOUNT@$hoster "$cmd"
}

function runcpcmd() {
	hoster=$1
	src=$2
	dst=$3
	scp $KEY_FILE -p $src $ACCOUNT@$hoster:$dst
}

function procedure_copy_or_move() {
	echo "This function is not implemented yet"
	#echo Begin to $cmd box...
	# make a clean vm first
	# export vm to package
	# copy to host
	# import box
	#echo End of $cmd.
	exit 0
}

function procedure_delete() {
	echo Deleting box $TGT_BOX in $TGT_HOST...
	#local=$(echo `hostname` | tr '[a-z]' '[A-Z]')
	local=`hostname`
	if [ "$local" != "$TGT_HOST" ]; then		
		cri=".hosts[]|select(.host==\"$TGT_HOST\")|.account,.keyfile"
		hostinfo=($(jq "$cri" -r < $globalfile))
		ACCOUNT=${hostinfo[0]}
		kf=${hostinfo[1]}
		if [ "$kf" != "null" ]; then
			KEY_FILE=" -i $kf "
		fi
		runsshcmd $TGT_HOST "vagrant box remove -f $TGT_BOX"
	else
		vagrant box remove -f $TGT_BOX
	fi
	exit 0
}

function procedure_list() {
	echo Begin to $cmd box...

	echo
	if [ "$SELECTED_HOST" != "" ]; then		
		echo You choose to run host $SELECTED_HOST only
	fi
	echo Getting vagrant box list in selected host\(s\)...
	#local=$(echo `hostname` | tr '[a-z]' '[A-Z]')
	local=`hostname`
	#echo Local hostname $local
	declare -A hostarr
	#hostarr[$local]=$(vagrant box list)

	cri=".[]|select(.host!=null)|.host"
	hosts=$(jq "$cri" -r <$configfile)
	for i in ${hosts[@]}
	do
		build=1
		for j in "${!hostarr[@]}"; do
			#echo "$j  ${i}"
			if [[ "$j" = "${i}" ]]; then
				#echo "${i} exists"
				build=0
			fi
		done
		if [ "$SELECTED_HOST" != "" ]&& [ "$SELECTED_HOST" != "$i" ]; then		
			build=0
		fi
		if [[ "$build" = "1" ]]; then
			cri=".hosts[]|select(.host==\"${i}\")|.account,.keyfile"
			hostinfo=($(jq "$cri" -r < $globalfile))
			ACCOUNT=${hostinfo[0]}
			kf=${hostinfo[1]}
			if [ "$kf" != "null" ]; then
				KEY_FILE=" -i $kf "
			fi
			if [ "$local" == "$i" ]; then
				boxlist=$(vagrant box list)
			else 
				boxlist=$(runsshcmd "$i" "vagrant box list")
			fi			
			hostarr+=( ["$i"]="$boxlist")
		fi
	done
	for key in ${!hostarr[@]}; do
		echo 
		echo Boxes in ${key}:
		x=(${hostarr[${key}]})
		for ((k=0;k< ${#x[@]}; k+=3))
		do
			echo -e ' \t' ${x[k]}
		done
	done
	echo
	exit 0
}

function copy_resource() {
	srcpath=$1
	fname=$2
	dst=share/$(basename $fname)
	echo $dst
	if [[ -f share/$fname ]]; then
		echo "use local file share/$fname"
	else
		if [ $SRC_PATH!="" ]; then
			curl -s -o share/$fname $SRC_PATH/$srcpath/$fname
			res=$(curl --write-out %{http_code} -s -o $dst $SRC_PATH/$srcpath/$fname)
			echo "$SRC_PATH/$srcpath/$fname [$res]"
		else
			echo "file $srcpath/$fname does not exist."

			exit 1
		fi
	fi
}

function procedure_build() {
	echo Begin to Build boxes for project $PROJECT

	echo 
	echo Validating configuration file format...
	{
		x=$(jq '.' < $configfile)
		echo "Configuration file looks OK"
	}||
	{
		echo "Configuration File Validation Failed!"
		exit 1
	}

	echo
	if [ "$SELECTED_HOST" != "" ]; then		
		echo You choose to run host $SELECTED_HOST only
	fi
	echo Getting vagrant box list in selected host\(s\)...
	local=`hostname`
	declare -A hostarr
	if [ "$SELECTED_NAME" != "" ]; then
		cri=".[]|select(.host!=null)|select(.name==\"$SELECTED_NAME\")|.host"
	else
		cri=".[]|select(.host!=null)|.host"
	fi
	hosts=$(jq "$cri" -r <$configfile)
	for i in ${hosts[@]}
	do
		build=1
		for j in "${!hostarr[@]}"; do
			echo "$j  ${i}"
			if [[ "$j" = "${i}" ]]; then
				echo "${i} exists"
				build=0
			fi
		done
		if [ "$SELECTED_HOST" != "" ]&& [ "$SELECTED_HOST" != "$i" ]; then		
			build=0
		fi
		if [[ "$build" = "1" ]]; then
			cri=".hosts[]|select(.host==\"${i}\")|.account,.keyfile"
			hostinfo=($(jq "$cri" -r < $globalfile))
			ACCOUNT=${hostinfo[0]}
			kf=${hostinfo[1]}
			if [ "$kf" != "null" ]; then
				KEY_FILE=" -i $kf "
			fi
			if [ "$local" == "$i" ]; then
				boxlist=$(vagrant box list)
			else 
				boxlist=$(runsshcmd "$i" "vagrant box list")
			fi			
			hostarr+=( ["$i"]="$boxlist")
		fi
	done
	for key in ${!hostarr[@]}; do
		echo ${key} ${hostarr[${key}]}
	done

	echo
	echo Checking invalid box usage in configuration file...
	proceed=1
	for key in ${!hostarr[@]}; do
		cri=".[]|select(.host==\"${key}\")|select(.box!=null)|select(.box.script==null)|select(.box.title|inside(\"${hostarr[${key}]}\")|not)|\"box(\(.box.title)) of \(.name) does not exist on \(.host)\""
		#echo $cri
		checks=$(jq -r "$cri" <$configfile)
		if [ "[$checks]" != "[]" ] ; then
			echo "$checks"
			proceed=0
		fi
	done
	if [ "$proceed" == "0" ] ; then
			exit 1
	fi
	echo 
	echo Preparing to load provision script for basevm...
	declare -A boxarr
	for key in ${!hostarr[@]}; do
		if [ "$SELECTED_NAME" != "" ]; then
			cri=".[]|select(.host==\"${key}\")|select(.name==\"$SELECTED_NAME\")|select(.box.title!=null)|select(.box.script!=null)|.box.title"
		else
			cri=".[]|select(.host==\"${key}\")|select(.box.title!=null)|select(.box.script!=null)|.box.title"
		fi
		#echo $cri
		bases=$(jq "$cri" -r <$configfile)
		#echo $bases
		for i in ${bases[@]}
		do
			build=1
			for j in "${!boxarr[@]}"; do
				if [[ "$j" = "$i" ]]; then
					build=0
				fi
			done
			if [[ "$build" = "1" ]]; then

				cri=".[]|select(.host==\"${key}\")|select(.box.title==\"$i\")|.box.script[]"
				#echo "$cri"
				checks=$(jq "$cri" -r <$configfile)
				#echo $checks

				#echo "add $i with $checks"
				boxarr+=( ["$i"]="$checks")
			fi
		done
	done
	cd $PROJECT_DIR/basevm
	mkdir -p share
	pwd 
	for key in ${!boxarr[@]}; do
		script=(${boxarr[${key}]})
		for ((k=0;k< ${#script[@]}; k++))
		do
			echo Use ${script[k]} to provision box ${key}
			copy_resource "scripts" "${script[k]}"
		done
	done

	for key in "${!boxarr[@]}"; do

		cri=".[]|select(.box.title==\"${key}\")|select(.box.script!=null)|select(.box.files!=null)|.box.files[]"
		files=$(jq -r "$cri" <$configfile)
		if [[ "$files"!="" ]]; then
			echo
			echo Validating files...
			fileary=($files)
			for ((k=0;k< ${#fileary[@]}; k++))
			do
				copy_resource "basevm" "${fileary[k]}"
			done
		fi

		script=(${boxarr[${key}]})
		echo
		echo Creating basevm for box $key...
		provisions=""
		for ((k=0;k< ${#script[@]}; k++))
		do
			provisions+="	basevm.vm.provision \"shell\", inline: \". /home/vagrant/share/${script[k]}\"\n"
		done
		sed -e "s|<box>|$BUILDER_BOX|g" $PROG_DIR/Vagrantfile.base.template > Vagrantfile.tmp1
		sed -e "s|<nic>|$BUILDER_NIC|g" Vagrantfile.tmp1 > Vagrantfile.tmp2
		sed -e "s|<ScriptFiles>|$provisions|g" Vagrantfile.tmp2 > Vagrantfile
		vagrant destroy -f
		vagrant up --no-provision
		vagrant vbguest
		vagrant up
		up_status=$?
		if [ $up_status != 0 ]; then
			echo "Failed to bring up a template vm, please try running again."
				#clean_up
				exit $up_status
		fi

		cri=".[]|select(.box.title==\"${key}\")|select(.box.script!=null)|.box.prefix"
		checks=$(jq -r "$cri" <$configfile)
		if [ "$checks" == "yes" ] ; then
			boxname=$PROJECT-$key.box
		else
			boxname=$key.box
		fi
		echo "Packaging basevm to $boxname..."
		rm -f $boxname
		vagrant package --output "$boxname"
	done

	echo 
	echo Importing box into selected host\(s\)...
	for key in "${!boxarr[@]}"; do
		cri=".[]|select(.box.title==\"${key}\")|select(.box.script!=null)|.host, if \"\(.box.prefix)\" == \"yes\" then \"$PROJECT-\(.box.title)\" else \"\(.box.title)\" end"
		#echo $key $cri
		checks=$(jq -r "$cri" <$configfile)
		if [ "[$checks]" != "[]" ] ; then
			x=($checks)
			hoster=${x[0]}
			boxname=${x[1]}
			echo
			echo importing $boxname into $hoster..
			if [ "$local" != "$hoster" ] ; then
				cri=".hosts[]|select(.host==\"$hoster\")|.account,.keyfile"
				hostinfo=($(jq "$cri" -r < $globalfile))
				ACCOUNT=${hostinfo[0]}
				kf=${hostinfo[1]}
				if [ "$kf" != "null" ]; then
					KEY_FILE=" -i $kf "
				fi
				runsshcmd "$hoster" "vagrant box remove -f $boxname"
				echo Copy package to $hoster
				runsshcmd $hoster 'mkdir ~/globaltemp'
				runcpcmd $hoster "$boxname.box" "~/globaltemp/"
				echo Importing box to $hoster vagrant
				runsshcmd $hoster "vagrant box add $boxname ~/globaltemp/$boxname.box"
				echo Remove package in $hoster
				runsshcmd "$hoster" "rm -f ~/globaltemp/$boxname.box"
			else
				echo "Processing box in Local $hoster"
				vagrant box remove -f "$boxname"
				echo Importing box to vagrant
				vagrant box add "$boxname" "$boxname.box"
				echo Remove package in $hoster
			fi
		fi
	done


	if [ "$NO_CLEAN" != "yes" ] ; then
		echo Clearing Temporary Building File...
		vagrant destroy -f
		rm -f Vagrantfile
		rm -f Vagrantfile.*
		rm -f *.box
	else
		echo Keep Temporary Building Files
	fi

	cd $INVOKE_DIR

	echo End of building boxes for project $PROJECT.
}

case $cmd in
	build)
		procedure_build
		;;
	list)
		procedure_list
		;;
	copy | move)
		procedure_copy_or_move
		;;
	delete)
		procedure_delete
		;;
esac
