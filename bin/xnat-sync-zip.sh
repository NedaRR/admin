#!/bin/bash
# Syncs the xnat filesystem to a remote filesystem, zipping every scan along
# the way
# 
# Usage: 
#   xnat-sync-zip.sh <xnat_dir> <backup_dir>
#
#
# Assumes that the xnat filesystem is structured like so: 
#
#   /mnt/xnat/.../{study}/arc001/{exam}

#
# The sync happens in two stages: 
# 1. Everything except the files below any SCANS/ folder are synced
# 2. Each SCANS/ folder is inspected, and any exams that do not have
#    corresponding zip files on the backup are zipped. 
set -e 

xnat_dir=${1}
backup_dir=${2}

backup_xnat_root=${backup_dir}/$(basename $xnat_dir)  

if [[ "$xnat_dir" =~ /$ ]]; then
    echo The xnat dir must not have a trailing slash: $xnat_dir
    exit 1
fi 


rsync -a --delete --exclude=cachearchive --exclude='arc001/**' ${xnat_dir} ${backup_dir}

find ${xnat_dir}  -type d -name arc001 -exec find {} -mindepth 1 -maxdepth 1 \; -prune | \
while read exam_dir; do 
    backup_zip=${exam_dir/$xnat_dir/${backup_xnat_root}}.zip
    exam_parent_dir=$(dirname ${exam_dir})
    exam_dir_name=$(basename ${exam_dir})

    echo "cd $exam_parent_dir && time zip -qru ${backup_zip} ${exam_dir_name}"
done | parallel -v -j1 
