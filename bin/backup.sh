#!/bin/bash
# Backup all the things
# This script expects to be run as root :-)

# set path for cron-y goodness
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# http://urbanautomaton.com/blog/2014/09/09/redirecting-bash-script-output-to-syslog/
exec 1> >(logger -s -t $(basename $0)) 2>&1

excludes="--exclude=.cache --exclude=Cache --exclude='.Trash*'"
excludes="$excludes --exclude=.thumbnails --exclude=Trash"
rsync_opts="-aH -F --delete $excludes"   # add -n for a dry run
                                         # -a transfers ownership and perms
                                         # -H preserves hardlinks
                                         # -F excludes all folders with
                                         #    .rsync-filter files in them
                                         # --delete deletes files on target

function log { echo "$(date): $1"; }
function die { log "$1"; exit 1; }
function sync { 
  src=$1    # source folder to rsync (trailing slashes are important!)
  dest=$2   # destination folder 
  log "Backup $src to $dest"
  mountpoint -q $src || (mount $src || die "Failed to mount $src. Skipping.")
  echo rsync $rsync_opts $src $dest
}
  
log "Mounting ZFS"
zfs mount -a || die "Failed to mount ZFS tank dataset"

# note trailing slashes on source folders. rsync treats this as "copy everything
# from inside the folder, but not the folder itself"
sync /archive         /tank
sync /projects        /tank
# this isnt the whole database, but it is all of the data.
sync /mnt/xnat        /tank
sync /quarantine      /tank
sync /opt/quarantine/ /tank/quarantine-nouveau

log "Taking a ZFS snapshot of tank"
/usr/local/bin/zsnap --keep=8 --prefix=daily- tank

log "Backup complete."
log "Space used on tank: $(zfs get used tank -Ho value) (logically: $(zfs get lused tank -Ho value))"
log "Space free on tank: $(zfs get avail tank -Ho value)"
