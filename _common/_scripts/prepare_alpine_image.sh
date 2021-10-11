#!/bin/sh

SUDOCK_PATH="/usr/sbin/sudock"

[[ -z ${APK_ADD_PACKAGES} ]] && APK_ADD_PACKAGES="bash curl mc nano sudo unzip vim"
[[ -z ${DOCKER_USER} ]] && DOCKER_USER="docker"
[[ -z ${DOCKER_GROUP} ]] && DOCKER_GROUP="docker"

apk update && apk add ${APK_ADD_PACKAGES}

# -- Ensure regular user and group
echo "Add/create ${DOCKER_USER}:${DOCKER_GROUP} with uid: ${DOCKER_UID}, gid: ${DOCKER_GID}"

GREP_GROUP_REGEXP="\w+:x?:${DOCKER_GID}:"
GREP_GROUP=$( grep -E ${GREP_GROUP_REGEXP} /etc/group )

if [[ -z "${GREP_GROUP}" ]]
then
  addgroup -g ${DOCKER_GID} ${DOCKER_USER}
else
  SED_GROUP_REGEXP="s|\w+:(x?):${DOCKER_GID}:(.*)|${DOCKER_GROUP}:\1:${DOCKER_GID}:${DOCKER_USER},\2|g"

  BUFFER=$( cat /etc/group | sed -E ${SED_GROUP_REGEXP} )
  echo -e "${BUFFER}" > /etc/group
fi

GREP_USER_REGEXP="\w+:x?:${DOCKER_UID}:"
GREP_USER=$( grep -E ${GREP_USER_REGEXP} /etc/passwd )

if [[ -z "${GREP_USER}" ]]
then
  adduser -u ${DOCKER_UID} -G ${DOCKER_GROUP} -D -s /bin/bash ${DOCKER_USER}
else
  PREV_USER=$( echo ${GREP_USER} | cut -d ':' -f1 )
  SED_USER_REGEXP="s|\w+:(x?):${DOCKER_UID}:(.*)/home/\w+|${DOCKER_USER}:\1:${DOCKER_UID}:\2/home/${DOCKER_USER}|g"

  BUFFER=$( cat /etc/passwd | sed -E ${SED_USER_REGEXP} )
  echo -e "${BUFFER}" > /etc/passwd

  mv /home/${PREV_USER} /home/${DOCKER_USER}
fi

if [[ -n "{APP_ROOT}" ]]
then
  sudo -u ${DOCKER_USER} -i echo "cd ${APP_ROOT}" >> /home/${DOCKER_USER}/.bash_profile
fi


# -- Various system fixes
cat /etc/passwd | sed -E 's|/bin/[a]?sh|/bin/bash|g' | tee /etc/passwd > /dev/null

echo '[[ `id -u` -ge 1000 || `id -un` == '${DOCKER_USER}' ]] && umask 0002' > /etc/profile.d/regular_user_umask.sh

echo "%${DOCKER_GROUP} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/regular_user_group

echo -e "#!/bin/bash \n sudo su ${DOCKER_USER} -l" > ${SUDOCK_PATH} && chmod +x ${SUDOCK_PATH}
