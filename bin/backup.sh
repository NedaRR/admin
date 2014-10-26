#!/bin/bash
# Backup our servers
# This script expects to be run as root :-)

# set path for cron-y goodness
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# http://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t $(basename $0)) 2>&1

excludes="--exclude=.cache --exclude=Cache --exclude='.Trash*'"
excludes="$excludes --exclude=.thumbnails --exclude=Trash"
rsync_opts="-aH --delete $excludes"   # set to -n for a dry run

function log { echo "$1"; }
function die { echo "$1"; exit 1; }
function sync { 
  mnt=$1    # mount holding src
  src=$2    # source folder to rsync (trailing slashes are important!)
  dest=$3   # destination folder 
  log "Backup $src to $dest"
  mountpoint -q $mnt || (mount $mnt || die "Failed to mount $mnt. Skipping.")
  rsync $rsync_opts $src $dest
}
  
log "Mounting ZFS"
zfs mount -a    || die "Failed to mount ZFS datasets"

# note trailing slashes
sync /archive        /archive/data    /tank/archive
sync /archive        /archive/spins   /tank/archive
sync /home           /home            /tank
sync /projects       /projects        /tank
sync /quarantine     /quarantine      /tank
sync /opt/quarantine /opt/quarantine/ /tank/quarantine-nouveau

log "Taking a ZFS snapshot of tank"
/usr/local/bin/zsnap --keep=8 --prefix=daily- tank

log "Backup /home to tigrsrv:/pool/home and taking ZFS snapshot"
sudo -u localroot ssh tigrsrv \
  "(mountpoint -q /pool/home || sudo zfs mount pool/home) &&
   sudo rsync $rsync_opts /home/ /pool/home &&
   sudo /usr/local/bin/zsnap --keep=8 --prefix=daily- pool/home"

log "Backup complete."
