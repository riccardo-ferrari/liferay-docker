#!/bin/bash

workspace_uid="$(/usr/bin/stat -c %u ${WORKSPACE_DIR})"
workspace_gid="$(/usr/bin/stat -c %g ${WORKSPACE_DIR})"
groupadd -g ${workspace_gid} liferay
useradd -g ${workspace_gid} -m -s /bin/bash -u ${workspace_uid} liferay
su - liferay -p 

