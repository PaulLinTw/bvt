#!/bin/bash
# bvt version scheme: major.minor
BVT_VERSION="1.5"
readonly PROG_NAME=$(basename $0)
readonly PROG_DIR=$(dirname $(realpath $0))
readonly INVOKE_DIR=$(pwd)
readonly ARGS="$@"
readonly argcount=9
SELECTED_HOST=""
SELECTED_STAGE=""
SELECTED_NAME=""
SKIP_COPY=""
PRJ_PATH=""
NO_CLEAN=""
KEY_FILE=""
ACCOUNT=""
SRC_PATH=""
OPEN_TAIL=""
BOX_SOURCE="centos"
REMOVE_LOOPBACK="false"

function cprint(){
echo -e $1
}

HColor="\e[1;36m"
NC="\e[0m"

function StageText(){
echo
cprint "\e[1;37m$1\e[0m"
echo
}

function WarningText(){
cprint "\e[1;33m$1\e[0m"
}

function ErrorText(){
cprint "\e[1;31m$1\e[0m"
}

readonly USAGE="Usage: $PROG_NAME [--help] [-p|--path] [-h|--host] [-n|--name] [-s|--stage] [-nc|--no-clean] [-sc|--skip-copy] [-v|--version] [-t|--tail]"
readonly HELP="$(cat <<EOF
Tool to manage virtual machine(s) on remote vagrant host(s).

    --help               Show this help message
    -v|--version         Show version information of BVT and dependancies, optional
    -p|--path            Specify project path which contains global.json file, critical
    -h|--host            Specify single host to run, optional
    -n|--name            Specify name of vm(s)to run, optional
    -s|--stage           Specify stage [up, provision, halt, reload, status,
                         global-status, clean, vbguest] to run, defalut option is status
    -bs|--box-source     Specify box source from [sles, centos(default)]
    -sc|--skip-copy      Skip process of copy or download files to hosts
    -nc|--no-clean       Keep Temporary Vagrantfiles, optional
    -t|--tail            Open log tailling console for all hosts, optional
    -rl|--remove-127001  Remove 127.0.0.1 hostname from /etc/hosts for all hosts, optional

EOF
)"

function help {
    echo "$USAGE"
    echo "$HELP"
    exit 0
}

while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		--help )
			help
			;;
		-h|--host)
			SELECTED_HOST="$2"
			shift
			;;
		-n|--name)
			SELECTED_NAME="$2"
			shift
			;;
		-p|--path)
			PRJ_PATH="$2"
			shift
			;;
		-bs|--box-source)
			BOX_SOURCE="$2"
			shift
			;;
		-s|--stage)
			SELECTED_STAGE="$2"
			shift
			;;
		-nc|--no-clean)
			NO_CLEAN="true"
			;;
		-sc|--skip-copy)
			SKIP_COPY="true"
			;;
		-cl|--color-legend)
			cprint "Color Legend: \e[1;37m[Step] \e[1;33m[Warning] \e[1;36m[Key Value] \e[1;31m[Error]\e[0m"
			exit 0
			;;
		-v|--version)
			vvg=$(vagrant -v)
			vjq=$(jq --version)
			cprint "BVT version: \e[1;36m${BVT_VERSION}\e[0m"
			cprint "Dependancies: \e[1;36m${vvg}, ${vjq}\e[0m"
			exit 0
			;;
		-t|--tail)
			OPEN_TAIL="true"
			;;
		-rl|--remove-127001)
			REMOVE_LOOPBACK="true"
			;;
        *)
            # unknown option
            echo "Unknown option $1"
            exit 1
            ;;
	esac
	shift # past argument or value
done

if [ "$PRJ_PATH" == "" ]; then		
	ErrorText "You must assign a project path"
	help
fi

