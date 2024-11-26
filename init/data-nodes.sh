#!/bin/bash
set -e  # Stop the script if any command fails

LOGFILE="/var/log/influxdb-data-node-setup.log"
exec > >(tee -i "$LOGFILE") 2>&1  # Log both stdout and stderr to a file

echo "Starting InfluxDB data-node setup..."

# Update and install necessary packages
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y python3 wget jq nvme-cli
echo "System updated and required packages installed."

# Wait to ensure EBS volume attachment is complete
sleep 10

# Identify the unmounted disk dynamically
DISK=$(lsblk -nrdo NAME,TYPE | grep disk | awk '{print "/dev/" $1}' | grep -v nvme0n1)
if [ -z "$DISK" ]; then
  echo "No additional disk found. Exiting."
  exit 1
fi
echo "Detected disk: $DISK"

# Format attached disk if not already formatted
if ! blkid "$DISK"; then
  echo "Formatting disk $DISK..."
  sudo mkfs.ext4 "$DISK"
else
  echo "Disk $DISK is already formatted."
fi

# Create folders and mount disks
echo "Mounting $DISK to /mnt/influxdb/data..."
sudo mkdir -p /mnt/influxdb/data
if ! mountpoint -q /mnt/influxdb/data; then
  sudo mount "$DISK" /mnt/influxdb/data
else
  echo "/mnt/influxdb/data is already mounted."
fi

# Create /etc/fstab entry for persistent mount
if ! grep -q '/mnt/influxdb/data' /etc/fstab; then
  echo "Adding $DISK to /etc/fstab..."
  echo '# influxdb-data-disk' | sudo tee -a /etc/fstab
  echo "$DISK    /mnt/influxdb/data    ext4    defaults,nofail    0    2" | sudo tee -a /etc/fstab
fi

# Download, install, and start InfluxDB data-node
INFLUXDB_DATA_VERSION="1.11.8-c1.11.8-1"
INFLUXDB_DATA_DEB="influxdb-data_${INFLUXDB_DATA_VERSION}_amd64.deb"
INFLUXDB_DATA_URL="https://dl.influxdata.com/enterprise/releases/${INFLUXDB_DATA_DEB}"

echo "Downloading InfluxDB data-node package..."
sudo wget -O "/tmp/${INFLUXDB_DATA_DEB}" "${INFLUXDB_DATA_URL}"
echo "Installing InfluxDB data-node..."
sudo dpkg -i "/tmp/${INFLUXDB_DATA_DEB}"
sudo systemctl enable influxdb
sudo systemctl start influxdb
echo "InfluxDB data-node service started."

# Wait for the data node service to start
sleep 10

# Register the data node with the meta cluster
META_NODES="influxdb-meta-node-1.vandroogenbroeck.net,influxdb-meta-node-2.vandroogenbroeck.net,influxdb-meta-node-3.vandroogenbroeck.net"
DATA_NODE_URL="http://$(hostname -f):8088"

if [ -n "$META_NODES" ]; then
  echo "Registering data node with meta cluster: $META_NODES"
  for META in $(echo $META_NODES | tr ',' ' '); do
    curl -s -X POST "http://${META}:8091/data/join" \
      -H "Content-Type: application/json" \
      -d "{\"dataNodeUrl\": \"${DATA_NODE_URL}\"}" && echo "Successfully registered with meta node ${META}" && break
  done
else
  echo "No meta cluster nodes defined. Skipping data node registration."
fi

# Verify cluster status
echo "Checking cluster status from the data node perspective..."
curl -s http://localhost:8088/status | jq .

echo "InfluxDB data-node setup completed successfully. Logs can be found at ${LOGFILE}."