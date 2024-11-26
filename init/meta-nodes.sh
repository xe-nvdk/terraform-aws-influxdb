#!/bin/bash
set -e  # Stop the script if any command fails

LOGFILE="/var/log/influxdb-meta-node-setup.log"
exec > >(tee -i "$LOGFILE") 2>&1  # Log both stdout and stderr to a file

echo "Starting InfluxDB meta-node setup..."

# Update and install necessary packages
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install -y python3 wget jq
sudo sleep 10

# Format attached disk if not already formatted
if [ -e /dev/xvdh ]; then
  if ! blkid /dev/xvdh; then
    echo "Formatting disk /dev/xvdh..."
    sudo mkfs.ext4 /dev/xvdh
  else
    echo "Disk /dev/xvdh is already formatted."
  fi

  # Create folders and mount disks
  echo "Mounting /dev/xvdh to /mnt/influxdb/meta/data..."
  sudo mkdir -p /mnt/influxdb/meta/data
  if ! mountpoint -q /mnt/influxdb/meta/data; then
    sudo mount /dev/xvdh /mnt/influxdb/meta/data
  else
    echo "/mnt/influxdb/meta/data is already mounted."
  fi

  # Create /etc/fstab entry for persistent mount
  if ! grep -q '/mnt/influxdb/meta/data' /etc/fstab; then
    echo "Adding /dev/xvdh to /etc/fstab..."
    echo '# influxdb-meta-disk' | sudo tee -a /etc/fstab
    echo '/dev/xvdh    /mnt/influxdb/meta/data    ext4    defaults,nofail    0    2' | sudo tee -a /etc/fstab
  fi
else
  echo "Disk /dev/xvdh not found. Skipping formatting and mounting."
fi

# Download, install, and start InfluxDB meta-node
INFLUXDB_META_VERSION="1.11.8-c1.11.8-1"
INFLUXDB_META_DEB="influxdb-meta_${INFLUXDB_META_VERSION}_amd64.deb"
INFLUXDB_META_URL="https://dl.influxdata.com/enterprise/releases/${INFLUXDB_META_DEB}"

echo "Downloading InfluxDB meta-node package..."
sudo wget -O "/tmp/${INFLUXDB_META_DEB}" "${INFLUXDB_META_URL}"
echo "Installing InfluxDB meta-node..."
sudo dpkg -i "/tmp/${INFLUXDB_META_DEB}"
sudo systemctl enable influxdb-meta
sudo systemctl start influxdb-meta
echo "InfluxDB meta-node service started."

# Wait for meta service to start
sleep 10

# Cluster setup: Add this meta node to the cluster
CLUSTER_META_NODES="influxdb-meta-node-1.vandroogenbroeck.net,influxdb-meta-node-2.vandroogenbroeck.net,influxdb-meta-node-3.vandroogenbroeck.net"  # Replace with actual meta node FQDNs
CURRENT_NODE="$(hostname -f)"  # Get the FQDN of this instance

if [ -n "$CLUSTER_META_NODES" ]; then
  echo "Joining meta cluster with nodes: $CLUSTER_META_NODES"
  for NODE in $(echo $CLUSTER_META_NODES | tr ',' ' '); do
    if [ "$NODE" != "$CURRENT_NODE" ]; then
      curl -s -X POST "http://${NODE}:8091/cluster/join" \
        -H "Content-Type: application/json" \
        -d "{\"metaNodes\": [\"$CLUSTER_META_NODES\"]}"
      break
    fi
  done
else
  echo "No meta cluster nodes defined. Skipping cluster join."
fi

# Verify cluster status
echo "Cluster status:"
curl -s http://localhost:8091/status | jq .

echo "InfluxDB meta-node setup completed successfully. Logs can be found at ${LOGFILE}."