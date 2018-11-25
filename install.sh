#!/usr/bin/env bash

function waiting_for_jboss {
  while [[ $(sudo netstat -ltnp | grep 9990 | wc -l) -lt 1 ]] ; do sleep 1s ; done
}

waiting_for_jboss

if [ "${JBOSS_EAP_PATCH}" != '7.1.0' ] ; then

  mkdir -p ./patches
  wget -q -i "${PATCHES_BASE_URL}/index.txt" -P ./patches/ || echo 'no patches found.'

  for PATCH_FILENAME in $(ls ./patches/*.zip) ; do
    echo "Applying $(basename ${PATCH_FILENAME}) file..."
    INSTRUCTIONS_FILE="${PATCH_FILENAME}.instructions"

    if [[ ${PATCH_FILENAME} == *-7.0.5-patch.zip ]] ; then
      echo "connect
            patch apply ${PATCH_FILENAME} --override=bin/standalone.conf,bin/standalone.conf.bat
            shutdown --restart=true" > ${INSTRUCTIONS_FILE}
    else
      echo "connect
            patch apply ${PATCH_FILENAME}
            shutdown --restart=true" > ${INSTRUCTIONS_FILE}
    fi

    jboss-cli.sh --file=${INSTRUCTIONS_FILE}
    rm -rf ${INSTRUCTIONS_FILE} ${PATCH_FILENAME}
    waiting_for_jboss
  done
fi

if [ -z ${KEEP_HISTORY} ] || [[ ! ${KEEP_HISTORY} =~ ^(keep|yes|true)$ ]] ; then
  echo 'Cleanup history...'
  jboss-cli.sh --commands='connect','/core-service=patching:ageout-history'
fi

echo 'Shutdown JBoss...'
jboss-cli.sh --commands='connect','shutdown --restart=false'

if [ -z ${KEEP_HISTORY} ] || [[ ! ${KEEP_HISTORY} =~ ^(keep|yes|true)$ ]] ; then
  echo 'Cleanup tmp, data, logs...'
  for FOLDER in "tmp" "data" "log" ; do
    sudo rm -rf ${JBOSS_HOME}/standalone/${FOLDER}
  done
fi

echo 'Done.'
