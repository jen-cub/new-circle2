#!/usr/bin/env bash
set -eu

MSG_TYPE="${TYPE:-Job} Successful: ${CIRCLE_PROJECT_REPONAME}" \
MSG_TITLE="${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME} @ ${CIRCLE_BRANCH:-${CIRCLE_TAG}}" \
MSG_LINK="${CIRCLE_BUILD_URL}" \
MSG_TEXT="${CIRCLE_JOB}\nBuild #${CIRCLE_BUILD_NUM}\nRef: ${CIRCLE_BRANCH:-${CIRCLE_TAG}}\n:Commit: ${CIRCLE_SHA1}" \
MSG_COLOUR="lightgreen" \
${HOME}/scripts/notify-rocketchat.sh
