#!/usr/bin/env bash

stats_raw=`curl --connect-timeout 2 --max-time $API_TIMEOUT --silent --noproxy '*' http://127.0.0.1:$MINER_API_PORT/stat`
if [[ $? -ne 0  || -z $stats_raw ]]; then
  echo -e "${YELLOW}Failed to read $miner stats_raw from localhost:${MINER_API_PORT}${NOCOLOR}"
else
  khs=`echo "$stats_raw" | jq -r '.devices[].speed' | awk '{s+=$1} END {printf("%.4f",s/1000)}'` #sum up and convert to khs
  local ac=$(jq -r '.total_accepted_shares' <<< "$stats_raw")
  local rj=$(jq -r '.total_rejected_shares - .total_invalid_shares' <<< "$stats_raw")
  local inv=$(jq -r '.total_invalid_shares' <<< "$stats_raw")

  # set -x
  #All fans speed array
  local fan=$(jq -r ".fan | .[]" <<< $gpu_stats)
  #All temp array
  local temp=$(jq -r ".temp | .[]" <<< $gpu_stats)

  #All busid array
  local all_bus_ids_array=(`echo "$gpu_detect_json" | jq -r '[ . | to_entries[] | select(.value) | .value.busid [0:2] ] | .[]'`)
  #Formating arrays

  #gminer's busid array
  local bus_id_array=(`jq -r '.devices[].bus_id[5:7]' <<< "$stats_raw"`)
  local bus_numbers=()
  local idx=0
  for gpu in ${bus_id_array[@]}; do
     bus_numbers[idx]=$((16#$gpu))
     idx=$((idx+1))
  done

  fan=`tr '\n' ' ' <<< $fan`
  temp=`tr '\n' ' ' <<< $temp`
  #IFS=' ' read -r -a bus_id_array <<< "$bus_id_array"
  IFS=' ' read -r -a fan <<< "$fan"
  IFS=' ' read -r -a temp <<< "$temp"

  #busid equality
  local fans_array=
  local temp_array=
  for ((i = 0; i < ${#all_bus_ids_array[@]}; i++)); do
    for ((j = 0; j < ${#bus_id_array[@]}; j++)); do
      if [[ "$(( 0x${all_bus_ids_array[$i]} ))" -eq "$(( 0x${bus_id_array[$j]} ))" ]]; then
        fans_array+=("${fan[$i]}")
        temp_array+=("${temp[$i]}")
      fi
    done
  done

  [[ -z $GMINER_ALGO ]] && GMINER_ALGO="144_5"
  [[ "$GMINER_ALGO" == "beamhashI" ]] && GMINER_ALGO="150_5"
  [[ "$GMINER_ALGO" == "beamhash" ]] && GMINER_ALGO="equihash 150/5"
  [[ "$GMINER_ALGO" == "beamhashII" ]] && GMINER_ALGO="equihash 150/5/3"
  [[ "$GMINER_ALGO" == "beamhashIII" ]] && GMINER_ALGO="beamhashv3"

  if [[ -n "$GMINER_ALGO2" ]]; then
    local total_khs2=`echo "$stats_raw" | jq -r '.devices[].speed2' | awk '{s+=$1} END {printf("%.4f",s/1000)}'` #sum up and convert to khs
    algo=$GMINER_ALGO
    algo2=$GMINER_ALGO2
    [[ "$GMINER_ALGO2" == "ton" ]] && algo2="sha256-ton"
    local ac2=$(jq '[.devices[].accepted_shares2] | add' <<< "$stats_raw")
    local rj2=$(jq '[.devices[].rejected_shares2] | add' <<< "$stats_raw")
    stats=$(jq -c \
          --argjson temp "`echo "${temp_array[@]}" | jq -s . | jq -c .`" \
          --argjson fan "`echo "${fans_array[@]}" | jq -s . | jq -c .`" \
          --arg ac "$ac" --arg rj "$rj" --arg iv "$inv" \
          --arg inv_gpu "$(echo "$stats_raw" | jq -r '.devices[].invalid_shares' | tr '\n' ';')" \
          --arg ac2 "$ac2" --arg rj2 "$rj2" \
          --argjson bus_numbers "`echo "${bus_numbers[@]}" | jq -sc .`" \
          --arg algo "$algo" --arg algo2 "$algo2" \
          --arg ver $(echo "$stats_raw" | jq -r '.miner' | awk '{ print $2 }') \
          --arg total_khs "$khs" --arg total_khs2 "$total_khs2" \
          '{hs: [.devices[].speed/1000], hs_units: "khs", ar: [$ac, $rj, $iv, $inv_gpu], $algo,
            $bus_numbers, $temp, $fan, uptime: .uptime, $ver}' <<< "$stats_raw")
  else
    algo=$GMINER_ALGO
    [[ "$GMINER_ALGO" == "ton" ]] && algo="sha256-ton"
    stats=$(jq -c \
          --argjson temp "`echo "${temp_array[@]}" | jq -s . | jq -c .`" \
          --argjson fan "`echo "${fans_array[@]}" | jq -s . | jq -c .`" \
          --arg ac "$ac" --arg rj "$rj" --arg iv "$inv" \
          --arg inv_gpu "$(echo "$stats_raw" | jq -r '.devices[].invalid_shares' | tr '\n' ';')" \
          --argjson bus_numbers "`echo "${bus_numbers[@]}" | jq -sc .`" \
          --arg algo "$algo"  \
          --arg ver $(echo "$stats_raw" | jq -r '.miner' | awk '{ print $2 }') \
          '{hs: [.devices[].speed/1000], hs_units: "khs", ar: [$ac, $rj, $iv, $inv_gpu], $algo,
            $bus_numbers, $temp, $fan, uptime: .uptime, $ver}' <<< "$stats_raw")
  fi
fi
