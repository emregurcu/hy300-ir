#!/bin/bash
cd "$(dirname "$0")"
sudo python3 kumanda.py "$@" || python3 kumanda.py --port 8080 "$@"
