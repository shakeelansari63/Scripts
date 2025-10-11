#!/bin/bash
flatpaks=$(cat ${DEV_MOUNT_POINT}/Configs/my-flatpaks.list | tr '\n' ' ')
sudo flatpak install flathub $flatpaks -y

# Install Flatpaks from flatpak file
ls -rt ${DEV_MOUNT_POINT}/Configs/Flatpaks/*.flatpak | while read flatpakfile
do
sudo flatpak install --bundle $flatpakfile -y
done
