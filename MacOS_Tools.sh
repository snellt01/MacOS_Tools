#<------HOW TO USE------>
#1. Open Terminal
#2. Type "bash" Drag & drop "MacOS_Tools.sh" into Terminal. Hit Enter 

#This shell script queries the plist of MacOS Applications and Pro Tools .aax plugins, outputting the name, version, developer and native arm compatability to a .csv file

#Limitations
  #apps with version numbers containing commas will have the comma removed on output
  #method used to determine developer fails on some apps. This is a result of the structure of the queried plist string.

#Script starts here
#!/bin/bash

#Global 
IFS=$'\n'
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
#mkdir /"${SCRIPT_DIR}"/"$(hostname)"/log
CSV_DIR="${SCRIPT_DIR}"/Inventory/"$(hostname -s)"
Inventory="${SCRIPT_DIR}""/Inventory"
hostname=$(hostname)
Inventory_Host="${Inventory}"/"$(hostname -s)"
InventoryCSV=/"${Inventory}"/"Macs-At-A-Glance.csv"

#------------------------Hostname Configuration Function------------------------#
function set_hostname() {
read -p "Set hostname? (y/N)" confirm
if [ "$confirm" = "y" ]; then 
  read -p "Type hostname" host_name
  hostname $host_name
fi
}

#------------------------Network Configuration Function------------------------#
function check_network_csv() {

  configdocument=""$(dirname "${BASH_SOURCE[0]}")"/ipconfig.csv"
  hostname=$(hostname)

  # Extracting parameters from CSV based on hostname
  function set_network_config() {
    # Extracting parameters from CSV based on hostname
    interfacename=$(awk -F',' -v host="$hostname" '$1 == host {print $2}' $configdocument)
    ip_address=$(awk -F',' -v host="$hostname" '$1 == host {print $3}' $configdocument)
    subnet=$(awk -F',' -v host="$hostname" '$1 == host {print $4}' $configdocument)
    gateway=$(awk -F',' -v host="$hostname" '$1 == host {print $5}' $configdocument)
    dns1=$(awk -F',' -v host="$hostname" '$1 == host {print $6}' $configdocument)
    dns2=$(awk -F',' -v host="$hostname" '$1 == host {print $7}' $configdocument)
    ntp=$(awk -F',' -v host="$hostname" '$1 == host {print $8}' $configdocument)
    jumbo=$(awk -F',' -v host="$hostname" '$1 == host {print $9}' $configdocument)

    # Set network configuration
    networksetup -setmanual $interfacename $ip_address $subnet $gateway >/dev/null 2>&1
    networksetup -setdnsservers $interfacename $dns1 $dns2 >/dev/null 2>&1
    sudo networksetup -setmtu $interfacename $mtu >/dev/null 2>&1
    #Check if value is set in csv, set NTP server
    if [ -n "$ntp" ]; then
      sudo systemsetup -setusingnetworktime on >/dev/null 2>&1
      sudo systemsetup -setnetworktimeserver $ntp >/dev/null 2>&1
    else
      echo "NTP not set"
    fi 

    #check if MTU value exists in csv file, if so set it
    if [ "$jumbo" = Y ]; then
      sudo networksetup -setmtu $interfacename 9000 >/dev/null 2>&1
      echo "MTU set to 9000"
    elif [ "$jumbo" = N ]; then
      sudo networksetup -setmtu $interfacename 1500 >/dev/null 2>&1
      echo "MTU set to 1500"
    else
      echo "MTU not defined, skipped"
    fi     
  }

    # Check if CSV file exists
    if [ ! -f "$configdocument" ]; then
      echo "ERROR: CSV file $csv_file not found."
      echo "Hostname, Interface Name, IP Address, Subnet, Gateway, DNS 1, DNS 2, NTP, Jumbo Frames (Y/N/Blank)" > $configdocument
      echo "example-host, Terminal command to get network names: networksetup -listallnetworkservices, 10.0.1.100, 255.255.255.0, 10.0.1.1, 1.1.1.1, 8.8.8.8, uk.pool.ntp.org, Y=9000 N=1500 Blank=no change" >> $configdocument
      chmod 777 $configdocument
      echo "Template Config Document Generated"
      echo "Please complete config document and run again"
    else
        # Check if hostname exists in the CSV file
        if ! grep -q "^$hostname," "$configdocument"; then
            echo "ERROR: Hostname $hostname not found in the CSV file."
        else
          set_network_config
        fi
    fi
}


