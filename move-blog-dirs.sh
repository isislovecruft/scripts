#!/usr/bin/env bash
#-----------------------------------------------------------------------------
# move-blog-dirs.sh
# -----------------
# Used with Pelican for patternsinthevoid.net to change the ownership and
# permissions of generated HTML, then move the files and directories into the
# webserver root.
#
# :author: isis lovecruft <isis@patternsinthevoid.net> 0xa3adb67a2cdb8b35
# :licence: WTFPL
# :version: 0.0.1
#----------------------------------------------------------------------------

sudo rsync -q -rthL --safe-links --protect-args \
    --chmod=go=rX --chmod=u=rwX --cvs-exclude --delete-during \
    --delete-excluded --force --prune-empty-dirs \
    --log-file=/home/isis/update.log \
    /home/isis/published/ /var/www/blog.patternsinthevoid.net/docroot/
sudo chown -R www-data:www-data /var/www/blog.patternsinthevoid.net/docroot/
