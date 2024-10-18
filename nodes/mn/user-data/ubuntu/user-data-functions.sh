
# set_hostname
#*************
set_hostname() {
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

<<COMMENT
# label_node_docker_engine
#*************************
label_node_docker_engine() {
  sed -i 's|#DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4"|DOCKER_OPTS="--label=mn=true"|g' /etc/default/docker
  systemctl daemon-reload
  systemctl restart docker
}
COMMENT

# install_nfs_common
#*******************
install_nfs_common() {
  apt-get install -y nfs-common
  rm /lib/systemd/system/nfs-common.service
  systemctl daemon-reload
  systemctl unmask nfs-common
  systemctl start nfs-common
  systemctl enable nfs-common

  systemctl status nfs-common >> /tmp/nfs-common-status.txt
  grep running < /tmp/nfs-common-status.txt

  NFS_COMMON_FOUND=$?

  if [[ $NFS_COMMON_FOUND == "0" ]];
  then
    export NFS_COMMON_STATUS=running
    echo "NFS_COMMON_STATUS=running" >> /tmp/user-data-output.txt
  else
    export NFS_COMMON_STATUS=none
    echo "NFS_COMMON_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/nfs-common-status.txt
}

# mount_swarm_data_store
#***********************
mount_swarm_data_store() {
  install_nfs_common

  if [[ $NFS_COMMON_STATUS == "running" ]];
  then
    mkdir $SWARM_DATA_STORE_MOUNT_DIR

    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$SWARM_DATA_STORE_DNS":/ $SWARM_DATA_STORE_MOUNT_DIR
    echo "$SWARM_DATA_STORE_DNS:/ $SWARM_DATA_STORE_MOUNT_DIR nfs4 defaults,_netdev,nofail 0 0" >> /etc/fstab

    findmnt | grep $SWARM_DATA_STORE_DNS

    SWARM_DATA_STORE_MOUNT_STATUS=$?

    if [[ $SWARM_DATA_STORE_MOUNT_STATUS == "0" ]];
    then
      echo "SWARM_DATA_STORE_MOUNT_STATUS=mounted" >> /tmp/user-data-output.txt
    else
      echo "SWARM_DATA_STORE_MOUNT_STATUS=none" >> /tmp/user-data-output.txt
    fi
  else
    echo "NFS_COMMON_STATUS=none"
  fi
}

# attach_public_eip_address
#**************************
attach_public_eip_address() {
  aws ec2 associate-address --allocation-id "$NODE_PUBLIC_EIP_ALLOCATION_ID" --instance-id "$INSTANCE_ID" --allow-reassociation

  NODE_EIP_ATTACHED=$?

  if [[ $NODE_EIP_ATTACHED == "0" ]];
  then
    echo "NODE_EIP_STATUS=attached" >> /tmp/user-data-output.txt
  else
    echo "NODE_EIP_STATUS=none" >> /tmp/user-data-output.txt
  fi
}

# attach_private_eip_address
#***************************
attach_private_eip_address() {
  aws ec2 attach-network-interface --network-interface-id $NODE_PRIVATE_EIP_ENI_ID --instance-id $INSTANCE_ID --device-index 1

  cat > /etc/netplan/51-eth1.yaml<< EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      dhcp4: no
      addresses:
       - $NODE_PRIVATE_EIP/$NODE_SUBNET_MASK
      routes:
       - to: 0.0.0.0/0
         via: $NODE_SUBNET_ENI_IP
         scope: global
         table: 1000
      routing-policy:
       - from: $NODE_PRIVATE_EIP
         table: 1000
EOF

  netplan apply

  echo "NODE_PRIVATE_EIP=$NODE_PRIVATE_EIP" >> /tmp/user-data-output.txt
}

# restore_1_mn_swarm_from_backup
#*******************************
restore_1_mn_swarm_from_backup() {
  systemctl stop docker

  cat > /etc/docker/daemon.json<< EOF
{
  "data-root": "$NODE_DOCKER_ROOT_DIR"
}
EOF

  mv /var/lib/docker /var/lib/docker-bkp
  systemctl daemon-reload
  systemctl restart docker
}

# persist_mn_docker_root_dir_on_swarm_data_store
#***********************************************
persist_mn_docker_root_dir_on_swarm_data_store() {
  systemctl stop docker

  cat > /etc/docker/daemon.json<< EOF
{
  "data-root": "$NODE_DOCKER_ROOT_DIR"
}
EOF

  mv /var/lib/docker /var/lib/docker-bkp
  systemctl daemon-reload
  systemctl restart docker
}

# setup_mn_docker_root_dir_on_swarm_data_store
#*********************************************
setup_mn_docker_root_dir_on_swarm_data_store() {
  if [[ $NUM_OF_MN != "1" ]];
  then
    export NODE_DOCKER_ROOT_DIR="$SWARM_DATA_STORE_MOUNT_DIR/mn-$MN_INDEX-data"

    ls $SWARM_DATA_STORE_MOUNT_DIR | grep mn-$MN_INDEX-data

    NODE_DOCKER_ROOT_DIR_FOUND=$?

    if [[ $NODE_DOCKER_ROOT_DIR_FOUND == "0" ]];
    then
      rm -rf $NODE_DOCKER_ROOT_DIR/*
      persist_mn_docker_root_dir_on_swarm_data_store
    else
      mkdir $NODE_DOCKER_ROOT_DIR
      persist_mn_docker_root_dir_on_swarm_data_store
    fi
  else
     echo "Do nothing."
  fi
}

# ssm_check_parameter
#********************
ssm_check_parameter() { aws ssm get-parameter --name "$PARAMETER_NAME" --query "Parameter.Value" --output "text" --no-with-decryption; }

# ssm_get_parameter
#******************
ssm_get_parameter() { aws ssm get-parameter --name "$PARAMETER_NAME" --query "Parameter.Value" --output "text" --with-decryption; }

# get_existing_mn_join_token
#***************************
get_existing_mn_join_token() {
  PARAMETER_NAME=$SWARM_NAME-MN-JOIN-TOKEN
  EXISTING_MN_JOIN_TOKEN=$(ssm_get_parameter)
}

# docker_swarm_init
#******************
docker_swarm_init() {
  docker swarm init --advertise-addr "$NODE_PRIVATE_EIP" > /tmp/swarm-init-status.txt
  grep "Swarm initialized" < /tmp/swarm-init-status.txt

  SWARM_INITIALIZED=$?

  if [[ $SWARM_INITIALIZED == "0" ]];
  then
    echo "SWARM_STATUS=initialized" >> /tmp/user-data-output.txt
    echo "SWARM_LEADER=mn-1" >> /tmp/user-data-output.txt
    docker_node_inspect
  else
    echo "SWARM_STATUS=none" >> /tmp/user-data-output.txt
    echo "NODE_ROLE=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/swarm-init-status.txt
}

# publish_mn_join_token
#**********************
publish_mn_join_token() {
  docker swarm join-token --quiet manager > /tmp/mn-join-token.txt
  aws ssm put-parameter --name "$SWARM_NAME-MN-JOIN-TOKEN" --type "SecureString" --value "$(cat /tmp/mn-join-token.txt)" --overwrite

  MN_JOIN_TOKEN_STORED=$?

  if [[ $MN_JOIN_TOKEN_STORED == "0" ]];
  then
    echo "MN_JOIN_TOKEN_STATUS=uploaded" >> /tmp/user-data-output.txt
  else
    echo "MN_JOIN_TOKEN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/mn-join-token.txt
}

# publish_wn_join_token
#**********************
publish_wn_join_token() {
  docker swarm join-token --quiet worker > /tmp/wn-join-token.txt
  aws ssm put-parameter --name "$SWARM_NAME-WN-JOIN-TOKEN" --type "SecureString" --value "$(cat /tmp/wn-join-token.txt)" --overwrite

  WN_JOIN_TOKEN_STORED=$?

  if [[ $WN_JOIN_TOKEN_STORED == "0" ]];
  then
    echo "WN_JOIN_TOKEN_STATUS=uploaded" >> /tmp/user-data-output.txt
    echo "" >> /tmp/user-data-output.txt
  else
    echo "WN_JOIN_TOKEN_STATUS=none" >> /tmp/user-data-output.txt
    echo "" >> /tmp/user-data-output.txt
  fi

  rm /tmp/wn-join-token.txt
}

# initiate_cluster
#*****************
initiate_cluster() {
  docker_swarm_init
  publish_mn_join_token
  publish_wn_join_token
}

# join_mn_to_mn_1_led_cluster
#****************************
join_mn_to_mn_1_led_cluster() {
  PARAMETER_NAME=$MN_1_PRIVATE_EIP_NAME
  MN_1_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_1_PRIVATE_EIP

  docker swarm join --token $EXISTING_MN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a cluster as a manager." < /tmp/node-join-status.txt

  NODE_JOINED_OR_REJOINED_MN_1_LED_CLUSTER=$?

  if [[ $NODE_JOINED_OR_REJOINED_MN_1_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn_1" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
    docker_node_inspect
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_mn_to_mn_2_led_cluster
#****************************
join_mn_to_mn_2_led_cluster() {
  PARAMETER_NAME=$MN_2_PRIVATE_EIP_NAME
  MN_2_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_2_PRIVATE_EIP

  docker swarm join --token $EXISTING_MN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a cluster as a manager." < /tmp/node-join-status.txt

  NODE_JOINED_OR_REJOINED_MN_2_LED_CLUSTER=$?

  if [[ $NODE_JOINED_OR_REJOINED_MN_2_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-2" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
    docker_node_inspect
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_mn_to_mn_3_led_cluster
#****************************
join_mn_to_mn_3_led_cluster() {
  PARAMETER_NAME=$MN_3_PRIVATE_EIP_NAME
  MN_3_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_3_PRIVATE_EIP

  docker swarm join --token $EXISTING_MN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a cluster as a manager." < /tmp/node-join-status.txt

  NODE_JOINED_OR_REJOINED_MN_3_LED_CLUSTER=$?

  if [[ $NODE_JOINED_OR_REJOINED_MN_3_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-3" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
    docker_node_inspect
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_mn_to_mn_4_led_cluster
#****************************
join_mn_to_mn_4_led_cluster() {
  PARAMETER_NAME=$MN_4_PRIVATE_EIP_NAME
  MN_4_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_4_PRIVATE_EIP

  docker swarm join --token $EXISTING_MN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a cluster as a manager." < /tmp/node-join-status.txt

  NODE_JOINED_OR_REJOINED_MN_4_LED_CLUSTER=$?

  if [[ $NODE_JOINED_OR_REJOINED_MN_4_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-4" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
    docker_node_inspect
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_mn_to_mn_5_led_cluster
#****************************
join_mn_to_mn_5_led_cluster() {
  PARAMETER_NAME=$MN_5_PRIVATE_EIP_NAME
  MN_5_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_5_PRIVATE_EIP

  docker swarm join --token $EXISTING_MN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a cluster as a manager." < /tmp/node-join-status.txt

  NODE_JOINED_OR_REJOINED_MN_5_LED_CLUSTER=$?

  if [[ $NODE_JOINED_OR_REJOINED_MN_5_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-5" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
    docker_node_inspect
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_mn_to_mn_6_led_cluster
#****************************
join_mn_to_mn_6_led_cluster() {
  PARAMETER_NAME=$MN_6_PRIVATE_EIP_NAME
  MN_6_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_6_PRIVATE_EIP

  docker swarm join --token $EXISTING_MN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a cluster as a manager." < /tmp/node-join-status.txt

  NODE_JOINED_OR_REJOINED_MN_6_LED_CLUSTER=$?

  if [[ $NODE_JOINED_OR_REJOINED_MN_6_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-6" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
    docker_node_inspect
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# join_mn_to_mn_7_led_cluster
#****************************
join_mn_to_mn_7_led_cluster() {
  PARAMETER_NAME=$MN_7_PRIVATE_EIP_NAME
  MN_7_PRIVATE_EIP=$(ssm_get_parameter)

  SWARM_LEADER_PRIVATE_EIP=$MN_7_PRIVATE_EIP

  docker swarm join --token $EXISTING_MN_JOIN_TOKEN $SWARM_LEADER_PRIVATE_EIP:2377 > /tmp/node-join-status.txt
  grep "This node joined a cluster as a manager." < /tmp/node-join-status.txt

  NODE_JOINED_OR_REJOINED_MN_7_LED_CLUSTER=$?

  if [[ $NODE_JOINED_OR_REJOINED_MN_7_LED_CLUSTER == "0" ]];
  then
    export NODE_JOIN_STATUS=joined
    echo "SWARM_LEADER=mn-7" >> /tmp/user-data-output.txt
    echo "NODE_JOIN_STATUS=joined" >> /tmp/user-data-output.txt
    docker_node_inspect
  else
    docker swarm leave --force
    echo "NODE_JOIN_STATUS=none" >> /tmp/user-data-output.txt
  fi

  rm /tmp/node-join-status.txt
}

# docker_node_inspect
#********************
docker_node_inspect() {
  echo "" >> /tmp/user-data-output.txt
  echo "NODE_STATE=$(docker node inspect --format '{{ .Status.State }}' self)" >> /tmp/user-data-output.txt
  echo "NODE_ROLE=$(docker node inspect --format '{{ .Spec.Role }}' self)" >> /tmp/user-data-output.txt
  echo "NODE_LEADER_STATUS=$(docker node inspect --format '{{ .ManagerStatus.Leader }}' self)" >> /tmp/user-data-output.txt
  echo "NODE_AVAILABILITY=$(docker node inspect --format '{{ .Spec.Availability }}' self)" >> /tmp/user-data-output.txt
  echo "NODE_REACHABILITY=$(docker node inspect --format '{{ .ManagerStatus.Reachability }}' self)" >> /tmp/user-data-output.txt
  echo "" >> /tmp/user-data-output.txt
}

# join_mn_1_to_1_mn_cluster
#**************************
join_mn_1_to_1_mn_cluster() {
  if [[ $MN_INDEX == "1" && $NUM_OF_MN == "1" ]];
  then
    export NODE_DOCKER_ROOT_DIR="$SWARM_DATA_STORE_MOUNT_DIR/mn-$MN_INDEX-data"

    ls $SWARM_DATA_STORE_MOUNT_DIR | grep mn-$MN_INDEX-data

    NODE_DOCKER_ROOT_DIR_FOUND=$?

    if [[ $NODE_DOCKER_ROOT_DIR_FOUND == "0" ]];
    then
      restore_1_mn_swarm_from_backup
    else
      mkdir $NODE_DOCKER_ROOT_DIR
      persist_mn_docker_root_dir_on_swarm_data_store
      initiate_cluster
    fi
  else
     echo "Do nothing."
  fi
}

# join_mn_1_to_3_mn_cluster
#**************************
join_mn_1_to_3_mn_cluster() {
  if [[ $MN_INDEX == "1" && $NUM_OF_MN == "3" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    MN_JOIN_TOKEN_PLACEHOLDER_VALUE="12345"
    get_existing_mn_join_token

    if [[ $EXISTING_MN_JOIN_TOKEN == $MN_JOIN_TOKEN_PLACEHOLDER_VALUE ]];
    then
      initiate_cluster
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_2_to_3_mn_cluster
#**************************
join_mn_2_to_3_mn_cluster() {
  if [[ $MN_INDEX == "2" && $NUM_OF_MN == "3" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_3_led_cluster
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_3_to_3_mn_cluster
#**************************
join_mn_3_to_3_mn_cluster() {
  if [[ $MN_INDEX == "3" && $NUM_OF_MN == "3" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_1_to_5_mn_cluster
#**************************
join_mn_1_to_5_mn_cluster() {
  if [[ $MN_INDEX == "1" && $NUM_OF_MN == "5" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    MN_JOIN_TOKEN_PLACEHOLDER_VALUE="12345"
    get_existing_mn_join_token

    if [[ $EXISTING_MN_JOIN_TOKEN == $MN_JOIN_TOKEN_PLACEHOLDER_VALUE ]];
    then
      initiate_cluster
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_4_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_mn_to_mn_5_led_cluster
          fi
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_2_to_5_mn_cluster
#**************************
join_mn_2_to_5_mn_cluster() {
  if [[ $MN_INDEX == "2" && $NUM_OF_MN == "5" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_3_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_4_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_5_led_cluster
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_3_to_5_mn_cluster
#**************************
join_mn_3_to_5_mn_cluster() {
  if [[ $MN_INDEX == "3" && $NUM_OF_MN == "5" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_4_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_5_led_cluster
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_4_to_5_mn_cluster
#**************************
join_mn_4_to_5_mn_cluster() {
  if [[ $MN_INDEX == "4" && $NUM_OF_MN == "5" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_5_led_cluster
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_5_to_5_mn_cluster
#**************************
join_mn_5_to_5_mn_cluster() {
  if [[ $MN_INDEX == "5" && $NUM_OF_MN == "5" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_4_led_cluster
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_1_to_7_mn_cluster
#**************************
join_mn_1_to_7_mn_cluster() {
  if [[ $MN_INDEX == "1" && $NUM_OF_MN == "7" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    MN_JOIN_TOKEN_PLACEHOLDER_VALUE="12345"
    get_existing_mn_join_token

    if [[ $EXISTING_MN_JOIN_TOKEN == $MN_JOIN_TOKEN_PLACEHOLDER_VALUE ]];
    then
      initiate_cluster
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_4_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_mn_to_mn_5_led_cluster

            if [[ $NODE_JOIN_STATUS == "joined" ]];
            then
              echo "Do nothing."
            else
              join_mn_to_mn_6_led_cluster

              if [[ $NODE_JOIN_STATUS == "joined" ]];
              then
                echo "Do nothing."
              else
                join_mn_to_mn_7_led_cluster
              fi
            fi
          fi
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_2_to_7_mn_cluster
#**************************
join_mn_2_to_7_mn_cluster() {
  if [[ $MN_INDEX == "2" && $NUM_OF_MN == "7" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_3_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_4_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_5_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_mn_to_mn_6_led_cluster

            if [[ $NODE_JOIN_STATUS == "joined" ]];
            then
              echo "Do nothing."
            else
              join_mn_to_mn_7_led_cluster
            fi
          fi
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_3_to_7_mn_cluster
#**************************
join_mn_3_to_7_mn_cluster() {
  if [[ $MN_INDEX == "3" && $NUM_OF_MN == "7" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_4_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_5_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_mn_to_mn_6_led_cluster

            if [[ $NODE_JOIN_STATUS == "joined" ]];
            then
              echo "Do nothing."
            else
              join_mn_to_mn_7_led_cluster
            fi
          fi
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_4_to_7_mn_cluster
#**************************
join_mn_4_to_7_mn_cluster() {
  if [[ $MN_INDEX == "4" && $NUM_OF_MN == "7" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_5_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_mn_to_mn_6_led_cluster

            if [[ $NODE_JOIN_STATUS == "joined" ]];
            then
              echo "Do nothing."
            else
              join_mn_to_mn_7_led_cluster
            fi
          fi
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_5_to_7_mn_cluster
#**************************
join_mn_5_to_7_mn_cluster() {
  if [[ $MN_INDEX == "5" && $NUM_OF_MN == "7" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_4_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_mn_to_mn_6_led_cluster

            if [[ $NODE_JOIN_STATUS == "joined" ]];
            then
              echo "Do nothing."
            else
              join_mn_to_mn_7_led_cluster
            fi
          fi
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_6_to_7_mn_cluster
#**************************
join_mn_6_to_7_mn_cluster() {
  if [[ $MN_INDEX == "6" && $NUM_OF_MN == "7" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_4_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_mn_to_mn_5_led_cluster

            if [[ $NODE_JOIN_STATUS == "joined" ]];
            then
              echo "Do nothing."
            else
              join_mn_to_mn_7_led_cluster
            fi
          fi
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
}

# join_mn_7_to_7_mn_cluster
#**************************
join_mn_7_to_7_mn_cluster() {
  if [[ $MN_INDEX == "7" && $NUM_OF_MN == "7" ]];
  then
    setup_mn_docker_root_dir_on_swarm_data_store

    get_existing_mn_join_token
    join_mn_to_mn_1_led_cluster

    if [[ $NODE_JOIN_STATUS == "joined" ]];
    then
      echo "Do nothing."
    else
      join_mn_to_mn_2_led_cluster

      if [[ $NODE_JOIN_STATUS == "joined" ]];
      then
        echo "Do nothing."
      else
        join_mn_to_mn_3_led_cluster

        if [[ $NODE_JOIN_STATUS == "joined" ]];
        then
          echo "Do nothing."
        else
          join_mn_to_mn_4_led_cluster

          if [[ $NODE_JOIN_STATUS == "joined" ]];
          then
            echo "Do nothing."
          else
            join_mn_to_mn_5_led_cluster

            if [[ $NODE_JOIN_STATUS == "joined" ]];
            then
              echo "Do nothing."
            else
              join_mn_to_mn_6_led_cluster
            fi
          fi
        fi
      fi
    fi
  else
    echo "Do nothing."
  fi
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

# docker_service_create_metadataproxy
#************************************
docker_service_create_metadataproxy() {
  docker service create \
   --name metadataproxy \
   --network host \
   --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
   --mode global \
   lyft/metadataproxy

  docker service ls | grep metadataproxy

  METADATA_PROXY_FOUND=$?

  if [[ $METADATA_PROXY_FOUND == "true" ]];
  then
    echo "METADATA_PROXY_STATUS=running" >> /tmp/user-data-output.txt
  else
    echo "METADATA_PROXY_STATUS=none" >> /tmp/user-data-output.txt
  fi
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

  if [[ $MN_INDEX == "1" && $GRANT_SWARM_SERVICES_IAM_ACCESS == "true" ]];
  then
    docker service ls | grep metadataproxy

    METADATAPROXY_SERVICE_FOUND=$?

    if [[ $METADATAPROXY_SERVICE_FOUND == "0" ]];
    then
      echo "Do nothing."
    else
      docker_service_create_metadataproxy
    fi
  else
    echo "Do nothing."
  fi
}

# docker_service_create_service_autoscaler
#*****************************************
docker_service_create_service_autoscaler() {
  if [[ $NUM_OF_MN == "1" ]];
  then
    docker service create \
     --name service-autoscaler \
     --publish 8081:8000 \
     --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
     --constraint "node.role==manager" \
     --constraint "node.hostname==$SWARM_NAME_0-mn-1" \
     --mode replicated \
     --replicas 1 \
     gianarb/orbiter
  else
    docker service create \
     --name service-autoscaler \
     --publish 8081:8000 \
     --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
     --constraint "node.role==manager" \
     --constraint "node.hostname==$SWARM_NAME_0-mn-2" \
     --mode replicated \
     --replicas 1 \
     gianarb/orbiter
  fi

  docker service ls | grep service-autoscaler

  SERVICE_AUTOSCALER_FOUND=$?

  if [[ $SERVICE_AUTOSCALER_FOUND == "0" ]];
  then
    echo "SERVICE_AUTOSCALER_STATUS=running" >> /tmp/user-data-output.txt
  else
    echo "SERVICE_AUTOSCALER_STATUS=none" >> /tmp/user-data-output.txt
  fi
}

# deploy_service_autoscaler
#**************************
deploy_service_autoscaler() {
  if [[ $MN_INDEX == "1" && $NUM_OF_MN == "1" && $ENABLE_SWARM_SERVICES_AUTOSCALING == "true" ]];
  then
    docker service ls | grep service-autoscaler

    SERVICE_AUTOSCALER_FOUND=$?

    if [[ $SERVICE_AUTOSCALER_FOUND == "0" ]];
    then
      echo "Do nothing."
    else
      docker_service_create_service_autoscaler
    fi
  elif [[ $MN_INDEX == "2" && $NUM_OF_MN != "1" && $ENABLE_SWARM_SERVICES_AUTOSCALING == "true" ]];
  then
    docker service ls | grep service-autoscaler

    SERVICE_AUTOSCALER_FOUND=$?

    if [[ $SERVICE_AUTOSCALER_FOUND == "0" ]];
    then
      echo "Do nothing."
    else
      docker_service_create_service_autoscaler
    fi
  else
    echo "Do nothing."
  fi
}

# create_dashboards_directory
#****************************
create_dashboards_directory() {
  if [[ $MN_INDEX == "1" ]];
  then
    ls $SWARM_DATA_STORE_MOUNT_DIR | grep dashboards

    DASHBOARDS_DIR_FOUND=$?

    if [[ $DASHBOARDS_DIR_FOUND == "0" ]];
    then
      echo "Do nothing."
    else
      mkdir $DASHBOARDS_DIR
    fi
  else
    echo "Do nothing."
  fi
}

# create_portainer_directory
#****************************
create_portainer_directory() {
  if [[ $MN_INDEX == "1" ]];
  then
    ls $DASHBOARDS_DIR | grep portainer

    PORTAINER_DIR_FOUND=$?

    if [[ $PORTAINER_DIR_FOUND == "0" ]];
    then
      echo "Do nothing."
    else
      mkdir -p $PORTAINER_DIR/config              #    mkdir -p $PORTAINER_DIR/data
    fi
  else
    echo "Do nothing."
  fi
}

# docker_network_create_portainer_network
#****************************************
docker_network_create_portainer_network() {
  docker network ls | grep portainer-network

  PORTAINER_NETWORK_FOUND=$?

  if [[ $PORTAINER_NETWORK_FOUND=$? == "0" ]];
  then
    echo "Do nothing."
  else
    docker network create \
     --driver overlay \
     --scope swarm \
     --attachable \
     portainer-network

    docker network ls | grep portainer-network

    PORTAINER_NETWORK_FOUND=$?

    if [[ $PORTAINER_NETWORK_FOUND == "0" ]];
    then
      echo "PORTAINER_NETWORK_STATUS=created" >> /tmp/user-data-output.txt
    else
      echo "PORTAINER_NETWORK_STATUS=none" >> /tmp/user-data-output.txt
    fi
  fi
}

# docker_service_create_portainer_agent_mn
#*****************************************
docker_service_create_portainer_agent_mn() {
  docker service ls | grep portainer-agent-mn-$MN_INDEX

  PORTAINER_AGENT_MN_FOUND=$?

  if [[ $PORTAINER_AGENT_MN_FOUND == "0" ]];
  then
    echo "Do nothing."
  else
    docker service create \
     --name portainer-agent-mn-$MN_INDEX \
     --network portainer-network \
     --env AGENT_CLUSTER_ADDR=tasks.portainer-agent-mn-$MN_INDEX \
     --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
     --mount type=bind,src=$NODE_DOCKER_ROOT_DIR/volumes,dst=/var/lib/docker/volumes \
     --constraint "node.platform.os==linux" \
     --constraint "node.hostname==$SWARM_NAME_0-mn-$MN_INDEX" \
     --mode replicated \
     --replicas 1 \
    portainer/agent:latest
  fi

  docker service ls | grep portainer-agent-mn-$MN_INDEX

  PORTAINER_AGENT_MN_FOUND=$?

  if [[ $PORTAINER_AGENT_MN_FOUND == "0" ]];
  then
    #export PORTAINER_AGENT_MN_STATUS=running
    echo "PORTAINER_AGENT_MN_STATUS=running" >> /tmp/user-data-output.txt
  else
    echo "PORTAINER_AGENT_MN_STATUS=none" >> /tmp/user-data-output.txt
  fi
}

# docker_service_create_portainer_agent_wn
#*****************************************
docker_service_create_portainer_agent_wn() {
  docker service ls | grep portainer-agent-wn

  PORTAINER_AGENT_WN_FOUND=$?

  if [[ $PORTAINER_AGENT_WN_FOUND == "0" ]];
  then
    echo "Do nothing."
  else
    docker service create \
     --name portainer-agent-wn \
     --network portainer-network \
     --env AGENT_CLUSTER_ADDR=tasks.portainer-agent-wn \
     --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
     --mount type=bind,src=/var/lib/docker/volumes,dst=/var/lib/docker/volumes \
     --constraint "node.platform.os==linux" \
     --constraint "node.role==worker" \
     --mode global \
    portainer/agent:latest
  fi

  docker service ls | grep portainer-agent-wn

  PORTAINER_AGENT_WN_FOUND=$?

  if [[ $PORTAINER_AGENT_WN_FOUND == "0" ]];
  then
    #export PORTAINER_AGENT_WN_STATUS=running
    echo "PORTAINER_AGENT_WN_STATUS=running" >> /tmp/user-data-output.txt
  else
    echo "PORTAINER_AGENT_WN_STATUS=none" >> /tmp/user-data-output.txt
  fi
}

# docker_volume_create_portainer_data
#************************************
docker_volume_create_portainer_data() {
  create_portainer_directory

  ls $PORTAINER_DIR | grep data

  PORTAINER_DATA_FOUND=$?

  if [[ $PORTAINER_DATA_FOUND == "0" ]];
  then
    docker volume create \
     --driver local \
     --opt type=nfs \
     --opt device=:/dashboards/portainer/data \
     --opt o=addr=$SWARM_DATA_STORE_DNS,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,rw \
    portainer-data
  else
    mkdir -p $PORTAINER_DIR/data

    docker volume create \
     --driver local \
     --opt type=nfs \
     --opt device=:/dashboards/portainer/data \
     --opt o=addr=$SWARM_DATA_STORE_DNS,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,rw \
    portainer-data
  fi

  docker volume ls | grep portainer-data

  PORTAINER_DATA_VOLUME_FOUND=$?

  if [[ $PORTAINER_DATA_VOLUME_FOUND == "0" ]];
  then
    echo "PORTAINER_DATA_VOLUME_STATUS=created" >> /tmp/user-data-output.txt
  else
    echo "PORTAINER_DATA_VOLUME_STATUS=none" >> /tmp/user-data-output.txt
  fi
}

# docker_service_create_portainer_server
#***************************************
docker_service_create_portainer_server() {
  docker service ls | grep portainer-server

  PORTAINER_SERVER_FOUND=$?

  if [[ $PORTAINER_SERVER_FOUND == "0" ]];
  then
    echo "Do nothing."
  else
    mv /tmp/config-files/portainer-dap.txt $PORTAINER_DIR/config/dap.txt

    docker service create \
     --name portainer-server \
     --endpoint-mode dnsrr \
     --network portainer-network \
     --publish published=$PORTAINER_SERVER_PORT,target=$PORTAINER_SERVER_PORT,mode=host \
     --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
     --mount type=bind,src=$PORTAINER_DIR/config/dap.txt,dst=/tmp/portainer_password \
     --mount type=volume,src=portainer-data,dst=/data \
     --constraint "node.hostname==$SWARM_NAME_0-mn-1" \
     --mode replicated \
     --replicas 1 \
    portainer/portainer-ce:latest --admin-password-file /tmp/portainer_password -H "tcp://tasks.portainer-agent-mn-1:9001" --tlsskipverify
    #--base-url /portainer

    docker service ls | grep portainer-server

    PORTAINER_SERVER_FOUND=$?

    if [[ $PORTAINER_SERVER_FOUND == "0" ]];
    then
      echo "PORTAINER_SERVER_STATUS=running" >> /tmp/user-data-output.txt
    else
      echo "PORTAINER_SERVER_STATUS=none" >> /tmp/user-data-output.txt
    fi
  fi
}

# deploy_portainer_stack
#***********************
deploy_portainer_stack() {
  if [[ $MN_INDEX == "1" ]];
  then
    docker_network_create_portainer_network
    docker_volume_create_portainer_data

    docker_service_create_portainer_agent_mn
    docker_service_create_portainer_agent_wn
    docker_service_create_portainer_server
  else
    docker_service_create_portainer_agent_mn
  fi
}

# send_slack_notification function
#*********************************
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
