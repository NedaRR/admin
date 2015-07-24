#!/bin/bash
# trailing slash on /projects/david/ says "copy the contents"
rsync -a --delete /projects/david/ /alumni/david/projects/
