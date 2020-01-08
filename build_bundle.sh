#!/bin/bash

source _common.sh

function fix_tomcat_setenv {
    echo "Inspecting ${1}"

	local jvm_opts="-Xms2560m -Xmx2560m -XX:MaxNewSize=1536m -XX:MaxMetaspaceSize=512m -XX:MetaspaceSize=512m -XX:NewSize=1536m -XX:SurvivorRatio=7"

	#
	# For 7.1.3
	#

	sed -i "s/-Xms1280m -Xmx1280m -XX:MaxNewSize=256m -XX:NewSize=256m -XX:MaxMetaspaceSize=512m -XX:MetaspaceSize=512m -XX:SurvivorRatio=7/${jvm_opts}/" ${1}/bin/setenv.bat
	sed -i "s/-Xms2560m -Xmx2560m -XX:MaxNewSize=1536m -XX:MaxMetaspaceSize=512m -XX:MetaspaceSize=512m -XX:NewSize=1536m -XX:SurvivorRatio=7/${jvm_opts}/" ${1}/bin/setenv.sh

	#
	# For 7.1.10.1
	#

	sed -i "s/-Xmx1024m -XX:MaxMetaspaceSize=512m/${jvm_opts}/" ${1}/bin/setenv.bat
	sed -i "s/-Xmx1024m -XX:MaxMetaspaceSize=512m/${jvm_opts}/" ${1}/bin/setenv.sh

	if $(! grep -q -e "${jvm_opts}" ${1}/bin/setenv.bat) || $(! grep -q -e "${jvm_opts}" ${1}/bin/setenv.sh)
	then
		echo "Unable to set JVM options."
	fi
}

