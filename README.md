# MacOS_Tools
Bash script for deploying and documenting MacOS builds



# What
A shell script that
- Optimise MacOS for Media Composer
- Set IP addresses based on ipconfig.csv file. Name is important, IP addresses set by matching to hostname
- Creates a Macs-at-a-Glance.csv file with commonly documented Mac details (customer documentation)
- Can be copied and pasted directly into build document in this folder
	- Creates a Apple System Profile
	- Creates a CSV file with Application details
	- Creates a CSV file with Pro Tools AAX details

# How to Use
Steps
1.	Open ‘Terminal’
2.	Type ‘bash’ followed by a single space into terminal and drag and drop ‘MacOS_xxxxx’ into terminal.
3.	Hit the Enter key on your keyboard, select option 3 and hit enter again
4.	An output folder called ‘Inventory’ should appear in the same location as the bash script


# Setting IP addresses
1. Fill out ifconfig.csv file and save to same directory script is run in
2. Run script on target & set hostname
3. Choose configure IP address option


# Creating Inventory
Files will be created in the same directory as the script
Can be run directly from a USB stick and moved between Macs. 
Each Mac will generate a new folder and append the master inventory file
