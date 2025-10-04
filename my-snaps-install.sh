#!/bin/bash
cat ${DEV_MOUNT_POINT}/Configs/my-snap.list | while read snappkg
do
  flag="--classic"
  if [[ "$snappkg" == "xdman" ]]
  then
    flag="$flag --beta"
  fi

  echo "--- Installing \`$snappkg\` with \`$flag\` flags ---"
  sudo snap install $snappkg $flag
  echo ""
done


