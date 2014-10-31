#!/bin/bash
# Backup all the things
# This script expects to be run as root :-)

# set path for cron-y goodness
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# http://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t $(basename $0)) 2>&1

excludes="--exclude=.cache --exclude=Cache --exclude='.Trash*'"
excludes="$excludes --exclude=.thumbnails --exclude=Trash"
rsync_opts="-aH --delete $excludes"   # add -n for a dry run

function log { echo "$1"; }
function die { echo "$1"; exit 1; }
function sync { 
  src=$1    # source folder to rsync (trailing slashes are important!)
  dest=$2   # destination folder 
  log "Backup $src to $dest"
  mountpoint -q $src || (mount $src || die "Failed to mount $src. Skipping.")
  rsync $rsync_opts $src $dest
}
  
log "Mounting ZFS"
zfs mount -a    || die "Failed to mount ZFS datasets"

# note trailing slashes on source folders. rsync treats this as "copy everything
# from inside the folder, but not the folder itself"
sync /archive         /tank
sync /home            /tank
sync /spins           /tank
sync /projects        /tank
sync /quarantine      /tank
sync /opt/quarantine/ /tank/quarantine-nouveau

log "Taking a ZFS snapshot of tank"
/usr/local/bin/zsnap --keep=8 --prefix=daily- tank

log "Backup /home to tigrsrv:/pool/home and take ZFS snapshot"
sudo -u localroot ssh tigrsrv \
  "(mountpoint -q /pool/home || sudo zfs mount pool/home) &&
   sudo rsync $rsync_opts /home/ /pool/home &&
   sudo /usr/local/bin/zsnap --keep=8 --prefix=daily- pool/home"

log "Backup complete."