#------------------------Power Configuration Function------------------------#
function optimise_power_settings() {
systemsetup -setcomputersleep Never
systemsetup -setdisplaysleep Never
systemsetup -setharddisksleep Never
systemsetup -setrestartpowerfailure on
systemsetup -setwakeonnetworkaccess on
}

#------------------------Enable Screen Sharing Function------------------------#
function enable_screen_sharing() {
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -users localadmin -access -on -privs -all
}

#------------------------UI Settings Function------------------------#
function ui_tweaks() {
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowPathbar -bool true
killall Finder
}

#------------------------AVID Optimise Function------------------------#
function avid_optimise() {
sudo fdesetup disable
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -boolean FALSE
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist

}

#----------------------------------------------MacOS Inventory Start----------------------------------------------#
function MacOS_Inventory (){
  #------------------------CSV inventory function------------------------#
  function CSV_Inventory(){

  #create dir if it does nto exist
  if [ ! -d "$Inventory" ]; then
          mkdir -p "$Inventory"
  fi
  sleep 1
  if [ ! -d "$Inventory_Host" ]; then
          mkdir -p "$Inventory_Host"
  fi

  # Print header to CSV file
  if [ ! -e "$InventoryCSV" ]; then
      echo "Model, Hostname, Serial #, CPU, RAM, OS Version, Interface, Mac Address, IPv4 Address, Subnet Mask, Default Gateway" > "${Inventory}"/Macs-At-A-Glance.csv
  fi

  macos_version=$(sw_vers -productVersion)
  hostname=$(hostname)

  model_name=$(system_profiler SPHardwareDataType | grep "Model Name" | awk -F': ' '{print $2}')
  #model_ID=$(system_profiler SPHardwareDataType | grep "Model Identifier" | awk -F': ' '{print $2}')
  Chip=$(system_profiler SPHardwareDataType | grep "Chip" | awk -F': ' '{print $2}')
  Cores=$(system_profiler SPHardwareDataType | grep "Total Number of Cores" | awk -F': ' '{print $2}')
  RAM=$(system_profiler SPHardwareDataType | grep "Memory" | awk -F': ' '{print $2}')
  Serial_number=$(system_profiler SPHardwareDataType | grep "Serial Number (system)" | awk -F': ' '{print $2}')

  loop=false

  convert_hex_to_decimal() {
      subnet_mask_hex=$1
      if [ -z "$subnet_mask_hex" ]; then
              continue
      else
      subnet_mask_dec=$(printf "%d.%d.%d.%d" 0x${subnet_mask_hex:2:2} 0x${subnet_mask_hex:4:2} 0x${subnet_mask_hex:6:2} 0x${subnet_mask_hex:8:2})
      fi 
      echo "$subnet_mask_dec"
  }

  #a disaster
  get_dns_servers() {
      scutil --dns | awk -F': ' '/nameserver/ { dns_servers = dns_servers "," $2 } END { print substr(dns_servers, 2) }'
  }

  # Get the list of active network interfaces
  active_interfaces=$(ifconfig -lu | grep -o 'en[0-9]\+' | grep -E 'en[0-9]+' | sort -t 'n' -k2,2)

  for interface in $active_interfaces; do
      # Get network settings
      
      status=$(ifconfig "$interface" | awk '/status:/ {print $2}')
      
      # Check if the interface status is "active"
      if [ "$status" = "active" ]; then
          # Extract IPv4 address, Subnet Mask, Router, and DNS Servers using ifconfig
          MACAddr=$(ifconfig "$interface" | awk '/ether / {print $2}')
          ipv4_address=$(ifconfig "$interface" | awk '/inet / {print $2}')
          subnet_mask_hex=$(ifconfig "$interface" | awk '/inet / {print $4}')
          subnet_mask=$(convert_hex_to_decimal "$subnet_mask_hex")
          gateway=$(route -n get default -ifscope "$interface" | grep gateway | awk '{print $2}')
          # dns_servers=$(get_dns_servers "$interface")
          
          # Only loop interface values
          if [ "$loop" = false ]; then
              echo "$model_name,$hostname,$Serial_number,$Chip $Cores,$RAM,$macos_version,$interface,$MACAddr,$ipv4_address,$subnet_mask,$gateway" >> "${Inventory}"/Macs-At-A-Glance.csv
              loop=true
          else
              # Print network settings to CSV without macOS version
              echo ",,,,,,$interface,$MACAddr,$ipv4_address,$subnet_mask,$gateway" >> "${Inventory}"/Macs-At-A-Glance.csv
          fi
      fi
  done

  #echo "Mac Details written to "${Inventory}"/Macs-At-A-Glance.csv"
  }


  #------------------------AAX Scan Function------------------------#
  function aax_scan(){
    printf "Plugin,Version,Developer,Native Arm,64-bit\n" | tr -d '"'>"${CSV_DIR}"/aax_plugins.csv
    sleep 2
    aax_csv="${CSV_DIR}/aax_plugins.csv"
    AAX_DIR='/Library/Application Support/Avid/Audio/Plug-Ins'
    cd "$AAX_DIR"

    for file in $(find "$AAX_DIR" -iname "Contents" -prune); do
      name="${file%.*}"
      version=`plutil -p "/$file/Info.plist" | grep CFBundleShortVersionString | tr -d ","` 
      developer=`plutil -p "/$file/Info.plist" | grep CFBundleIdentifier | cut -f2 -d "."`
      #binary=`file "/$file/MacOS/${file//.aaaxplugin}"`
      binary=`file "/$file/MacOS"/*`
      if [[ $binary == *"arm64"* ]]; then
        arm="yes"
      else
        arm="no"
      fi
      if [[ $binary == *"64-bit"* ]]; then
        bit="64-bit"
      elif [[ $binary == *"32-bit"* ]]; then
        bit="32-bit"
      else
        bit="unknown"
      fi
      printf "${name#*Plug-Ins/},${version#*>},${developer},$arm,$bit\n" | tr -d '"'>>"$aax_csv"
      #printf "$binary\n" >> "${CSV_DIR}"/log/aax_debug.log
    done
  }


  #------------------------Apps Scan Function------------------------#
  function apps_scan(){
    printf "Application,Version,Developer,Native Arm,64-bit\n" | tr -d '"'>"${CSV_DIR}"/applications.csv 
    sleep 2
    apps_csv="${CSV_DIR}/Applications.csv"
    APP_DIR='/Applications'
    cd "$APP_DIR"

    for file in $(find "$APP_DIR" -iname "Contents" -prune); do
      name="${file%.*}"
      version=`plutil -p "/$file/Info.plist" | grep CFBundleShortVersionString | tr -d ","` 
      developer=`plutil -p "/$file/Info.plist" | grep CFBundleIdentifier | cut -f2 -d "."` 
      #binary=`file "/$file/MacOS/${file//.app}"`
      binary=`file "/$file/MacOS"/*`
      if [[ $binary == *"arm64"* ]]; then
        arm="yes"
      else
        arm="no"
      fi
      if [[ $binary == *"64-bit"* ]]; then
        bit="64-bit"
      elif [[ $binary == *"32-bit"* ]]; then
        bit="32-bit"
      else
        bit="unknown"
      fi
      printf "${name#*Applications/},${version#*>},${developer},$arm,$bit\n" | tr -d '"'>>"$apps_csv"
      #printf "$binary\n" >> "${CSV_DIR}"/log/app_debug.log
    done
  }


  #------------------------CSV Sort Function------------------------#
  function sort_output(){
  #loop through the array of CSVs to be sorted
  csv_files=("$aax_csv" "$apps_csv")
  for csv_file in "${csv_files[@]}"; do
      if [ ! -f "$csv_file" ]; then
        echo
        continue
      fi
        # extract the header row, only sorting the rows below
      header=$(head -n 1 "$csv_file")
        #sort rows by 3rd column 1st, then 1st column 2nd, f=case insensitve
      data_rows=$(tail -n +2 "$csv_file" | sort -t',' -k3,3f -k1,1f)
      echo "$header" > "$csv_file"
      echo "$data_rows" >> "$csv_file"
  done
  }


  #------------------------System Profile Function------------------------#
  function system_profile(){
  #get system profile
  system_profiler -detailLevel full -xml > "${CSV_DIR}"/system_profile.spx 2> /dev/null
  }


#------------------------MacOS Inventory Menu------------------------#

  printf "\n%.0s" {1..3}
  printf "Type a number and hit enter to choose an option\n\n"
  echo "1. System Profile Only"
  echo "2. System Profile & Application Inventory"
  echo "3. System Profile, Application & AAX Plugins Inventory (Audio)"
  #printf "\n%.0s" {1..1}
  read -r choice

  case "$choice" in
    1) 
      printf "\nThis may take a few minutes, please wait...\n\n\n"
      CSV_Inventory
      system_profile
      ;;
    2) 
      printf "\nThis may take a few minutes, please wait...\n\n\n"
      CSV_Inventory
      apps_scan
      sort_output
      system_profile
      ;;
    3) 
      printf "\nThis may take a few minutes, please wait...\n\n\n"
      CSV_Inventory
      aax_scan
      apps_scan
      sort_output
      system_profile
      ;;
    *)
      exit
      ;;
  esac
  chmod -R 777 "$Inventory"
  printf "\n----Scan Complete - Output folder location----\n" 
  printf "\n${CSV_DIR}\n\n\n\n"
}
#----------------------------------------------MacOS Inventory Code End----------------------------------------------#