function install_fix_pack {
	local fix_pack_url=${1}
	local bundle_home=${2}

	#
	# See https://gist.github.com/ethanbustad/600d232539824db320d2977d453115a6.
	#

	echo ""
	echo "Download Patching Tool."
	echo ""

	rm -fr ${bundle_home}/patching-tool

	local patching_tool_version=$(curl ${CURL_OPTS} --silent https://files.liferay.com/private/ee/fix-packs/patching-tool/LATEST-2.0.txt)

    echo "version: ${patching_tool_version}"

	local patching_tool_name="patching-tool-${patching_tool_version}.zip"

	get_file files.liferay.com/private/ee/fix-packs/patching-tool/${patching_tool_name} ${bundle_home}/ true

	chmod u+x ${bundle_home}/patching-tool/*.sh

	echo ""
	echo "Install Patching Tool."
	echo ""

	local liferay_tomcat_version=$(get_tomcat_version ${bundle_home})

	echo -e "global.lib.path=../tomcat-${liferay_tomcat_version}/lib/ext/\nliferay.home=../\npatching.mode=binary\nwar.path=../tomcat-${liferay_tomcat_version}/webapps/ROOT/" > ${bundle_home}/patching-tool/default.properties

	${bundle_home}/patching-tool/patching-tool.sh auto-discovery ..

	${bundle_home}/patching-tool/patching-tool.sh revert

	rm -fr ${bundle_home}/${bundle_home}/patching-tool/patches/*

	echo ""
	echo "Download fix pack."
	echo ""

	get_file ${fix_pack_url} ${bundle_home}/patching-tool/patches/

	echo ""
	echo "Install fix pack."
	echo ""

	local patch_status=$(${bundle_home}/patching-tool/patching-tool.sh info | grep "\[ x\]\|\[ D\]\|\[ o\]\|\[ s\]")

	if [[ ! -z ${patch_status} ]]
	then
		echo "Unable to patch: ${patch_status}."

		exit 1
	fi

	${bundle_home}/patching-tool/patching-tool.sh install

	${bundle_home}/patching-tool/patching-tool.sh update-plugins

	rm -fr ${bundle_home}/osgi/state
}

function main {

    local portal_bundle_url=${1}

	local portal_bundle_name=${portal_bundle_url##*/}
    portal_bundle_name=${portal_bundle_name%.*}

    local portal_fix_pack=${2}

    local -n lpkgs=${3}

    local -n workspaces=${4}

	#
	# Make temporary directory.
	#

	local current_date=$(date)

	local timestamp=$(date "${current_date}" "+%Y%m%d%H%M")

    export TEMP_DIR=/tmp/${timestamp}

	mkdir -p ${TEMP_DIR}

	export LIFERAY_HOME=${TEMP_DIR}/liferay

    echo "bundle_name: ${portal_bundle_name}"
    echo "LIFERAY_HOME: ${LIFERAY_HOME}"

	#
	# Download and extract Portal.
	#

    get_file ${portal_bundle_url} ${TEMP_DIR} true

    mv ${TEMP_DIR}/liferay-* ${LIFERAY_HOME}

	#
	# Install fix pack.
	#

	if [[ ${portal_bundle_name} == *-dxp-* ]]
	then
		if [[ ! ${portal_fix_pack} == "none" ]]
		then
			install_fix_pack ${portal_fix_pack} ${LIFERAY_HOME}
		fi
	fi

	#
	# Install LPKGs
	#

    if [[ ! ${lpkgs} == "none" ]]
    then
        for lpkg_url in "${lpkgs[@]}"
        do
            local lpkg_name=${lpkg_url##*/}
            lpkg_name=${lpkg_name%.*}

            echo ""
            echo "Install LPKG: ${lpkg_name}"
            echo ""

            get_file ${lpkg_url} ${LIFERAY_HOME}/osgi/marketplace

            if [[ ${lpkg_name,,} == *commerce* ]]
            then
                echo "Found Commerce!"

                if [[ ${lpkg_name} == *hotfix* ]]
                then
                    commerce_full_name=$(echo ${lpkg_name} | sed 's/%20//g')
                    commerce_full_version=${commerce_full_name#*-}
                    commerce_version=${commerce_full_version%-*}
                else
                    commerce_full_name=$(echo ${lpkg_name} | sed 's/%20/-/g')
                    commerce_full_version=${commerce_full_name##*-}
                    commerce_version=${commerce_full_version%%-*}
                fi

                if [[ ${portal_bundle_name} == *-dxp-* ]]
                then
                    commerce_bundle_name=liferay-commerce-enterprise-${commerce_version}
                else
                    commerce_bundle_name=liferay-commerce-${commerce_version}
                fi

                mv ${LIFERAY_HOME} ${TEMP_DIR}/${commerce_bundle_name}

                export LIFERAY_HOME=${TEMP_DIR}/${commerce_bundle_name}

                echo "LIFERAY_HOME is now set to: ${LIFERAY_HOME}"

                portal_bundle_name=${commerce_bundle_name}

                echo "bundle_name is now set to: ${portal_bundle_name}"
            fi

        done
    fi

	#
	# Compile workspace
	#

    local cwd=${PWD}

    if [[ ! ${workspaces} == "none" ]]
    then
        for wrk in "${workspaces[@]}"
        do
            local tokens=($(echo ${wrk} | sed 's/@/ /g'))

            tokens_length=${#tokens[@]}

            echo "Token length: ${tokens_length}"

            if [[ ${tokens_length} == 2 ]]
            then
                wrk_path=${tokens[0]}
                branch=${tokens[1]}
                echo "w: ${wrk_path} b: ${branch}"
            else
                wrk_path=${wrk}
                echo "w: ${wrk_path}"
            fi

            cd ${WORKSPACE_DIR}/${wrk_path}

            echo ${PWD}

            if [[ ! -z ${branch} ]]
            then
                git checkout ${branch}
            fi

            repo_root=${wrk_path%%/*}

            if [[ -f ${WORKSPACE_DIR}/${repo_root}/app.server.properties ]]
            then
                echo "Inside portal repo"

                echo -e "\napp.server.parent.dir=${cwd}/${LIFERAY_HOME}" > "${WORKSPACE_DIR}/${repo_root}/app.server.$(whoami).properties"

                cd ${WORKSPACE_DIR}/${repo_root}

                ant setup-sdk install-portal-snapshots

                cd -
            elif [[ -f "gradle.properties" ]]
            then
                echo "Inside sub-repo"

                cp gradle.properties gradle.properties-${timestamp}

                echo -e "\napp.server.parent.dir=${cwd}/${LIFERAY_HOME}" >> gradle.properties

                echo "${GRADLE_CMD} ${GRADLE_OPTS_CUSTOM} ${GRADLE_TASKS}"
            fi

            eval "${GRADLE_CMD} ${GRADLE_OPTS_CUSTOM} ${GRADLE_TASKS}"

            if [[ -f ${WORKSPACE_DIR}/${repo_root}/app.server.properties ]]
            then
                echo ""
            elif [[ -f "gradle.properties" ]]
            then
                cp gradle.properties-${timestamp} gradle.properties
            fi

            local git_hash=$(git log -1 --pretty=format:%h)

            echo ${git_hash} > "${LIFERAY_HOME}/${wrk_path}.hash"

            cd ${cwd}

        done
    fi

	#
	# Start Tomcat.
	#

	start_tomcat ${LIFERAY_HOME}

	#
	# Build bundle.
	#
    echo "packaging"

	cd ${TEMP_DIR}

	mv liferay* ${portal_bundle_name}

	7z a ${P7Z_OPTS} ${portal_bundle_name}-${timestamp}.7z ${portal_bundle_name}

    if [[ ! -d ${CACHE_DIR}/releases ]]
    then
        mkdir -p ${CACHE_DIR}/releases
    fi

    cp ${portal_bundle_name}-${timestamp}.7z ${CACHE_DIR}/releases

	cd ..

}

function start_tomcat {
	local liferay_home=${1}

	rm -fr ${liferay_home}/data/elasticsearch**

	fix_tomcat_setenv ${liferay_home}/tomcat-$(get_tomcat_version ${liferay_home})

	cp ${liferay_home}/tomcat-*/bin/setenv.sh /tmp/setenv.sh.bak

	printf "\nexport LIFERAY_CLEAN_OSGI_STATE=true" >> ${liferay_home}/tomcat-*/bin/setenv.sh

    export CATALINA_PID=/tmp/catalina.pid

	${liferay_home}/tomcat-*/bin/startup.sh & disown

	until $(curl --head --fail --output /dev/null --silent http://localhost:8080)
	do
		sleep 3
	done

    echo "stop"

#    kill -15 $(cat ${CATALINA_PID})

	(${liferay_home}/tomcat-*/bin/shutdown.sh 180 )& disown

    while [[ $(jps | grep Bootstrap | wc -l | tr -d ' ') -gt 0 ]];
    do
        sleep 3
        echo "waiting shutdonw"
    done

#    echo "tomcat exit status: ${exit_status}"

    echo "clean"

	rm -fr ${liferay_home}/logs/*
	rm -fr ${liferay_home}/tomcat-*/logs/*
	rm -fr ${liferay_home}/osgi/state/*

	mv /tmp/setenv.sh.bak ${liferay_home}/tomcat-*/bin/setenv.sh

}

function parse_args {
    lpkgs=()
    workspaces=()

    for i in "$@"
    do
        case "${1}" in
            --portal)
                echo "'portal' is ${2}"
                export LIFERAY_PORTAL=${2}
                shift 2
                ;;
            --fix-pack)
                echo "'fix-pack' is ${2}"
                export LIFERAY_PORTAL_FIX_PACK=${2}
                shift 2
                ;;
            --lpkg)
                echo "'lpkgs' is ${2}"
                lpkgs+=(${2})
                shift 2
                ;;
            --workspace)
                echo "'workspace' is ${2}"
                workspaces+=(${2})
                shift 2
                ;;
            --user)
                export LIFERAY_AUTH=${2}
                export CURL_OPTS="${CURL_OPTS} -u ${LIFERAY_AUTH}"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    export LIFERAY_LPKG=(${lpkgs[@]})
    export LIFERAY_WORKSPACE=(${workspaces[@]})
}

function get_file() {
	FILE_URL=${1}

	DEST_PATH=${2}

	EXPLODE=${3}

	FILE_NAME=${1##*/}

	local release_dir=${1%/*}

	release_dir=${release_dir#*com/}
	release_dir=${release_dir#*com/}
	release_dir=${release_dir#*liferay-release-tool/}
	release_dir=${release_dir#*private/ee/}
	release_dir=${CACHE_DIR}/${release_dir}

	if [[ ! -e ${release_dir}/${FILE_NAME} ]]
	then
		echo ""
		echo "Downloading ${FILE_URL}."
		echo ""

		mkdir -p ${release_dir}

		curl ${CURL_OPTS} -f -o ${release_dir}/${FILE_NAME} ${FILE_URL} || exit 2
	fi

    if [[ -n ${EXPLODE} ]]
    then
        echo ""
        echo "Exploding ${release_dir}/${FILE_NAME} to ${DEST_PATH}"
        echo ""

        if [[ ${FILE_NAME} == *.7z ]]
        then
            7z x -O${DEST_PATH} ${release_dir}/${FILE_NAME} || exit 3
        else
            unzip -q ${release_dir}/${FILE_NAME} -d ${DEST_PATH}  || exit 3
        fi
    else
        echo ""
        echo "Copying ${release_dir}/${FILE_NAME} to ${DEST_PATH}"
        echo ""

        cp ${release_dir}/${FILE_NAME} ${DEST_PATH}
    fi
}

function drop_privilege() {
    local current_id=$(id -u)
    local workspace_uid="$(/usr/bin/stat -c %u ${WORKSPACE_DIR})"
    local workspace_gid="$(/usr/bin/stat -c %g ${WORKSPACE_DIR})"

    if [[ ! ${workspace_uid} == ${current_id} ]]
    then
        groupadd -g ${workspace_gid} liferay
        useradd -g ${workspace_gid} -m -s /bin/bash -u ${workspace_uid} liferay

        echo "Dropping privilege"

        export HOME=/home/liferay

        exec su - liferay -p "$0" -- " $@"

        echo "done"

        exit 0
    fi
}

drop_privilege ${@}

check_utils 7z curl java unzip git

parse_args ${@}

main ${LIFERAY_PORTAL} ${LIFERAY_PORTAL_FIX_PACK:-none} ${LIFERAY_LPKG[@]:-none} ${LIFERAY_WORKSPACE[@]:-none}