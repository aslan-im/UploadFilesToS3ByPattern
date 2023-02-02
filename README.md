# Upload Files to S3 Bucket by Pattern
A script for uploading files to an S3 bucket based on a specific prefix defined in the configuration file. The script will scan the target path for files with the specified prefix, and then upload those files to the designated S3 bucket. The output will be logged in a log file for future reference.

# Requirements
- AWS.Tools.Common
- AWS.Tools.S3
- Logging module

# Inputs
Configuration file containing the necessary parameters such as file prefixes, target path, and S3 bucket name.

# Outputs
Log file containing the status and progress of the file upload process.

# Usage
1. Clone or download the repository to your local machine.
2. Make sure you have the required modules installed on your machine.
3. Fill in the necessary parameters in the configuration file.
4. Run the script in PowerShell.

# Notes
Owner: Aslan Imanalin  
Github: @aslan-im