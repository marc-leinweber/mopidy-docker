#!/bin/bash
apt-get update
apt-get upgrade -y
pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U
exec mopidy --config /mopidy/mopidy.conf

