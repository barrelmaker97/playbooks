#!/bin/bash
# Verify the full DNS stack resolves queries end-to-end
dig @127.0.0.1 -p 53 google.com +short +time=2 +tries=1 > /dev/null 2>&1
