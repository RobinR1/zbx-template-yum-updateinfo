#!/bin/bash
#####################################################################################
# yum-updateinfo.sh - Retrieves available security and package updates using YUM
#                     and send it to Zabbix.
#
# Author: robin.roevens (at) disroot.org
# Version: 1.0
#
# Requires: yum-plugin-security
#           zabbix-sender
#
# Note: on CentOS there are no security errata included in the repositories, hence
#       security info on CentOS won't work. Other repo's you added may include such
#       data, EPEL does for example, but ofcourse only for packages provided by EPEL.
#
# Host in Zabbix should be configured with the "Template Module YUM updateinfo by 
# Zabbix trapper" template.
# Schedule this script to run each hour or so using a Systemd timer or cron job.

# Configuration
ZBX_CONFIG=/etc/zabbix/zabbix_agentd.conf
ZBX_SENDER_BIN=zabbix_sender

ZBX_ITEM_PREFIX=yum.updateinfo
ZBX_DATA=/tmp/zabbix-sender-yum-updateinfo.data
ZBX_SENDER=$(which $ZBX_SENDER_BIN)

[[ $ZBX_SENDER ]] || { echo "Error: $ZBX_SENDER_BIN was not found"; exit 1; }

# Prepare temp files
summary=$(mktemp)
echo -n > $ZBX_DATA

# Cleanup when script exits
trap \
    "{ echo \"Cleaning up...\"; rm -f "${summary}" ; rm -f "${ZBX_DATA}"; exit 255; }" \
 SIGINT SIGTERM ERR EXIT

# Get number of available updates
echo "Retrieving YUM update summary..."
timeout -k 30 5m yum updateinfo summary > $summary || { echo "Error: Failed retrieving updateinfo summary from YUM."; exit; }
CRITICAL=$(grep "Critical Security notice" $summary | awk '{ print $1 }')
IMPORTANT=$(grep "Important Security notice" $summary | awk '{ print $1 }')
MODERATE=$(grep "Moderate Security notice" $summary | awk '{ print $1 }')
LOW=$(grep "Low Security notice" $summary | awk '{ print $1 }')
BUGFIX=$(grep "Bugfix notice" $summary | awk '{ print $1 }')
ENHANCEMENT=$(grep "Enhancement notice" $summary | awk '{ print $1 }')

# Get list of known vulnerabilities
echo "Retrieving list of known vulnerabilities..."
CVES=$(timeout -k 30 5m yum updateinfo list cves | grep "CVE-" | awk '{ print $1 }' | sort -u | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/, /g')

# Count total number of available updates
echo "Retrieving list of all updates..."
UPDATES=$(timeout -k 30 5m yum -q check-update | egrep '(.i386|.x86_64|.noarch|.src)' | awk '{ print $1 }' | sort -u) 
if [[ $UPDATES ]]; then
    UPDATES_COUNT=$(echo "$UPDATES" | wc -l)
    UPDATES=$(echo "$UPDATES" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/, /g' )
else
    UPDATES="none"
    UPDATES_COUNT=0;
fi

# Add data to file and send it to Zabbix Server 
echo "Generating $ZBX_DATA..."
[[ $CRITICAL ]] && echo "- $ZBX_ITEM_PREFIX.security.critical $CRITICAL" >> $ZBX_DATA || echo "- $ZBX_ITEM_PREFIX.security.critical 0" >> $ZBX_DATA
[[ $IMPORTANT ]] && echo "- $ZBX_ITEM_PREFIX.security.important $IMPORTANT" >> $ZBX_DATA || echo "- $ZBX_ITEM_PREFIX.security.important 0" >> $ZBX_DATA
[[ $MODERATE ]] && echo "- $ZBX_ITEM_PREFIX.security.moderate $MODERATE" >> $ZBX_DATA || echo "- $ZBX_ITEM_PREFIX.security.moderate 0" >> $ZBX_DATA
[[ $BUGFIX ]] && echo "- $ZBX_ITEM_PREFIX.bugfixes $BUGFIX" >> $ZBX_DATA || echo "- $ZBX_ITEM_PREFIX.bugfixes 0" >> $ZBX_DATA
[[ $LOW ]] && echo "- $ZBX_ITEM_PREFIX.security.low $LOW" >> $ZBX_DATA || echo "- $ZBX_ITEM_PREFIX.security.low 0" >> $ZBX_DATA
[[ $ENHANCEMENT ]] && echo "- $ZBX_ITEM_PREFIX.enhancement $ENHANCEMENT" >> $ZBX_DATA || echo "- $ZBX_ITEM_PREFIX.enhancement 0" >> $ZBX_DATA
[[ $CVES ]] && echo "- $ZBX_ITEM_PREFIX.security.cves $CVES" >> $ZBX_DATA || echo "- $ZBX_ITEM_PREFIX.security.cves none" >> $ZBX_DATA
echo "- $ZBX_ITEM_PREFIX.updates $UPDATES" >> $ZBX_DATA 
echo "- $ZBX_ITEM_PREFIX.updates.count $UPDATES_COUNT" >> $ZBX_DATA 

echo "Sending data to Zabbix:"
cat $ZBX_DATA

$ZBX_SENDER -c $ZBX_CONFIG -i $ZBX_DATA