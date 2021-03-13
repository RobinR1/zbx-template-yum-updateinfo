# Template Module YUM updateinfo by Zabbix trapper

## Overview

For Zabbix version: 4.0

This template monitors a host for available security updates, enhancements, bugfixes and general package updates.
Additionally it will feed Zabbix with a list of known vulnerabilities (as known by YUM) and package names of the available updates.

This template was tested on:

- Zabbix 4.4
- CentOS 7 (no security errata available)
- Oracle Linux 7
and should work on any Redhat derivative.

## Setup

On all hosts you want to monitor:
- Install packages `yum-plugin-security` and `zabbix-sender` 
- Copy `scripts/yum-updateinfo.sh` to `/etc/zabbix/scripts`
- Copy Systemd unit files 
  - `systemd/zabbix-template-module-yum-updateinfo.service` and 
  - `systemd/zabbix-template-module-yum-updateinfo.timer` 
  to `/etc/systemd/system`
- By default the systemd timer will execute the script every hour. Change this in the `.timer`-file to your needs.
- If you chose to put the `yum-updateinfo.sh` script somewhere else than `/etc/zabbix/scripts`, adjust the path in the `.service`-file
- Enable and start the Systemd timer:
  ```
  systemctl daemon-reload
  systemctl enable zabbix-template-module-yum-updateinfo.timer
  systemctl start zabbix-template-module-yum-updateinfo.timer
  ```
On Zabbix server:
- Import the `template_module_yum_updateinfo.xml` template into Zabbix
- Assign the template "Template Module YUM updateinfo by Zabbix trapper" to the host(s) you want to monitor

## Zabbix configuration

No specific Zabbix configuration is required

### Macros used

|Name|Description|Default|
|----|-----------|-------|
|{$YUM_UPDATEINFO_MAXAGE} |<p>Max age of available security updates information</p>|`2d` |

#### Notes about $YUM_UPDATEINFO_MAXAGE

The template will trigger a warning if no new information was received within the time set by this macro. Don't set this to 1h if the script is executed only once an hour since the script may take some time to finish collecting information from YUM so it may take a little longer than that hour for new data to actually reach the Zabbix server.

## Feedback

Please report any issues with the template at https://github.com/RobinR1/zbx-template-yum-updateinfo/issues