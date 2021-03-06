#!/usr/bin/env bash

function die_on_error()
{
	local rc=${1:-'missing'}
	local errmsg=${2:-'missing'}

	# DIE if status code is missing
	if [ "missing" = "$rc" ];
	then
		printf "Error %s\n" "You didn't send me an error code";
		exit `false`;
	fi

	# DIE if error message is missing	
	if [ "missing" = "$errmsg" ];
	then
		printf "Error %s\n" "You didn't send me an error message";
		exit `false`;
	fi

	if [ 0 -ne $rc ];
	then
		printf "Error: failed with exit status: %d and error message: %s\n" "$rc" "$errmsg";
		exit `false`;
	fi

	printf "Completed operation: %s\n" "$errmsg";
}

function confirm()
{
	read -r -p "${1:-Are you sure? [y/N]} " response
	case $response in
		[yY][eE][sS]|[yY]) 
			true
			;;
		*)
			false
		;;
	esac
}


function main()
{
	DEBUG=${1:-''}

	function devtools_setup() 
	{
		# Command Line Tools
		${DEBUG} sudo xcodebuild -license
		die_on_error $? "xcodebuild license"
	
		# Enable Developer Mode
		${DEBUG} sudo /usr/sbin/DevToolsSecurity -enable
		die_on_error $? "Enabling dev tools security"

		${DEBUG} sudo /usr/sbin/dseditgroup -o edit -t group -a staff _developer
		die_on_error $? "Add _developer to staff"
	}

	function install_homebrew()
	{
		# Homebrew
		${DEBUG} ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
		die_on_error $? "Homebrew installation"
	}

	function install_brew() 
	{
		${DEBUG} brew install $1
		die_on_error $? "${1} installation"
	}

	function install_gem()
	{
		${DEBUG} sudo gem install $1
		die_on_error $? "${1} installation"
	}

	# Brews
	function install_brews()
	{
		install_brew git
		install_brew wget
		install_brew xctool
		install_brew Caskroom/cask/java
		install_brew jenkins
	}

	# Gems
	function update_rubygems()
	{
		${DEBUG} sudo gem update --system
	}

	function install_gems()
	{
		install_gem cocoapods
		install_gem xcpretty
		install_gem shenzhen
	}
	
	function setup_cocoapods()
	{
		# Setup Cocoapods
		${DEBUG} pod setup
		die_on_error $? "Setup cocoapods"
	}
	
	function jenkins_setup()
	{
		# Jenkins Configuration
		${DEBUG} mkdir -p ~/Library/LaunchAgents
		${DEBUG} ln -sfv /usr/local/opt/jenkins/*.plist ~/Library/LaunchAgents
		die_on_error $? "Symlink Jenkins LaunchAgents"

		${DEBUG} chmod 600 /usr/local/opt/jenkins/*.plist
		die_on_error $? "Set correct permissions on Jenkins LaunchAgents"

		${DEBUG} sudo chown root /usr/local/opt/jenkins/*.plist
		die_on_error $? "Change Jenkins LaunchAgents ownership to root"

		# Start Jenkins
		${DEBUG} launchctl load ~/Library/LaunchAgents/homebrew.mxcl.jenkins.plist
		die_on_error $? "Start Jenkins"

		# Wait for Jenkins to start
		${DEBUG} sleep 20
	}
	
	function download_cli()
	{
		${DEBUG} curl -L -O http://localhost:8080/jnlpJars/jenkins-cli.jar
		die_on_error $? "Download Jenkins CLI"
	}

	function install_plugin()
	{
		${DEBUG} java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin $1
		die_on_error $? "$1 installation"
	}

	function install_plugins()
	{
		install_plugin xcode-plugin
		install_plugin github-oauth
		install_plugin build-timeout
		install_plugin mailer
		install_plugin git
		install_plugin cobertura
		install_plugin s3
		install_plugin ghprb
		install_plugin build-flow-plugin	
	}
	
	function restart_jenkins()
	{
		${DEBUG} java -jar jenkins-cli.jar -s http://localhost:8080/ restart
		die_on_error $? "Restart Jenkins"
		${DEBUG} sleep 20
	}
	
	confirm "Accept Xcode Terms and Conditions and enable developer mode? [Y/n]" && devtools_setup
	confirm "Install Hombrew? [Y/n]" && install_homebrew
	echo "Installing Brews"
	install_brews
	echo "Updating Rubygems"
	update_rubygems
	echo "Installing Gems"
	install_gems
	confirm "Setup cocoapods? [Y/n]" && setup_cocoapods
	echo "Setting up jenkins"
	jenkins_setup
	echo "Downloading jenkins-cli"
	download_cli
	echo "Installing plugins"
	install_plugins
	restart_jenkins
}

echo "---------------------------- Starting Setup ----------------------------"
echo "Please ensure that Xcode and the Command Line Tools are installed before"
echo "continuing."
echo "Command line tools can be installed with xcode-select --install."
echo "Xcode can be installed from the Mac App Store"
echo "------------------------------------------------------------------------"


confirm && main $@

