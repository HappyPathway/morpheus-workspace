#!/bin/bash
set -e

# Mount EFS volume
yum install -y amazon-efs-utils
mkdir -p /morpheus/lib
echo "${efs_dns_name}:/ /morpheus/lib efs _netdev,tls,iam 0 0" >> /etc/fstab
mount -a

# Configure application environment
cat > /etc/morpheus/morpheus.rb <<EOF
morpheus['db']['host'] = "${db_endpoint}"
morpheus['messaging']['host'] = "${rabbitmq_host}"
morpheus['elastic']['host'] = "${opensearch_host}"
morpheus['nginx']['ssl']['enabled'] = true
morpheus['nginx']['ssl']['protocols'] = "TLSv1.2 TLSv1.3"

# High availability settings
morpheus['ha']['enabled'] = true
morpheus['nginx']['workers'] = 4
morpheus['web']['workers'] = 4
morpheus['job']['workers'] = 4

# Shared storage configuration
morpheus['shared_storage']['enabled'] = true
morpheus['shared_storage']['mount_path'] = "/morpheus/lib"
EOF

# Apply configuration
morpheus-ctl reconfigure