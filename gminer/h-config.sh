#!/usr/bin/env bash

function miner_ver() {
  local MINER_VER=$GMINER_VER
  if [[ -z $MINER_VER ]]; then
     MINER_VER=$MINER_LATEST_VER
     [[ ! -z $MINER_LATEST_VER_UBU16 && $(lsb_release  -c) =~ xenial ]] &&
                        MINER_VER=$MINER_LATEST_VER_UBU16
  fi
  echo $MINER_VER
}


function miner_config_echo() {
  local MINER_VER=`miner_ver`
  miner_echo_config_file "/hive/miners/$MINER_NAME/$MINER_VER/$MINER_NAME.conf"
}

function miner_config_gen() {
  local MINER_CONFIG="$MINER_DIR/$MINER_VER/$MINER_NAME.conf"
  mkfile_from_symlink $MINER_CONFIG

  [[ -z $GMINER_ALGO ]] && GMINER_ALGO="144_5"
  local conf="--algo $GMINER_ALGO"
  [[ "$GMINER_ALGO" == "ethash" && "$GMINER_ALGO2" == "eaglesong" ]] && conf="--algo eth+ckb" && echo "Dual mining Ethash+CKB"
  [[ "$GMINER_ALGO" == "ethash" && "$GMINER_ALGO2" == "blake2s" ]]   && conf="--algo eth+kda" && echo "Dual mining Ethash+KDA"
  [[ "$GMINER_ALGO" == "ethash" && "$GMINER_ALGO2" == "handshake" ]] && conf="--algo eth+hns" && echo "Dual mining Ethash+HNS"

  local hosts=($GMINER_HOST)
  local ports=($GMINER_PORT)

  for (( i=0; i < ${#hosts[@]}; i++)); do
    conf+=" --server ${hosts[$i]}"
    [[ ! -z ${ports[$i]} ]] && conf+=" --port ${ports[$i]}"
    [[ ! -z $GMINER_TEMPLATE ]] && conf+=" --user $GMINER_TEMPLATE"
    [[ ! -z $GMINER_PASS ]] && conf+=" --pass $GMINER_PASS"
    [[ $GMINER_TLS -eq 1 ]] && conf+=" --ssl 1"
  done

  if [[ ! -z $GMINER_ALGO2 ]]; then
     echo "Dual mining $GMINER_ALGO + $GMINER_ALGO2"
     if [[ $GMINER_ALGO2 == "zil" ]]; then
        hosts=($GMINER_HOST2)
        ports=($GMINER_PORT2)

        for (( i=0; i < ${#hosts[@]}; i++)); do
          conf+=" --zilserver ${hosts[$i]}"
          [[ ! -z ${ports[$i]} ]] && conf+=" --zilport ${ports[$i]}"
          [[ ! -z $GMINER_TEMPLATE2 ]] && conf+=" --ziluser $GMINER_TEMPLATE2"
          [[ ! -z $GMINER_PASS2 ]] && conf+=" --zilpass $GMINER_PASS2"
          [[ $GMINER_TLS2 -eq 1 ]] && conf+=" --zilssl 1"
        done
     else
        conf+=" --dalgo $GMINER_ALGO2"
        hosts=($GMINER_HOST2)
        ports=($GMINER_PORT2)

        for (( i=0; i < ${#hosts[@]}; i++)); do
          conf+=" --dserver ${hosts[$i]}"
          [[ ! -z ${ports[$i]} ]] && conf+=" --dport ${ports[$i]}"
          [[ ! -z $GMINER_TEMPLATE2 ]] && conf+=" --duser $GMINER_TEMPLATE2"
          [[ ! -z $GMINER_PASS2 ]] && conf+=" --dpass $GMINER_PASS2"
          [[ $GMINER_TLS2 -eq 1 ]] && conf+=" --dssl 1"
        done

        [[ ! -z $GMINER_INTENSITY ]] && conf+=" --dual_intensity $GMINER_INTENSITY"
     fi
  fi

  conf+=" $GMINER_USER_CONFIG"


