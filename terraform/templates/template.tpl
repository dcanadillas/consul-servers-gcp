#!/bin/bash

CONSUL_DIR="/etc/consul.d"

NODE_HOSTNAME=$(curl -s -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/hostname)
PUBLIC_IP=$(curl -s -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
PRIVATE_IP=$(curl -s -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
GCP_ZONE=$(curl -s -H 'Metadata-Flavor:Google' http://metadata.google.internal/computeMetadata/v1/instance/zone)
DC="${dc_name}"
CONSUL_LICENSE="${consul_license}"


# ---- Check directories ----
if [ -d "$CONSUL_DIR" ];then
    echo "Consul configurations will be created in $CONSUL_DIR" >> /tmp/consul-log.out
else
    echo "Consul configurations directoy does not exist. Exiting..." >> /tmp/consul-log.out
    exit 1
fi

if [ -d "/opt/consul" ]; then
    echo "Consul data directory will be created at existing /opt/consul" >> /tmp/consul-log.out
else
    echo "/opt/consul does not exist. Check that VM image is the right one. Creating directory anyway..."
    sudo mkdir -p /opt/consul
    sudo chown -R consul:consul /opt/consul
fi

if [ -d "/$CONSUL_DIR/tls" ]; then
    echo "Consul TLS directory exists" >> /tmp/consul-log.out
else
    echo "Consul TLS directory does not exist. Creating directory..."
    sudo mkdir -p $CONSUL_DIR/tls
    sudo chown -R consul:consul $CONSUL_DIR/tls
fi

# Creating a directory for audit
sudo mkdir -p /tmp/consul/audit


# ---- Enterprise Licenses ----
echo $CONSUL_LICENSE | sudo tee $CONSUL_DIR/license.hclic > /dev/null

# ---- Preparing certificates ----
echo "==> Adding server certificates to /etc/consul.d"
%{ if consul_ca == "" }
echo "Using CA provided from the VM image"
%{ else }
echo "${consul_ca}" | sudo tee "$CONSUL_DIR"/tls/consul-agent-ca.pem
echo "${consul_ca_key}" | sudo tee "$CONSUL_DIR"/tls/consul-agent-ca-key.pem
%{ endif }

%{ if consul_cert == "" }
consul tls cert create -server -dc $DC \
    -ca "$CONSUL_DIR"/tls/consul-agent-ca.pem \
    -key  "$CONSUL_DIR"/tls/consul-agent-ca-key.pem \
    -additional-dnsname="${consul_fqdn}" \
    -node="$NODE_HOSTNAME" 
sudo mv "$DC"-server-consul-*.pem "$CONSUL_DIR"/tls/
%{ else }
echo "${consul_cert}" | sudo tee "$CONSUL_DIR"/tls/"$DC"-server-consul-0.pem
echo "${consul_key}" | sudo tee "$CONSUL_DIR"/tls/"$DC"-server-consul-0-key.pem
%{ endif }

# ----------------------------------
echo "==> Generating Consul configs"

sudo tee $CONSUL_DIR/consul.hcl > /dev/null <<EOF
datacenter = "$DC"
data_dir = "/opt/consul"
node_name = "$NODE_HOSTNAME"
node_meta = {
  hostname = "$NODE_HOSTNAME"
  gcp_instance = "$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")"
  gcp_zone = "$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | awk -F / '{print $NF}')"
}
encrypt = "$(cat $CONSUL_DIR/keygen.out)"
ca_file = "$CONSUL_DIR/tls/consul-agent-ca.pem"
cert_file = "$CONSUL_DIR/tls/$DC-server-consul-0.pem"
key_file = "/etc/consul.d/tls/$DC-server-consul-0-key.pem"
verify_incoming = false
verify_outgoing = false
verify_server_hostname = false
retry_join = ["provider=gce project_name=${gcp_project} tag_value=${tag} zone_pattern=\"${region}-.*\""]
license_path = "$CONSUL_DIR/license.hclic"

auto_encrypt {
  allow_tls = true
}

acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens = {
    initial_management = "${bootstrap_token}"
    agent = "${bootstrap_token}"
  }
}

performance {
  raft_multiplier = 1
}

autopilot {
  cleanup_dead_servers = true
  last_contact_threshold = "200ms"
  max_trailing_logs = 250
  server_stabilization_time = "10s"
  # This is the tag that will be used to identify the zone of the datacenter in node_meta and apply the redundancy zone
  redundancy_zone_tag = "gcp_zone"
}

audit {
  enabled = true
  sink "${dc_name}_sink" {
    type   = "file"
    format = "json"
    path   = "/opt/consul/audit/audit.json"
    delivery_guarantee = "best-effort"
    rotate_duration = "24h"
    rotate_max_files = 15
    rotate_bytes = 25165824
    mode = "644"
  }
}


EOF

sudo tee $CONSUL_DIR/server.hcl > /dev/null <<EOF
server = true
bootstrap_expect = 3

ui = true
client_addr = "0.0.0.0"
advertise_addr = "$PRIVATE_IP"

connect {
  enabled = true
}

ports {
  https = 8501
  grpc = 8502
  grpc_tls = 8503
}

node_meta {
  zone = "$GCP_ZONE"
}
EOF

echo "==> Creating the Consul service"
sudo tee /usr/lib/systemd/system/consul.service > /dev/null <<EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$CONSUL_DIR/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/bin/consul agent -config-dir="$CONSUL_DIR"/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Let's set some permissions to read certificates from Consul
echo "==> Changing permissions"
sudo chown -R consul:consul "$CONSUL_DIR"/tls
sudo chown -R consul:consul /tmp/consul/audit

# ---------------



# INIT SERVICES

echo "==> Starting Consul..."
sudo systemctl start consul


