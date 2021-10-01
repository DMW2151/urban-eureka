#! /bin/bash
sudo yum install -y lsof curl

cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=dev-backend-ecs-cluster
EOF
