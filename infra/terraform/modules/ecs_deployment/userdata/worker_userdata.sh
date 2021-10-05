#! /bin/bash

# User data for the ECS cluster workers, add self to ECS cluster, we get a VERY small
# userdata script becaause we're using an AMI w. the ECS agent already baked in!

sudo yum install -y lsof curl

cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=dev-backend-ecs-cluster
EOF
