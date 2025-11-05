#!/bin/bash

############################## Helper Methods ###################################
function format_memory()
{
    memory=$1

    if [[ $memory -eq 0 ]]
    then
        echo -ne "0B"
    elif [[ $memory -ge 1048576 ]]
    then
        mem=$(bc -l <<< "scale=1;$memory / 1048576")
        echo -ne "${mem}G"
    elif [[ $memory -ge 1024 ]]
    then
        mem=$(bc -l <<< "scale=1;$memory / 1024")
        echo -ne "${mem}M"
    else
        mem=$(bc -l <<< "scale=1;$memory")
        echo -ne "${mem}K"
    fi
}

function format_speed()
{
    speed=$1

    if [[ $speed -ge 1073741824 ]]
    then
        netspeed=$(bc -l <<< "scale=1;$speed / 1073741824")
        echo -ne "${netspeed}G/s"
    elif [[ $speed -ge 1048576 ]]
    then
        netspeed=$(bc -l <<< "scale=1;$speed / 1048576")
        echo -ne "${netspeed}M/s"
    elif [[ $speed -ge 1024 ]]
    then
        netspeed=$(bc -l <<< "scale=1;$speed / 1024")
        echo -ne "${netspeed}K/s"
    else
        netspeed=$(bc -l <<< "scale=1;$speed")
        echo -ne "${netspeed}B/s"
    fi
}

function format_cpu()
{
    cpu=$1
    cpuused=$(bc -l <<< "scale=1;$cpu")
    echo -ne "${cpuused}%"
}

function format_gpu()
{
    gpu=$1
    gpuunit=$2

    if [[ "$gpuunit" == "GiB" ]]
    then
        gpuinbyte=$(bc -l <<< "scale=1;$gpu * 1024 * 1024")
        echo -ne "$(format_memory $gpuinbyte)"

    elif [[ "$gpuunit" == "MiB" ]]
    then
        gpuinbyte=$(bc -l <<< "scale=1;$gpu * 1024 ")
        echo -ne "$(format_memory $gpuinbyte)"

    elif [[ "$gpuunit" == "KiB" ]]
    then
        gpuinbyte=$(bc -l <<< "scale=1;$gpu")
        echo -ne "$(format_memory $gpuinbyte)"
    else
        gpuinbyte=$(bc -l <<< "scale=1;$gpu")
        echo -ne "$(format_memory $gpuinbyte)"
    fi
}

############################## CPU Stats ###################################
cpustats=$(top -bn 2 -d 0.2 | grep '^%Cpu' | tail -n 1 | gawk '{print $2+$4+$6}')

############################## RAM Stats ###################################
totalram=$(grep -e "^MemTotal" -m 1 /proc/meminfo | sed 's/[^0-9]//g')
availram=$(grep -e "^MemAvailable" -m 1 /proc/meminfo | sed 's/[^0-9]//g')
usedram=$((totalram - availram))

############################## SWAP Stats ###################################
totalswap=$(grep -e "^SwapTotal" -m 1 /proc/meminfo | sed 's/[^0-9]//g')
availswap=$(grep -e "^SwapFree" -m 1 /proc/meminfo | sed 's/[^0-9]//g')
usedswap=$((totalswap - availswap))

############################## Network Stats ###################################
defaultinterface=$(ip route list | grep ^default | gawk '{print $5}')

prev_rx=$(awk '{print $0}' "/sys/class/net/${defaultinterface}/statistics/rx_bytes")
prev_tx=$(awk '{print $0}' "/sys/class/net/${defaultinterface}/statistics/tx_bytes")
sleep 0.25
curr_rx=$(awk '{print $0}' "/sys/class/net/${defaultinterface}/statistics/rx_bytes")
curr_tx=$(awk '{print $0}' "/sys/class/net/${defaultinterface}/statistics/tx_bytes")

rx=$(((curr_rx - prev_rx) * 4))
tx=$(((curr_tx - prev_tx) * 4))

############################## GPU Stats ###################################
gpuexist=$(nvidia-smi -q>/dev/null 2>&1; [[ $? -eq 0 ]] && echo 1 || echo 0)
if [[ $gpuexist -eq 1 ]]
then
    numgpu=$(nvidia-smi -q -d MEMORY | grep BAR | wc -l)
    totalgpu=$(nvidia-smi -q -d MEMORY | grep BAR -A2 | grep Total | awk '{print $3}')
    totalgpuunit=$(nvidia-smi -q -d MEMORY | grep BAR -A2 | grep Total | awk '{print $4}')
    usedgpu=$(nvidia-smi -q -d MEMORY | grep BAR -A2 | grep Used | awk '{print $3}')
    usedgpuunit=$(nvidia-smi -q -d MEMORY | grep BAR -A2 | grep Used | awk '{print $4}')
fi

############################## Output Stats ###################################
stats="""⌘ $(format_cpu $cpustats)    ⚅ $(format_memory $usedram)/$(format_memory $totalram)"""
if [[ $totalswap -ne 0 ]]
then
stats="""$stats    ♻ $(format_memory $usedswap)/$(format_memory $totalswap)"""
fi
if [[ $gpuexist -eq 1 ]]
then
    stats="""$stats    🆛 $(format_gpu $usedgpu $usedgpuunit)/$(format_gpu $totalgpu $totalgpuunit)"""
fi
stats="""$stats    ⬆ $(format_speed $tx)  ⬇ $(format_speed $rx) """
echo -e """$stats"""

