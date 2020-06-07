#!/bin/bash
apt-get update
apt-get upgrade -y
pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U
ping -4 -w 60 google.com
ping -4 -w 60 spotify.com
exec mopidy --config /mopidy/mopidy.conf

