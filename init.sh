#!/usr/bin/env bash
#
# This script creates demo EdgeFS cluster
# with demo use and S3 service enabled
# Based on article "Data Geo-Transparency with EdgeFS on Mac for Developers"
# https://medium.com/edgefs/data-geo-transparency-with-edgefs-on-mac-for-developers-58d95f8672de
#

set -e
set -u
set -o pipefail

: ${AWS_ACCESS_KEY_ID:='unset'}
: ${AWS_SECRET_ACCESS_KEY:='unset'}

running_containers="$(docker-compose ps -q | wc -l)"
if [[ ${running_containers:-0} -ne 0 ]]; then
  echo
  echo -n "Running containers detected, destroy and proceed? [y/N]: "
  read DESTROY_RUNNING
  if [[ "${DESTROY_RUNNING:-nope}" != "y" ]]; then
    echo "aborting.."
    exit 1
  else
    docker-compose down
  fi
fi

if [[ -e "./etc/rest.json" ]]; then
  echo
  echo -n "Existing cluster configuration detected, wipe and proceed? [y/N]: "
  read DESTROY_CLUSTER
  if [[ "${DESTROY_CLUSTER:-nope}" != "y" ]]; then
    echo "aborting.."
    exit 1
  fi
fi

if [[ -d ./etc ]]; then
  rm -rf ./etc
fi
if [[ -d ./var ]]; then
  rm -rf ./var
fi
if [[ -d ./data ]]; then
  rm -rf ./data
fi

mkdir ./etc
mkdir ./var
mkdir -p ./data/store1

get_latest_images() {
  for image in $(grep 'image:' docker-compose.yml | awk '{print $NF}' | sort | uniq | tr -d "'"); do
    docker pull ${image}
  done
}

echo -n "Update local EdgeFS Docker images? [y/N]: "
read UPDATE_IMAGES
if [[ "${UPDATE_IMAGES:-nope}" == "y" ]]; then
  get_latest_images
fi

docker-compose run --rm \
  -e CCOW_LOG_STDOUT=1 target \
  config node -n localhost -i eth0 \
              -D /data/store1 -r 1 \
              --force-confirm \
              -o '{"MaxSizeGB":10,"RtPlevelOverride":1,"DisableVerifyChid":true,"Sync":2}'

docker-compose up -d ui mgmt s301 target
sleep 5

toolbox() {
  docker-compose exec mgmt toolbox $@
}

init_system() {
  toolbox efscli system init --force-confirm
  echo
}

create_cluster() {
  local cluster_name="${1:-myspace}"
  toolbox efscli cluster create ${cluster_name}
}

create_tenant() {
  local cluster_tenant="${1:-myspace/work}"
  toolbox efscli tenant create ${cluster_tenant}
}

create_bucket() {
  local cluster_tenant_bucket="${1:-myspace/work/shared1}"
  toolbox efscli bucket create ${cluster_tenant_bucket} -s 4M -t 1
}

create_service_s3() {
  local cluster_tenant="${1:-myspace/work}"
  toolbox efscli service create s3 s301
  toolbox efscli service serve s301 ${cluster_tenant}
  toolbox efscli service config s301 X-Auth-Type key_secret >/dev/null
  toolbox efscli service config s301 X-Region us-east-1 >/dev/null
  toolbox efscli service config s301 X-ACL-On false >/dev/null
  toolbox efscli service config s301 X-Status enabled >/dev/null
  toolbox efscli service show s301
}

create_user_demo() {
  local cluster_tenant="${1:-myspace/work}"
  local user_data
  user_data="$(toolbox efscli user create ${cluster_tenant} demouser demopassword)"
  AWS_ACCESS_KEY_ID="$(echo "${user_data}" | grep "Access key:" | awk '{print $NF}' | tr -d '\r\n')"
  AWS_SECRET_ACCESS_KEY="$(echo "${user_data}" | grep "Secret key:" | awk '{print $NF}' | tr -d '\r\n')"
}

restart_service_s3() {
  docker-compose restart s301
}

test_aws_cli() {
  local bucket="${1:-shared1}"
  if ! which aws >/dev/null; then
    echo
    echo "No AWS CLI detected!"
    NO_AWS_CLI=1
  fi
  echo
  echo "Testing upload to bucket \"${bucket}\""
  ${NO_AWS_CLI:+echo} aws --region yus-east-1 --endpoint-url http://localhost:9982 s3 cp ./init.sh s3://${bucket}/
  echo
  echo "Testing listing content of bucket \"${bucket}\""
  ${NO_AWS_CLI:+echo} aws --region us-east-1 --endpoint-url http://localhost:9982 s3 ls s3://${bucket}/
}

echo
echo -n "Proceed with initialization of demo cluster? [y/N]: "
read PROCEED_WITH_DEMO
if [[ "${PROCEED_WITH_DEMO:-nope}" == "y" ]]; then
  init_system
  create_cluster
  create_tenant
  create_bucket
  create_service_s3
  create_user_demo
  echo
  echo "==================="
  echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
  echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
  echo "==================="
  echo
  restart_service_s3
  test_aws_cli
else
  echo "do it yourself then"
  echo
fi

echo "## Here are some tips.."
cat <<EOM

### Getting into Management Toolbox to run efscli commands
docker-compose exec mgmt toolbox

### initialize local cluster segment
efscli system init

### initialize myspace/work/shared1
efscli cluster create myspace
efscli tenant create myspace/work
efscli bucket create myspace/work/shared1 -s 4M -t 1

### S3 service servicing myspace/work tenant
efscli service create s3 s301
efscli service serve s301 myspace/work
efscli service config s301 X-Auth-Type key_secret
efscli service config s301 X-Region us-east-1
efscli service config s301 X-ACL-On false
efscli service config s301 X-Status enabled

### S3 user creation
efscli user create myspace/work demouser demopassword

### Restart services
docker-compose restart s301

### Verify S3 service
export AWS_ACCESS_KEY_ID=KEY_FROM_USER_CREATION
export AWS_SECRET_ACCESS_KEY=SECRET_FROM_USER_CREATION
aws --region us-east-1 --endpoint-url http://localhost:9982 s3 cp ./init.sh s3://shared1/
aws --region us-east-1 --endpoint-url http://localhost:9982 s3 ls s3://shared1/

### Web UI available
Default Admin username: admin
Default Admin password: edgefs
URL: http://localhost:3000/

### Tear down demo cluster
docker-compose down

EOM
