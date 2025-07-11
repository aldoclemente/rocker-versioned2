#!/bin/bash

## Download and install RStudio server & dependencies uses.
##
## In order of preference, first argument of the script, the RSTUDIO_VERSION variable.
## ex. stable, preview, daily, 1.3.959, 2021.09.1+372, 2021.09.1-372, 2022.06.0-daily+11

set -e

RSTUDIO_VERSION=${1:-${RSTUDIO_VERSION:-"stable"}}
DEFAULT_USER="user" #${DEFAULT_USER:-"rstudio"}
# shellcheck source=/dev/null
source /etc/os-release
   
#ln -fs /usr/lib/rstudio-server/bin/rstudio-server /usr/local/bin
#ln -fs /usr/lib/rstudio-server/bin/rserver /usr/local/bin

# https://github.com/rocker-org/rocker-versioned2/issues/137
rm -f /var/lib/rstudio-server/secure-cookie-key

## RStudio wants an /etc/R, will populate from $R_HOME/etc
mkdir -p /etc/R

## Make RStudio compatible with case when R is built from source
## (and thus is at /usr/local/bin/R), because RStudio doesn't obey
## path if a user apt-get installs a package
R_BIN="$(which R)"
echo "rsession-which-r=${R_BIN}" >/etc/rstudio/rserver.conf
## use more robust file locking to avoid errors when using shared volumes:
echo "lock-type=advisory" >/etc/rstudio/file-locks

## Prepare optional configuration file to disable authentication
## To de-activate authentication, `disable_auth_rserver.conf` script
## will just need to be overwrite /etc/rstudio/rserver.conf.
## This is triggered by an env var in the user config
cp /etc/rstudio/rserver.conf /etc/rstudio/disable_auth_rserver.conf
echo "auth-none=1" >>/etc/rstudio/disable_auth_rserver.conf

## Set up RStudio init scripts
mkdir /usr/share/doc/ && mkdir /usr/share/doc/R
mkdir -p /etc/services.d/rstudio
cat <<"EOF" >/etc/services.d/rstudio/run
#!/usr/bin/with-contenv bash
## load /etc/environment vars first:
##for line in $( cat /etc/environment ) ; do export $line > /dev/null; done
echo --- starting R server ---
exec /usr/lib/rstudio-server/bin/rserver --server-daemonize 0
EOF
chmod +x /etc/services.d/rstudio/run
cat <<EOF >/etc/services.d/rstudio/finish
#!/bin/bash
/usr/lib/rstudio-server/bin/rstudio-server stop
EOF
chmod +x /etc/services.d/rstudio/finish
# If CUDA enabled, make sure RStudio knows (config_cuda_R.sh handles this anyway)
if [ -n "$CUDA_HOME" ]; then
    sed -i '/^rsession-ld-library-path/d' /etc/rstudio/rserver.conf
    echo "rsession-ld-library-path=$LD_LIBRARY_PATH" >>/etc/rstudio/rserver.conf
fi

# Log to stderr
cat <<EOF >/etc/rstudio/logging.conf
[*]
log-level=warn
logger-type=syslog
EOF

# set up default user
#/rocker_scripts/default_user.sh "${DEFAULT_USER}"

## Rocker's default RStudio settings, for better reproducibility
mkdir -p "/home/${DEFAULT_USER}/.config/rstudio/"
cat <<EOF >"/home/${DEFAULT_USER}/.config/rstudio/rstudio-prefs.json"
{
    "save_workspace": "never",
    "always_save_history": false,
    "reuse_sessions_for_project_links": true,
    "posix_terminal_shell": "bash"
}
EOF
chown -R "${DEFAULT_USER}:${DEFAULT_USER}" "/home/${DEFAULT_USER}"
# install user config initiation script
mkdir -p /etc/cont-init.d
cp /rocker_scripts/init_set_env.sh /etc/cont-init.d/01_set_env
cp /rocker_scripts/init_userconf.sh /etc/cont-init.d/02_userconf
cp /rocker_scripts/pam-helper.sh /usr/lib/rstudio-server/bin/pam-helper

# Clean up
#rm -rf /var/lib/apt/lists/*

# Check the RStudio Server
echo -e "Check the RStudio Server version...\n"

rstudio-server version

echo -e "\nInstall RStudio Server, done!"