#run all function 
function run_all() { 
  set_hostname 
  check_network_csv
  optimise_power_settings
  enable_screen_sharing
  avid_optimise
  ui_tweaks
  MacOS_Inventory
}

#------------------------Main Menu------------------------#
printf "\n%.0s" {1..20}

echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo "*                                                         *"
echo "*               MacOS Tools - Version 2.3                 *"
echo "*                                                         *"
echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo "Current Hostname: $hostname"
#echo "*                                                         *"
#echo "*                   What does this do?                    *"
#echo "*                                                         *"
#echo "*   Generates a system inventory of this Mac, including:  *"
#echo "*       - A system report                                 *"
#echo "*       - Applications                                    *"
#echo "*       - Pro Tools plugins                               *"
#echo "*                                                         *"
#echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"

while true; do
  printf "\n%.0s" {1..3}
  echo "Main Menu:"
  echo "I. Create System Inventory"
  echo "1. Set Hostname"
  echo "2. Configure Network from CSV"
  echo "3. Optimise Power Settings"
  echo "4. Enable Screen Sharing"
  echo "5. AVID Optimisations"
  echo "6. UI Tweaks"
  echo "A. Run all"
  echo "Q. Quit"
  read choice

  case $choice in
    1) set_hostname ;;
    2) check_network_csv ;;
    3) optimise_power_settings ;;
    4) enable_screen_sharing ;;
    5) avid_optimise;;
    6) ui_tweaks;;
    I|i) MacOS_Inventory ;;
    A|a) run_all ;; 
    Q|q) break  
      ;;
    *)
      echo "Invalid choice. Please enter a valid option."
      ;;
  esac
done

# Tom Snell