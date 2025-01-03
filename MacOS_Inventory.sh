#<------HOW TO USE------>
#1. Open Terminal
#2. Type "bash" Drag & drop MacOS_Inventory.sh" into Terminal. Hit Enter and follow promots

#<------WHAT IT DOES------>
#Queries the plist of MacOS Applications and audio plugins, outputting the name, version, developer and native arm compatability to a .csv file
#Gathers useful system information in a csv file including hostname, serial number, CPU, RAM, OS version, network interface, MAC address, IPv4 address, subnet mask and default gateway
#Gets .spx system profile
#originally written for Pro Tools systems but expanded to include other audio plugin formats. 

#<------Limitations------>
#apps with version numbers containing commas will have the comma removed on output. Theres likely a resolution with something like awk 
#method used to determine developer fails on some apps. This is a result of the structure of the queried plist string.

# Tom Snell

#<------Script starts here------>
#!/bin/bash

#<------Global------>
IFS=$'\n'
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
#mkdir /"${SCRIPT_DIR}"/"$(hostname)"/log
CSV_DIR="${SCRIPT_DIR}"/Inventory/"$(hostname -s)"
Inventory="${SCRIPT_DIR}""/Inventory"
hostname=$(hostname)
Inventory_Host="${Inventory}"/"$(hostname -s)"
InventoryCSV=/"${Inventory}"/"Macs-At-A-Glance.csv"

#<------CSV Inventory Function------>
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

#get information from system_profiler command and format output for csv. see if awk could completely replace grep 
macos_version=$(sw_vers -productVersion)
model_name=$(system_profiler SPHardwareDataType | grep "Model Name" | awk -F': ' '{print $2}')
Chip=$(system_profiler SPHardwareDataType | grep "Chip" | awk -F': ' '{print $2}')
Cores=$(system_profiler SPHardwareDataType | grep "Total Number of Cores" | awk -F': ' '{print $2}')
RAM=$(system_profiler SPHardwareDataType | grep "Memory" | awk -F': ' '{print $2}')
Serial_number=$(system_profiler SPHardwareDataType | grep "Serial Number (system)" | awk -F': ' '{print $2}')

#set loop to false for multiple interfaces if loop
loop=false

#convert subnet mask to decimeal
convert_hex_to_decimal() {
    subnet_mask_hex=$1
    if [ -z "$subnet_mask_hex" ]; then
            continue
    else
    subnet_mask_dec=$(printf "%d.%d.%d.%d" 0x${subnet_mask_hex:2:2} 0x${subnet_mask_hex:4:2} 0x${subnet_mask_hex:6:2} 0x${subnet_mask_hex:8:2})
    fi 
    echo "$subnet_mask_dec"
}

#Does not work as expected. Function not called
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
        
        # Only loop interface values. Probably not the cleanest way of doing this but it works
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

#<------Generalised app scan function------>
#app and plugin file paths
#au
AU_dir='/Library/Audio/Plug-Ins/Components'
AU_cut_dir='Components'
AU_csv="${CSV_DIR}/AU_plugins.csv"

#vst
VST_dir='/Library/Audio/Plug-Ins/VST'
VST_cut_dir='VST'
VST_csv="${CSV_DIR}/VST_plugins.csv"

#vst3
VST3_dir='/Library/Audio/Plug-Ins/VST3'
VST3_cut_dir='VST3'
VST3_csv="${CSV_DIR}/VST3_plugins.csv"

#aax
AAX_dir='/Library/Application Support/Avid/Audio/Plug-Ins'
AAX_cut_dir='Plug-Ins'
AAX_csv="${CSV_DIR}/AAX_plugins.csv"

#Applications
APP_dir='/Applications'
APP_cut_dir='Applications'
APP_csv="${CSV_DIR}/Applications.csv"

#pass through variables from all_app_scan function
function inventory_scan(){
  scan_dir=$1
  cut_dir=$2
  inventory_csv=$3

  printf "Plugin,Version,Developer,Native Arm,64-bit\n" | tr -d '"'>"$inventory_csv"
  #script occasionally began scannning before csv file had been generated, missing results
  sleep 2
  
  #might be able to comment this out but I put it here for a reason
#  cd "$scan_dir"

  for file in $(find "$scan_dir" -iname "Contents" -prune); do
    name="${file%.*}"
    version=`plutil -p "/$file/Info.plist" | grep CFBundleShortVersionString | tr -d ","`
    #some developers use different key for developer so outputs odd results. Possible to resolve but would be bespoke for each developer
    developer=`plutil -p "/$file/Info.plist" | grep CFBundleIdentifier | cut -f2 -d "."`
    #querry app binary type
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

    printf "${name#*$cut_dir/},${version#*>},${developer},$arm,$bit\n" | tr -d '"'>>"$inventory_csv"
  done
}

function all_app_scan(){
# Arrays of file paths
scan_dir=("$AU_dir" "$VST_dir" "$VST3_dir" "$AAX_dir" "$APP_dir")
cut_dir=("$AU_cut_dir" "$VST_cut_dir" "$VST3_cut_dir" "$AAX_cut_dir" "$APP_cut_dir")
inventory_csv=("$AU_csv" "$VST_csv" "$VST3_csv" "$AAX_csv" "$APP_csv")

# loop function passing through array varaibles
for ((i=0; i<${#scan_dir[@]}; i++)); do
    inventory_scan "${scan_dir[i]}" "${cut_dir[i]}" "${inventory_csv[i]}"
done
}
#<------CSV Sort Function------>
function sort_output(){
  #for all .csv in csv_dir 
  for csv_file in ${CSV_DIR}/*.csv; do
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

#<------System Profile Function------>
function system_profile(){
#get system profile
system_profiler -detailLevel full -xml > "${CSV_DIR}"/system_profile.spx 2> /dev/null
}

#<------Main Menu------>
printf "\n%.0s" {1..20}

echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo "*                                                         *"
echo "*             MacOS Inventory - Version 2.6               *"
echo "*                                                         *"
echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo "*                                                         *"
echo "*                   What does this do?                    *"
echo "*                                                         *"
echo "*   Generates a system inventory of this Mac, including:  *"
echo "*     - A system report                                   *"
echo "*     - Applications                                      *"
echo "*     - Audio Plugins                                     *"
echo "*                                                         *"
echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"

printf "\n%.0s" {1..3}
printf "Type a number and hit enter to choose an option\n\n"
echo "1. System Profile Only"
echo "2. System Profile & Application Inventory"
echo "3. System Profile, Application & Audio Plugins Inventory"
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
    inventory_scan "$APP_dir" "$APP_cut_dir" "$APP_csv"
    sort_output
    system_profile
    ;;
  3) 
    printf "\nThis may take a few minutes, please wait...\n\n\n"
    CSV_Inventory
    all_app_scan
    sort_output
    system_profile
    ;;
  *)
    exit
    ;;
esac
#chmod inventory in case script is run with sudo. Not necessary in this version of the script
#chmod -R 777 "$Inventory"
printf "\n----Scan Complete - Output folder location----\n" 
printf "\n${CSV_DIR}\n\n\n\n"