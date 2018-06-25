BT-Vagrant-Tool

Concept Chart
	https://d2mxuefqeaa7sj.cloudfront.net/s_180AC010986023A3833FC3BCDD084F5E17699B16BC940ABEF36304BCCBC076C3_1492081713197_file.png

Prerequisite Install
	Create non-password-ssh-key
		Each Vagrant Host  need a no-password-ssh login using rsa/dsa key. We use "btserver" as following sample user account to create a key:
		1. Check /home/user/.ssh/ if  key file is already generated.
		2. run ssh-keygen if no key file found
				ssh-keygen -t rsa
				Generating public/private rsa key pair.
				Enter file in which to save the key (/home/btserver/.ssh/id_rsa): 
				Created directory '/home/btserver/.ssh'.
				Enter passphrase (empty for no passphrase): remain empty
				Enter same passphrase again: remain empty
				Your identification has been saved in /home/btserver/.ssh/id_rsa.
				Your public key has been saved in /home/btserver/.ssh/id_rsa.pub.
				The key fingerprint is:
				3e:4f:05:79:3a:9f:96:7c:3b:ad:e9:58:37:bc:37:e4
		3. copy content of id_rsa.pub into clipboard
		4. login target machine using btserver
		5. open /home/btserver/.ssh/authorized_keys
		6. paste content of clipboard into end of line

	install vagrant
		Consider it already done.

	download this tool
		download and unzip bt-vagrant-tool.zip to preferred directory 
			http://btciservice.bluetechnology.com.tw:8080/share/s/lNyToVtRTweM2R_E59ZJtA
		or 
			http://paullin@dscgitlab/paullin/bt-vagrant-tool.git

	install shell tool jq
		A JSON parser used in shell.

		wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
		chmod +x ./jq
		cp jq /usr/bin

	Notice
		Operation under Windows OS has not been tested yet.

Create your own project 
	Project Template
		1. Copy and  rename the sample project folder under bt-vagrant-tool folder. Replace directory name "sample" with "your-project-name"
		2. Edit global.json in bt-vagrant-tool folder or the one under you project folder(recommended). do not change its structure or remove any item
	global attribute description
		{
			"project": your project name, must be exactly the same as project folder name
			"account": account to access all hosts using rsa/dsa ssh key
			"vagrantpath": base directory in which your porject path will be created
			"network": for example "192.168.1.", will be use to assign ip to vm
			"nic": "enp3s0", network device name, it depends on hardware of host machine
			"defaultbox": it will be used to create vm when no other box name is assigned.
		}

Project Settings
	you have to configure project and provide files needed during create vm.
	edit project attributes
		1. it is a JSON array, do not change it
		2. each item represents a kind of VM, add/remove item as you need
	attribute description
		{
		  "name": vagrant vmid and also hostname(with number) of vm
		  "size": number of vm
		   "box": vagrant box will be used to created vm
		   "box.title": box title
		  "box.prefix": "yes/no",
			  this attribute indicates that a box title has a prefix(project name)
		  "box.script": ["base_nxlog.sh"], in array format, 
			  this attribute indicates that a box will be created and added to vagrant box list of assigned host
		  "startip" :  start number of this group of vm, 1 based
		  "host": host name of this group of vm
		   "provision": ["initial_zk.sh"], in array format, 
			  put all scripts here to provision vm of this group
		  "alwaysrun": ["start_zk.sh"], in array format, 
			  put all scripts here to run every time vagrant up
		  "conf": ["zoo1.cfg", "zoo2.cfg", "zoo3.cfg"], in array format, 
			  will be copy into assigned host:~/share path
		  "jmx": use "yes" to specify JMX_PORT will be pass into provision scripts, port number is calculate by 9000 + startip + sequential order number of vm
		}    
	scripts and files
		1. Copy all script files needed to /scripts path under your project folder.
		2. Copy configuration file and any other files needed to /conf path under your project folder.
		3. If you plan to build box(es), copy configuration, script, and any other files needed to your project folder/basevm/share path
		4. Now, you are ready to deploy VM

Maintain boxes for project
	First, run global_box.sh help  under bt-vagrant-tool folder to get help

    Usage: global_box.sh [-h | --help] build|copy|delete|move
    Utility to maintain box in all hosts.
        help    Show this help message
        build   Build a box for host(s)
        list    List all boxes in all hosts
        copy    Copy a box from one host to another
        move    Move a box from one host to another
        delete  Delete box from one host

	there are 5 commands can be used: 

	build
		This command creates boxed and import into assigned hosts. Please use global_box.sh build —help to get more infomation about building boxed defined in project.json.

	list
		This command lists boxes in all hosts. Please use global_box.sh list —help to get more option information.

	copy
		This command copies a box into another host. Please use global_box.sh copy —help to get more option information.

	move
		This command moves a box into another host. Please use global_box.sh move —help to get more option information.

	delete
		This command removes a box from a host. Please use global_box.sh delete —help to get more option information.

Deploy your project
	1. First, run global_up.sh —help  under bt-vagrant-tool folder to get more command information.

	Usage: global_up.sh [-h | --help] [--config-path] [--host] [--stage] [--dns]
	Tool to bring up a vagrant cluster on local machine(s).

		-h | --help    Show this help message
		--config-path  Specify global.json file path, optional
		--host         Specify single host to run, optional
		--stage        Specify stage [up ,provision ,halt ,clean, status], optional
		--dns          Write ips into hosts for all vms, optional    

	2. Second, run global_up.sh with arguments --stage up , this will bring up VM in all host
	3. During test, run global_up.sh with arguments --host host-name , to run vagrant command in one host individually.
	4. After you finish testing VM, run global_up.sh with arguments --stage clean, this will destroy VM in all host.
