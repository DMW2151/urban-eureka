
#! /bin/bash

cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=dev-backend-ecs-cluster
ECS_CONTAINER_INSTANCE_PROPAGATE_TAGS_FROM=ec2_instance
ECS_CONTAINER_INSTANCE_TAGS={"tag_key": "tag_value"}
EOF
