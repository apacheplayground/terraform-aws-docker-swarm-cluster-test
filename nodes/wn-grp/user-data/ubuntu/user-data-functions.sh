
# set_hostname
#*************
set_hostname() {
  echo "$(aws autoscaling describe-auto-scaling-groups \
   --auto-scaling-group-name $NODE_GROUP_NAME \
   --region $AWS_REGION \
   --query "AutoScalingGroups[].Instances[?LifecycleState=='InService'].InstanceId" \
   --output text)" >> /tmp/node-grp-instances.txt

  NUM_OF_EXISTING_NODE_GRP_INSTANCES=$(wc -l < /tmp/node-grp-instances.txt)

  NODE_NUM=$(( $NUM_OF_EXISTING_NODE_GRP_INSTANCES + 1 ))

  HOSTNAME=$NODE_GROUP_NAME-$NODE_NUM

  hostnamectl set-hostname $HOSTNAME

  hostname | grep $HOSTNAME
  HOSTNAME_SET=$?

  if [[ $HOSTNAME_SET == "0" ]];
  then
    echo "HOSTNAME_STATUS=set" >> /tmp/user-data-output.txt
  else
    echo "HOSTNAME_STATUS=none" >> /tmp/user-data-output.txt
  fi
}

# install_jquery
#***************
install_jquery() {
  apt-get install -y jq

  jq --version
  JQuery_FOUND=$?

  if [[ $JQuery_FOUND == "0" ]];
  then
    echo "JQuery_STATUS=installed" >> /tmp/user-data-output.txt
  else
    echo "JQuery_STATUS=none" >> /tmp/user-data-output.txt
  fi
}

# install_docker
#***************
install_docker() {
  apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -y
  #apt-cache policy docker-ce   # not in official doc
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  usermod -aG docker $DEFAULT_USER
  echo "$DEFAULT_USER ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/$DEFAULT_USER

  sudo systemctl daemon-reload
  sudo systemctl restart docker
  systemctl status docker >> /tmp/docker-status.txt
  grep running < /tmp/docker-status.txt

  DOCKER_FOUND=$?

  if [[ $DOCKER_FOUND == "0" ]]
  then
    echo "DOCKER_STATUS=running" >> /tmp/user-data-output.txt
  else
    echo "DOCKER_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/docker-status.txt
}

# configure_metadataproxy_ip_routes
#**********************************
configure_metadataproxy_ip_routes() {
  EC2_METADATA_SERVICE_IP=169.254.169.254
  HOST_PRIVATE_IPV4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

  #HOST_LOOPBACK_IP=127.0.0.1
  #HOST_PRIVATE_IPV4=$(ifconfig eth0 | grep -Eo "inet addr:[0-9.]+" | grep -Eo "[0-9.]+")

  METADATA_PROXY_HOST_PORT=8000
  METADATA_PROXY_ADDRESS=$HOST_PRIVATE_IPV4:$METADATA_PROXY_HOST_PORT

  iptables \
   --wait \
   --table nat \
   --append PREROUTING \
   --protocol tcp \
   --dport 80 \
   --destination $EC2_METADATA_SERVICE_IP \
   --in-interface docker+ \
   --jump DNAT \
   --to-destination $METADATA_PROXY_ADDRESS

  iptables \
   --wait \
   --insert INPUT 1 \
   --protocol tcp \
   --dport 80 \
   ! --in-interface docker0 \
   --jump DROP
}

# grant_swarm_services_iam_access
#********************************
grant_swarm_services_iam_access() {
  if [[ $GRANT_SWARM_SERVICES_IAM_ACCESS == "true" ]];
  then
    configure_metadataproxy_ip_routes
  else
    echo "GRANT_SWARM_SERVICES_IAM_ACCESS=false"
  fi
}

# ssm_check_parameter
#********************
ssm_check_parameter() { aws ssm get-parameter --name "$PARAMETER_NAME" --query "Parameter.Value" --output "text" --no-with-decryption; }

# ssm_get_parameter
#******************
ssm_get_parameter() { aws ssm get-parameter --name "$PARAMETER_NAME" --query "Parameter.Value" --output "text" --with-decryption; }

