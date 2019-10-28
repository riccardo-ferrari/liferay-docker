#!/bin/bash

function main {
	echo ""
	echo "[LIFERAY] Starting ${LIFERAY_PRODUCT_NAME}. To stop the container with CTRL-C, run this container with the option \"-it\"."
	echo ""

	if [[ "${LIFERAY_EXPLODE_MODE}" == "true" ]] || [[ "${LIFERAY_EXPLODE_MODE}" == "test" ]]
	then
	    export LIFERAY_MODULE_PERIOD_FRAMEWORK_PERIOD_BASE_PERIOD_DIR=${LIFERAY_MOUNT_DIR}/osgi
	fi

	if [ "${LIFERAY_JPDA_ENABLED}" == "true" ]
	then
		${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run
	else
		${LIFERAY_HOME}/tomcat/bin/catalina.sh run
	fi
}

main