readonly globalfile=$(realpath $PRJ_PATH/global.json)
readonly PROJECT_DIR=$(dirname $globalfile)
readonly PROJECT=$(jq '.project' -r < $globalfile)
readonly SRC_PATH=$(jq '.|select(.resource!=null)|"\(.resource.site)/\(.resource.tag)"' -r < $globalfile)
readonly TEMP_DIR=$PROJECT_DIR/temp
mkdir -p $TEMP_DIR

# Get unused symbol in file
# arg 1: filename
# return: string, null means no applicable symbol.
function getsymbol(){
	fn="$1"
	sym=('!' '%' '|' '/' '_' '+' ';'  '~')
	symlen=${#sym[@]}
	symbol=""
	rtl=$fn
	i=0
	while [ "$rtl" != "" -a "$i" -lt "$symlen" ]
	do
		s=${sym[$i]}
		rtl=$(grep $s $fn)
		i=$((i+1))
	done
	if [ "$rtl" == "" ]; then
		symbol=$s
	fi
	echo $symbol
}

# replace item by item value in global.replacement.*
# arg 1: 'project', 'conf' or 'scripts'
# arg 2: file
function replacement() {
	level="$1"
	to_replace="$2"
	symb=$(getsymbol $to_replace)
	if [ "$symb" == "" ]; then
		ErrorText "Can not replace file $to_replace, no applicable symbol."
	else
		cri=".replacement.$level|length"
		count=($(jq $cri -r < $globalfile))
		if [ $count -gt 0 ]; then
			#echo "Proceeding $level level file $to_replace replacement..."
			cri=".replacement.$level|keys[]"
			replacer=($(jq $cri -r < $globalfile))
			for pp in ${!replacer[@]}
			do
				rep=${replacer[$pp]}
				cri=".replacement.$level.$rep"
				val="$(jq $cri -r < $globalfile)"
				sedterm="s${symb}@${rep}${symb}${val}${symb}g"
				sed -i $sedterm $to_replace
			done
		fi
	fi
}

StageText "Begin to process vm(s) for project $PROJECT"
cp $PROJECT_DIR/project.json $TEMP_DIR/_project.json

# replace project
replacement "project" "$TEMP_DIR/_project.json"

readonly configfile=$(echo "$TEMP_DIR/_project.json")

cprint "Project Path is ${HColor}$PROJECT_DIR${NC}"
cprint "Global configuration file is ${HColor}$globalfile${NC}"
cprint "Project configuration file is ${HColor}$configfile${NC}"
if [ "$SRC_PATH" !=  ""  ] ; then
	cprint "Resource base url is ${HColor}$SRC_PATH${NC}"
fi

readonly NETWORK=$(jq '.network' -r < $globalfile)
cprint "IP Domain is ${HColor}${NETWORK}X${NC}"

domianname=$(jq '.domain' -r < $globalfile)
if [ "$domianname" ==  "null"  ] ; then
	cprint "Domain Name is ${HColor}undefined${NC}"
	domianname=""
else
	cprint "Domain Name is ${HColor}$domianname${NC}"
fi
readonly DOMAIN=$domianname

readonly NETTYPE=$(jq '.nettype' -r < $globalfile)
if [ "$NETTYPE" == "hostonly" ]; then		
	cprint "Second NIC in VM is ${HColor}$NETTYPE(private)${NC}"
else
	cprint "Second NIC in VM is ${HColor}bridged(public)${NC}"
fi
if [ "$SELECTED_NAME" !=  ""  ] ; then
	cprint "VM name filter is ${HColor}$SELECTED_NAME${NC}"
fi
if [ "$SELECTED_HOST" != "" ]; then		
	cprint "Host filter is ${HColor}$SELECTED_HOST${NC}"
fi
if [[ $REMOVE_LOOPBACK == "true" ]] ; then
	cprint "127.0.0.1 hostname will ${HColor}be removed from${NC} /etc/hosts."
else
	cprint "127.0.0.1 hostname will ${HColor}stay in${NC} /etc/hosts."
fi

cprint "Box Source is ${HColor}$BOX_SOURCE${NC}"

StageText "Validating configuration file format..."
{
	x=$(jq '.' < $configfile)
	echo "Configuration file looks OK"
}||
{
  	echo "Configuration File Validation Failed!"
	exit 1
}

# check out any empty field
function checknull() {
  	if [ "$1" !=  "$2"  ] ; then
		echo checking .$2
		cri=".[]| select(.$2|tostring|contains(\"null\"))|.$1,.$2"
  	else 
		echo checking .$1
		cri=".[]| select(.$1|tostring|contains(\"null\"))|.$1"
	fi	

	#echo "$cri"
	checks=$(jq "$cri" -r < $configfile )
	#echo {$checks}
  	if [ "[$checks]" != "[]" ] ; then
		for i in ${checks[@]}
		do
			if [ "$i" != "null" ] ; then
  				ErrorText "$i $2 must be assigned."
			fi
		done
		exit 1
  	else 
		echo .$2  is checked.		
	fi
}
StageText "Checking any empty field in configuration file..."
checknull "name" "name"
checknull "name" "size"
checknull "name" "startip"
checknull "name" "host"
checknull "name" "provision"
checknull "name" "alwaysrun"
checknull "name" "conf"

function buildhostnames(){
	prj=$1
	fn="$prj/global.json"
	glbcfg=$(realpath $fn)
	prjdir=$(dirname $glbcfg)
	prjname=$(jq '.project' -r < $glbcfg)
	prjcfg=$(echo "$prjdir/project.json")
	declare -A hostlist
	cri=".[]|select(.host!=null)|.host"
	hosts=$(jq "$cri" -r <$prjcfg)
	for i in ${hosts[@]}
	do
		build=1
		for j in "${!hostlist[@]}"; do
			#echo "$j  ${i}"
	   		if [[ "$j" = "${i}" ]]; then
	       		#echo "${i} exists"
				build=0
	   		fi
		done
	   	if [[ "$build" = "1" ]]; then
			cri=".[]|select(.host==\"${i}\")|.name,.size,.startip,.startid"
			items=$(jq "$cri" -r <$prjcfg)
			#echo $items
			if [ "[$items]" != "[]" ] ; then	
				hostlist+=( ["$i"]="$items")
			fi
	   	fi
	done
	#rtn=$'\n'
	rtn="\n"
	hnames="#project $prjname$rtn"
	for key in ${!hostlist[@]}; do
		#echo $key  
		x=(${hostlist[${key}]})
		for ((k=0;k< ${#x[@]}; k+=4))
		do
			vmname=${x[k]}
			vmsize=${x[k+1]}
			vmstartip=${x[k+2]}
			vmstartid=${x[k+3]}
			if [[ "$vmstartid" == "null" ]]; then
				vmstartid=1
			fi
			for ((i=1;i<=$vmsize; i++))
			do
				vmid=$(expr $vmstartid + $i - 1)
				addr=$(expr $vmstartip + $i)
				if [ "[$DOMAIN]" != "[]" ] ; then	
					hnames+="$NETWORK$addr		$vmname$vmid.$DOMAIN		$vmname$vmid$rtn"
				else
					hnames+="$NETWORK$addr		$vmname$vmid$rtn"
				fi
			done
		done
	done
	unset hostlist
	unset hosts
	echo $hnames
}

StageText "Processing hostnames of project $PRJ_PATH..."
hostnames=$(buildhostnames "$PRJ_PATH")
relatedPrj=$(jq '.relatedprojects' -r < $globalfile)
if [[ "$relatedPrj" == "["*"]" ]]; then		
	relatedPrj=$(jq '.relatedprojects[]' -r < $globalfile)
	for pp in ${relatedPrj[@]}; do
		echo Processing hostnames of project $pp...
		hostnames+=$(buildhostnames "$pp")
	done
fi
printf "$hostnames"
printf "$hostnames" > $TEMP_DIR/hostnames

declare -A hostarr

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
			
		cri=".[]|select(.host==\"${i}\")|.name,.size, if .box.prefix == \"yes\" then \"$PROJECT-\(.box.title)\" else .box.title end,.startip,.jmx,.startid,.cpu,.memory,.disk"
		#echo $cri
		items=$(jq "$cri" -r <$configfile)
		#echo $items
		if [ "[$items]" != "[]" ] ; then	
			#echo add $items for $i
			hostarr+=( ["$i"]="$items")
		fi
   	fi
done
StageText "Creating Vagrantfile..."
for key in ${!hostarr[@]}; do

	cri=".hosts[]|select(.host==\"$key\")|.nic,.defaultbox"
	hostinfo=($(jq "$cri" -r < $globalfile))
	nic=${hostinfo[0]}
	base_box=${hostinfo[1]}
	script=""
	x=(${hostarr[${key}]})
	for ((k=0;k< ${#x[@]}; k+=$argcount))
	do
		vm_name=${x[k]}
		vm_size=${x[k+1]}
		vm_box=${x[k+2]}
		vm_startip=${x[k+3]}
		vm_jmx=${x[k+4]}
		vm_startid=${x[k+5]}
		vm_cpu=${x[k+6]}
		vm_mem=${x[k+7]}
		vm_disk=${x[k+8]}
		if [[ "$vm_startid" == "null" ]]; then
			vm_startid=1
		fi
		if [[ "$vm_mem" == "null" ]]; then
			vm_mem=2048
		fi
		if [[ "$vm_cpu" == "null" ]]; then
			vm_cpu=1
		fi
		if [[ "$vm_disk" == "null" ]]; then
			vm_disk=40
		fi
		script+="\n	num_$vm_name = $vm_size\n"
		script+="	(1..num_$vm_name).each { |i|\n"
		script+="		vmid = \($vm_startid+i-1\).to_s\n"
		script+="		name = \"$vm_name\" + vmid\n"
		script+="		dn = \"$DOMAIN\"\n"
		script+="		config.vm.define name do |$vm_name|\n"
		if [[ "$vm_box" != "null" ]]; then
			script+="			$vm_name.vm.box = \"$vm_box\"\n"
		else
			script+="			$vm_name.vm.box = \"$base_box\"\n"
		fi
		script+="			$vm_name.vm.provider \"virtualbox\" do |v|\n"
		script+="				v.memory = $vm_mem\n"
		script+="				v.cpus = $vm_cpu\n"
		script+="			end\n"
		script+="			$vm_name.disksize.size = '${vm_disk}GB'\n"
		script+="			$vm_name.vm.hostname = name\n"
		if [[ "$BOX_SOURCE" == "centos" ]]; then
			script+="			$vm_name.ssh.username   = \"vagrant\"\n"
			script+="			$vm_name.ssh.password   = \"vagrant\"\n"
			script+="			$vm_name.ssh.insert_key = \"false\"\n"
		fi
		script+="			$vm_name.vm.synced_folder \"$vm_name-share\", \"/home/vagrant/share\"\n"
		cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.bind"
		binds=$(jq "$cri" -r <$configfile)
		if [ "$binds" != "null" ] ; then
			cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.bind[]"
			binds=$(jq "$cri" -r <$configfile)
			for c in ${binds[@]}; do
				bindarr=($(echo $c | tr "," "\n"))
				script+="			$vm_name.vm.synced_folder \"${bindarr[0]}\", \"${bindarr[1]}\"\n"
			done
		fi
		script+="			ip_address = \"$NETWORK\" + \($vm_startip + i\).to_s\n"
		if [ "$NETTYPE" == "hostonly" ]; then		
			script+="			$vm_name.vm.network :private_network, ip: ip_address\n"
		else
			script+="			$vm_name.vm.network :public_network, ip: ip_address, bridge: \"$nic\"\n"
		fi
		if [[ "$vm_jmx" == "yes" ]]; then
			script+="			jmx_port_$vm_name =\(9000 + $vm_startip +i\).to_s\n"
		else
			script+="			jmx_port_$vm_name =\"\"\n"
		fi
		if (( $vm_disk > 40 )); then
			script+="			$vm_name.vm.provision \"shell\", path: \"./bvt_extend_disk.sh\", run:\"always\"\n"
		fi
		if [ $REMOVE_LOOPBACK == "true" ] ; then
			script+="			$vm_name.vm.provision \"shell\", path: \"./bvt_hosts.sh\", :args => [ name ], run:\"always\"\n"
		else
			script+="			$vm_name.vm.provision \"shell\", path: \"./bvt_hosts.sh\", run:\"always\"\n"
		fi
		cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.netdata"
		use_netdata=$(jq "$cri" -r <$configfile)
		if [[ "$use_netdata" != "null" ]]; then
			script+="			$vm_name.vm.provision \"shell\", path: \"./initial_netdata.sh\"\n"
			script+="			$vm_name.vm.provision \"shell\", path: \"./start_netdata.sh\", :args => [ \"$use_netdata\" ], run:\"always\"\n"
		fi
		cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.supervisor"
		use_supervisor=$(jq "$cri" -r <$configfile)
		#echo supervisor = $use_supervisor
		if [[ "$use_supervisor" != "null" ]]; then
			script+="			$vm_name.vm.provision \"shell\", path: \"./initial_supervisor.sh\"\n"
			if [[ "$use_supervisor" != "[]" ]]; then
				cri="on"
			else
				cri="off"
			fi
			#echo $cri
			script+="			$vm_name.vm.provision \"shell\", path: \"./start_supervisor.sh\", :args => [ \"$cri\" ], run:\"always\"\n"
		fi
		cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.provision[]"
		files=$(jq "$cri" -r <$configfile)
		for c in ${files[@]}; do
			script+="			$vm_name.vm.provision \"shell\", path: \"$vm_name-share/$c\", :args => [  vmid, ip_address, jmx_port_$vm_name, name, dn]\n"
		done

		cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.alwaysrun[]"
		files=$(jq "$cri" -r <$configfile)
		for c in ${files[@]}; do
			script+="			$vm_name.vm.provision \"shell\", path: \"$vm_name-share/$c\", :args => [  vmid, ip_address, jmx_port_$vm_name, name, dn], run:\"always\"\n"
		done
		script+="		end\n"
		script+="	}\n"
	done

	sed -e "s!<vm_enumeration>!$script!g" $PROG_DIR/Vagrantfile.main.template > $TEMP_DIR/Vagrantfile.$key

	cprint "$HColor$key$NC Vagrantfile created."
done

function runsshcmd() {
	svr=$1
	cmd=$2
	ssh $KEY_FILE $ACCOUNT@$svr "$cmd"
}

function runcpcmd() {
	svr=$1
	src=$2
	dst=$3
	#echo "scp $KEY_FILE -p $src $ACCOUNT@$svr:$dst"
	scp $KEY_FILE -p $src $ACCOUNT@$svr:$dst
}

function copy_src() {
	dsthost=$1
	srcpath=$2
	fname=$3
	dstpath=$4
	bname=$(basename $fname)
	toReplace=$TEMP_DIR/$bname
	if [[ -f $PROJECT_DIR/$srcpath/$fname ]]; then
		cp $PROJECT_DIR/$srcpath/$fname $toReplace
		replacement $srcpath $toReplace
		runcpcmd "$dsthost" "$toReplace" "$dstpath/$bname"
		#runcpcmd "$dsthost" "$PROJECT_DIR/$srcpath/$fname" "$dstpath/"
	else
		if [ $SRC_PATH!="" ]; then
			res=$(curl --write-out %{http_code} -s -o $toReplace $SRC_PATH/$srcpath/$fname)
			if [ "$res" == "200" ]; then
				replacement $srcpath $toReplace
				runcpcmd "$dsthost" "$toReplace" "$dstpath/$bname"
			else
				ErrorText "file $srcpath/$fname not found"
			fi
			#bname=$(basename $fname)
			#res=$(ssh $KEY_FILE $ACCOUNT@$svr "curl --write-out %{http_code} -s -o $dstpath/$bname $SRC_PATH/$srcpath/$fname")
			#echo "$SRC_PATH/$srcpath/$fname [$res]"
		else
			ErrorText "file $srcpath/$fname not found"
			exit 1
		fi
	fi
}

function copy_src_local() {
	srcpath=$1
	fname=$2
	dstpath=$3
	bname=$(basename $fname)
	toReplace=$TEMP_DIR/$bname
	if [[ -f $PROJECT_DIR/$srcpath/$fname ]]; then
		cp $PROJECT_DIR/$srcpath/$fname $toReplace
		replacement $srcpath $toReplace
		cp $toReplace $dstpath/$bname
		#cp $PROJECT_DIR/$srcpath/$fname $dstpath/
	else
		if [ $SRC_PATH!="" ]; then
			res=$(curl --write-out %{http_code} -s -o $toReplace $SRC_PATH/$srcpath/$fname)
			if [ "$res" == "200" ]; then
				replacement $srcpath $toReplace
				cp $toReplace $dstpath/$bname
			else
				ErrorText "file $srcpath/$fname not found"
			fi
			#res=$(curl --write-out %{http_code} -s -o $dstpath/$(basename $fname) $SRC_PATH/$srcpath/$fname)
			#echo "$SRC_PATH/$srcpath/$fname [$res]"
		else
			ErrorText "file $srcpath/$fname not found"
			exit 1
		fi
	fi
}

#local=$(echo `hostname` | tr '[a-z]' '[A-Z]')
local=`hostname`
if [ "$SKIP_COPY" != "" ]; then
	StageText "Skip copying and downloading files"
else
	StageText "Copy and Download files"
	for key in ${!hostarr[@]}; do
		hoster=$key
		cri=".hosts[]|select(.host==\"$key\")|.account,.keyfile,.vagrantpath"
		hostinfo=($(jq "$cri" -r < $globalfile))
		ACCOUNT=${hostinfo[0]}
		kf=${hostinfo[1]}
		if [ "$kf" != "null" ]; then		
			#echo you assigned ssh key file $kf
			KEY_FILE=" -i $kf "
		fi
		VAGRANTPATH=${hostinfo[2]}
		cprint "Copying files to host $HColor$hoster$NC..."
		if [ "$local" != "$hoster" ] ; then
			runsshcmd $hoster "mkdir -p $VAGRANTPATH/$PROJECT"
			runcpcmd $hoster "$TEMP_DIR/Vagrantfile.$hoster" "$VAGRANTPATH/$PROJECT/Vagrantfile"
			runcpcmd $hoster "$TEMP_DIR/hostnames" "$VAGRANTPATH/$PROJECT/"
			runcpcmd $hoster "$PROG_DIR/utilities/bvt_up.sh" "$VAGRANTPATH/$PROJECT/"
			runcpcmd $hoster "$PROG_DIR/utilities/bvt_extend_disk_$BOX_SOURCE.sh" "$VAGRANTPATH/$PROJECT/bvt_extend_disk.sh"
			runcpcmd $hoster "$PROG_DIR/utilities/bvt_hosts.sh" "$VAGRANTPATH/$PROJECT/"
			runcpcmd $hoster "$PROG_DIR/utilities/*_netdata.sh" "$VAGRANTPATH/$PROJECT/"
			runcpcmd $hoster "$PROG_DIR/utilities/*_supervisor.sh" "$VAGRANTPATH/$PROJECT/"
			runcpcmd $hoster "$PROG_DIR/utilities/incl.sh" "$VAGRANTPATH/$PROJECT/"
			x=(${hostarr[${key}]})
			for ((k=0;k< ${#x[@]}; k+=$argcount))
			do
				vm_name=${x[k]}
				runsshcmd $hoster "mkdir -p $VAGRANTPATH/$PROJECT/$vm_name-share"
				cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.provision"
				files=$(jq "$cri" -r <$configfile)
				if [ "$files" != "null" ] ; then
					cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.provision[]"
					files=$(jq "$cri" -r <$configfile)
					for c in ${files[@]}; do
						copy_src $hoster "scripts" "$c" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					done
				fi
				cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.alwaysrun"
				files=$(jq "$cri" -r <$configfile)
				if [ "$files" != "null" ] ; then
					cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.alwaysrun[]"
					files=$(jq "$cri" -r <$configfile)
					for c in ${files[@]}; do
						copy_src $hoster "scripts" "$c" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					done
				fi
				cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.conf"
				confs=$(jq "$cri" -r <$configfile)
				if [ "$confs" != "null" ] ; then
					cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.conf[]"
					confs=$(jq "$cri" -r <$configfile)
					for c  in ${confs[@]}; do
						copy_src $hoster "conf" "$c" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					done
				fi
				cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.supervisor"
				files=$(jq "$cri" -r <$configfile)
				if [ "$files" != "null" ]; then
					copy_src $hoster "conf" "supervisord.conf" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.supervisor[]"
					confs=$(jq "$cri" -r <$configfile)
					for c  in ${confs[@]}; do
						copy_src $hoster "conf" "$c" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					done
				fi
			done
		else
			mkdir -p $VAGRANTPATH/$PROJECT
			cp $TEMP_DIR/Vagrantfile.$hoster $VAGRANTPATH/$PROJECT/Vagrantfile
			cp $TEMP_DIR/hostnames $VAGRANTPATH/$PROJECT/
			cp $PROG_DIR/utilities/bvt_up.sh $VAGRANTPATH/$PROJECT/
			cp $PROG_DIR/utilities/bvt_extend_disk_$BOX_SOURCE.sh $VAGRANTPATH/$PROJECT/bvt_extend_disk.sh
			cp $PROG_DIR/utilities/bvt_hosts.sh $VAGRANTPATH/$PROJECT/
			cp $PROG_DIR/utilities/*_netdata.sh $VAGRANTPATH/$PROJECT/
			cp $PROG_DIR/utilities/*_supervisor.sh $VAGRANTPATH/$PROJECT/
			cp $PROG_DIR/utilities/incl.sh $VAGRANTPATH/$PROJECT/
			x=(${hostarr[${key}]})
			for ((k=0;k< ${#x[@]}; k+=$argcount))
			do
				vm_name=${x[k]}
				echo "vm_name=$vm_name"
				mkdir -p $VAGRANTPATH/$PROJECT/$vm_name-share
				cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.provision"
				files=$(jq "$cri" -r <$configfile)
				if [ "$files" != "null" ] ; then
					cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.provision[]"
					files=$(jq "$cri" -r <$configfile)
					for c in ${files[@]}; do
						echo $c
						copy_src_local "scripts" "$c" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					done
				fi
				cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.alwaysrun"
				files=$(jq "$cri" -r <$configfile)
				if [ "$files" != "null" ] ; then
					cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.alwaysrun[]"
					files=$(jq "$cri" -r <$configfile)
					for c in ${files[@]}; do
						echo $c
						copy_src_local "scripts" "$c" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					done
				fi
				cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.conf"
				confs=$(jq "$cri" -r <$configfile)
				if [ "$confs" != "null" ] ; then
					cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.conf[]"
					confs=$(jq "$cri" -r <$configfile)
					for c in ${confs[@]}; do
						echo $c
						copy_src_local "conf" "$c" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					done
				fi
				cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.supervisor"
				confs=$(jq "$cri" -r <$configfile)
				if [ "$confs" != "null" ]; then
					cri=".[]|select(.host==\"${key}\")|select(.name==\"$vm_name\")|.supervisor[]"
					confs=$(jq "$cri" -r <$configfile)
					copy_src_local "conf" "supervisord.conf" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					for c in ${confs[@]}; do
						echo $c
						copy_src_local "conf" "$c" "$VAGRANTPATH/$PROJECT/$vm_name-share"
					done
				fi
			done
		fi
	done
fi

if [ "$SELECTED_STAGE" == "" ]; then		
	SELECTED_STAGE="status"
fi
StageText "Running command"
for key in ${!hostarr[@]}; do
	hoster=$key
	cri=".hosts[]|select(.host==\"$key\")|.account,.keyfile,.vagrantpath"
	hostinfo=($(jq "$cri" -r < $globalfile))
	ACCOUNT=${hostinfo[0]}
	kf=${hostinfo[1]}
	if [ "$kf" != "null" ]; then		
		KEY_FILE=" -i $kf "
	else
		KEY_FILE=""
	fi
	VAGRANTPATH=${hostinfo[2]}
	NameList=""
	x=(${hostarr[${key}]})
	for ((k=0;k< ${#x[@]}; k+=$argcount))
	do
		vm_name=${x[k]}
		vm_size=${x[k+1]}
		vm_startid=${x[k+5]}
		if [[ "$vm_startid" == "null" ]]; then
			vm_startid=1
		fi
		if [ "$SELECTED_NAME" == $vm_name ]; then
			for ((s=0;s<$vm_size; s++))
			do
				nm=$(expr $vm_startid + $s)
				NameList+="$vm_name$nm "
			done			
		fi
	done
	if [ "$SELECTED_NAME" != "" ] && [ "$NameList" == "" ]; then
		cprint "No VM named $HColor$SELECTED_NAME$NC found in $HColor$hoster$NC, vagrant command ignored."
	else
		if [ "$NameList" != "" ]; then
			WithNames="--names $NameList"
		else
			WithNames=""
		fi
		cprint "Running bvt_up.sh $HColor$SELECTED_STAGE$NC command on host $HColor$hoster$NC"
		if [ "$local" != "$hoster" ] ; then
			if [ "$SELECTED_STAGE" == "status" ] || [ "$SELECTED_STAGE" == "global-status" ] ; then
				runsshcmd $hoster "$VAGRANTPATH/$PROJECT/bvt_up.sh --$SELECTED_STAGE $WithNames"
			else
				runsshcmd $hoster "$VAGRANTPATH/$PROJECT/bvt_up.sh --$SELECTED_STAGE $WithNames >> $VAGRANTPATH/log.$PROJECT &"
				if [ "$OPEN_TAIL" == "true" ]; then
					tilix -t "[$ACCOUNT@$hoster] $VAGRANTPATH/log.$PROJECT" --command="ssh $KEY_FILE $ACCOUNT@$hoster tail -f $VAGRANTPATH/log.$PROJECT"
				fi
			fi
		else
			if [ "$SELECTED_STAGE" == "status" ] || [ "$SELECTED_STAGE" == "global-status" ] ; then
				$VAGRANTPATH/$PROJECT/bvt_up.sh --$SELECTED_STAGE $WithNames
			else
				$VAGRANTPATH/$PROJECT/bvt_up.sh --$SELECTED_STAGE $WithNames >> $VAGRANTPATH/log.$PROJECT &
				if [ "$OPEN_TAIL" == "true" ]; then
					tilix -t "[localhost] $VAGRANTPATH/log.$PROJECT" --command="tail -f $VAGRANTPATH/log.$PROJECT"
				fi
			fi
		fi
	fi 
done
if [ "$SELECTED_STAGE" != "status" ] && [ "$SELECTED_STAGE" != "global-status" ] ; then
	echo
	cprint "Please tail ${HColor}log.$PROJECT$NC on selected host(s) to watch progress of vagrant command"
fi

if [ "$NO_CLEAN" == "true" ]; then
	StageText "Keep temporary file"
else
	StageText "Clean temporary file..."
	rm -r $TEMP_DIR
fi

StageText "End of vm(s) processing for project \"$PROJECT\""