# get_wn_join_token
#******************
get_wn_join_token() {
  PARAMETER_NAME=$SWARM_NAME-WN-JOIN-TOKEN
  WN_JOIN_TOKEN=$(ssm_get_parameter)
}

# join_wn_to_mn_1_led_cluster
#****************************
join_wn_to_mn_1_led_cluster() {
  PARAMETER_NAME=$MN_1_PRIVATE_EIP_NAME
  MN_1_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_1_PRIVATE_EIP

  docker swarm join --token $WN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a swarm as a worker." < /tmp/node-join-status.txt

  NODE_JOINED_MN_1_LED_CLUSTER=$?

  if [[ $NODE_JOINED_MN_1_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-1" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_wn_to_mn_2_led_cluster
#****************************
join_wn_to_mn_2_led_cluster() {
  PARAMETER_NAME=$MN_2_PRIVATE_EIP_NAME
  MN_2_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_2_PRIVATE_EIP

  docker swarm join --token $WN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a swarm as a worker." < /tmp/node-join-status.txt

  NODE_JOINED_MN_2_LED_CLUSTER=$?

  if [[ $NODE_JOINED_MN_2_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-2" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_wn_to_mn_3_led_cluster
#****************************
join_wn_to_mn_3_led_cluster() {
  PARAMETER_NAME=$MN_3_PRIVATE_EIP_NAME
  MN_3_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_3_PRIVATE_EIP

  docker swarm join --token $WN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a swarm as a worker." < /tmp/node-join-status.txt

  NODE_JOINED_MN_3_LED_CLUSTER=$?

  if [[ $NODE_JOINED_MN_3_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-3" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_wn_to_mn_4_led_cluster
#****************************
join_wn_to_mn_4_led_cluster() {
  PARAMETER_NAME=$MN_4_PRIVATE_EIP_NAME
  MN_4_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_3_PRIVATE_EIP

  docker swarm join --token $WN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a swarm as a worker." < /tmp/node-join-status.txt

  NODE_JOINED_MN_4_LED_CLUSTER=$?

  if [[ $NODE_JOINED_MN_4_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-4" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_wn_to_mn_5_led_cluster
#****************************
join_wn_to_mn_5_led_cluster() {
  PARAMETER_NAME=$MN_5_PRIVATE_EIP_NAME
  MN_5_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_5_PRIVATE_EIP

  docker swarm join --token $WN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a swarm as a worker." < /tmp/node-join-status.txt

  NODE_JOINED_MN_5_LED_CLUSTER=$?

  if [[ $NODE_JOINED_MN_5_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-5" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_wn_to_swarm
#*****************
join_wn_to_swarm() {
  if [[ $NUM_OF_MN == "1" ]];
  then
    join_wn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      echo "Something went wrong."
    fi
  elif [[ $NUM_OF_MN == "3" ]];
  then
    join_wn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_wn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_wn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          echo "Something went wrong."
        fi
      fi
    fi
  else
    join_wn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_wn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_wn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_wn_to_mn_4_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_wn_to_mn_5_led_cluster

            if [[ $NODE_JOIN_STATUS == "joined" ]];
            then
              echo "Do nothing."
            else
              echo "Something went wrong."
            fi
          fi
        fi
      fi
    fi
  fi
}

# send_slack_notification
#************************
send_slack_notification() {
  PARAMETER_NAME=$SLACK_WEBHOOK_URL_SSM_PARAMETER
  SLACK_WEBHOOK_URL=$(ssm_get_parameter)

  SLACK_MESSAGE=$(cat /tmp/user-data-output.txt)

  curl \
   -X POST \
   -H 'Content-type: application/json' \
   --data "{\"text\":\"$SLACK_MESSAGE\"}" \
   $SLACK_WEBHOOK_URL

  NODE_STATUS_NOTIFICATION_SUCCESSFUL=$?

  if [[ $NODE_STATUS_NOTIFICATION_SUCCESSFUL == "0" ]];
  then
    echo "NODE_STATUS_NOTIFICATION=successful" >> /tmp/user-data-output.txt
  else
    echo "NODE_STATUS_NOTIFICATION=none" >> /tmp/user-data-output.txt
  fi
}

######################################## APACHEPLAYGROUND™ ########################################
