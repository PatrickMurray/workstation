#! /usr/bin/env bash


# VARIABLES


GITHUB_USERNAME="patrickmurray"
GITHUB_REPOSITORY="workstation"
GITHUB_BRANCH="master"

GITHUB_ARCHIVE_URL="https://www.github.com/${GITHUB_USERNAME}/${GITHUB_REPOSITORY}/archive/${GITHUB_BRANCH}.zip";

ANSIBLE_REQUIREMENTS_FILENAME="requirements.yml";
ANSIBLE_PLAYBOOK_FILENAME="main.yml";


# INITIALIZE


if [[ "${EUID}" -ne 0 ]];
then
  echo "Script must be run as root user"
  exit -1;
fi


TEMP_DIRECTORY=$(mktemp --directory --suffix "_${GITHUB_USERNAME}_${GITHUB_REPOSITORY}_${GITHUB_BRANCH}");

if [[ "${?}" -ne 0 ]];
then
  echo "An error occurred while initializing the temporary directory";
  exit -1;
fi


cd "${TEMP_DIRECTORY}";

if [[ "${?}" -ne 0 ]];
then
  echo "An error occurred while changing to the temporary directory";
  exit -1;
fi


# INSTALL ANSIBLE


dnf install -y ansible-core;

if [[ "${?}" -ne 0 ]];
then
  echo "An error occurred while attempting to install ansible";
  exit -1;
fi


# DOWNLOAD ANSIBLE PLAYBOOK


wget "${GITHUB_ARCHIVE_URL}";

if [[ "${?}" -ne 0 ]];
then
  echo "An error occurred while attempting to download ansible playbook";
  exit -1;
fi


unzip "${GITHUB_BRANCH}.zip";

if [[ "${?}" -ne 0 ]];
then
  echo "An error occurred while extracting the archive"
  exit -1;
fi


cd "${GITHUB_REPOSITORY}-${GITHUB_BRANCH}";

if [[ "${?}" -ne 0 ]];
then
  echo "An error occurred while changing to the repository directory";
  exit -1;
fi


# INSTALL ANSIBLE DEPENDENCIES


ansible-galaxy install --role-file "${ANSIBLE_REQUIREMENTS_FILENAME}";

if [[ "${?}" -ne 0 ]];
then
  echo "An error occurred while installing ansible dependencies";
  exit -1;
fi


ansible-playbook "${ANSIBLE_PLAYBOOK_FILENAME}";

if [[ "${?}" -ne 0 ]];
then
  echo "An error occurred while running ansible playbook";
  exit -1;
fi

