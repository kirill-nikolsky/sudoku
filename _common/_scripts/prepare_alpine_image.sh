#!/bin/sh

SUDOCK_PATH="/usr/sbin/sudock"

INSTALL_PACKAGES="bash curl git mc nano shadow sudo unzip vim"

[[ -n "${APK_ADD_EXTRA_PACKAGES}" ]] && INSTALL_PACKAGES="${INSTALL_PACKAGES} ${APK_ADD_EXTRA_PACKAGES}"
[[ -z "${DOCKER_USER}" ]] && DOCKER_USER="docker"
[[ -z "${DOCKER_GROUP}" ]] && DOCKER_GROUP="docker"

apk update && apk upgrade && apk add --no-cache ${INSTALL_PACKAGES}

# -- Ensure regular user and group

[ -d /var/mail ] || mkdir /var/mail

echo "Add/move ${DOCKER_USER}:${DOCKER_GROUP} with uid: ${DOCKER_UID}, gid: ${DOCKER_GID}"

GREP_GROUP_REGEXP="\w+:x?:${DOCKER_GID}:"
GREP_GROUP=$( grep -E ${GREP_GROUP_REGEXP} /etc/group )

if [[ -z "${GREP_GROUP}" ]]
then
  groupadd -g ${DOCKER_GID} ${DOCKER_GROUP}
else
  PREV_GROUP_NAME=$( echo ${GREP_GROUP} | cut -d ":" -f1 )

  groupmod -n ${DOCKER_GROUP} ${PREV_GROUP_NAME}
fi

GREP_USER_REGEXP="\w+:x?:${DOCKER_UID}:"
GREP_USER=$( grep -E ${GREP_USER_REGEXP} /etc/passwd )

if [[ -z "${GREP_USER}" ]]
then
  useradd -g ${DOCKER_GROUP} -u ${DOCKER_UID} -m -s /bin/bash ${DOCKER_USER}
else
  PREV_USER_NAME=$( echo ${GREP_USER} | cut -d ':' -f1 )

  usermod -l ${DOCKER_USER} -g ${DOCKER_GROUP} -m -d /home/${DOCKER_USER} -s /bin/bash ${PREV_USER_NAME}
fi

if [[ -n "{APP_ROOT}" ]]
then
  sudo -u ${DOCKER_USER} -i echo "cd ${APP_ROOT}" >> /home/${DOCKER_USER}/.bash_profile
fi


# -- Various system fixes
cat /etc/passwd | sed -i -E 's|/bin/[a]?sh|/bin/bash|g' /etc/passwd

echo '[[ `id -u` -ge 1000 || `id -un` == '${DOCKER_USER}' ]] && umask 0002' > /etc/profile.d/regular_user_umask.sh

echo "%${DOCKER_GROUP} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/regular_user_group

echo -e "#!/bin/bash \n sudo su ${DOCKER_USER} -l" > ${SUDOCK_PATH} && chmod +x ${SUDOCK_PATH}
