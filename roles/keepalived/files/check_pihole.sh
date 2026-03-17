#!/bin/bash
# Simple script to check if pihole-FTL is running
if pgrep pihole-FTL > /dev/null; then
    exit 0
else
    exit 1
fi
