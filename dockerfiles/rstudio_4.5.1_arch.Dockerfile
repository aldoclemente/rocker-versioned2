FROM archlinux:latest AS base

ENV S6_OVERLAY_VERSION 2.1.0.2
ENV S6_OVERLAY_MD5HASH 7e81e28fcb4d882d2fbc6c7f671758e2

COPY s6-archlinux-docker/container-files /

RUN pacman --noconfirm -Syu && \
pacman --noconfirm -S wget tar && \
rm -rf /usr/share/man/* /var/cache/pacman/pkg/* /var/lib/pacman/sync/* /etc/pacman.d/mirrorlist.pacnew && \
cd /tmp && \
wget https://github.com/just-containers/s6-overlay/releases/download/v$S6_OVERLAY_VERSION/s6-overlay-amd64.tar.gz && \
echo "$S6_OVERLAY_MD5HASH *s6-overlay-amd64.tar.gz" | md5sum -c - && \
tar xzf s6-overlay-amd64.tar.gz -C / && \
rm s6-overlay-amd64.tar.gz && \
sh /usr/local/sbin/fix-bins.sh

RUN pacman-key --init
RUN pacman --noconfirm -Sy archlinux-keyring
RUN pacman --noconfirm -Sy gcc
RUN pacman --noconfirm -Sy clang
RUN pacman --noconfirm -Syu icu
RUN pacman --noconfirm -Sy make
RUN pacman --noconfirm -Sy cmake
RUN pacman --noconfirm -Sy git
RUN pacman --noconfirm -Sy libxml2
RUN pacman --noconfirm -Sy freetype2
RUN pacman --noconfirm -Sy harfbuzz
RUN pacman --noconfirm -Sy fribidi
RUN pacman --noconfirm -Sy libtiff
RUN pacman --noconfirm -Sy eigen
RUN pacman --noconfirm -Sy python3
RUN pacman --noconfirm -Sy r-base
RUN pacman --noconfirm -Sy nano
RUN pacman --noconfirm -Sy gtest
RUN pacman --noconfirm -Sy valgrind
RUN pacman --noconfirm -Sy openmpi
RUN pacman --noconfirm -Sy ttf-dejavu ttf-liberation
RUN pacman --noconfirm -Sy heaptrack
RUN cd /usr/include && git clone https://github.com/yixuan/LBFGSpp.git

RUN pacman --noconfirm -Sy pkgconf
RUN pacman --noconfirm -Sy libxml2
RUN cd && echo "install.packages(c('Rcpp', 'RcppEigen', 'R6', 'devtools'), repos='https://cran.stat.unipd.it/')" > tmp.R
RUN cd && Rscript tmp.R
RUN cd && rm tmp.R

FROM base AS rstudio

ENV R_VERSION 4.5.1
ENV R_HOME /usr/lib/R
ENV TZ="Etc/UTC"

# INSTALLING PARU
RUN pacman --noconfirm -Sy --needed base-devel
RUN useradd -m user && echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN cd /home/user &&  sudo -u user git clone https://aur.archlinux.org/paru.git
RUN cd /home/user/paru/ && sudo -u user makepkg -si --noconfirm

# Installing Rstudio Server on archlinux
RUN sudo -u user paru -Sy --noconfirm rstudio-server-bin


ENV CRAN="https://p3m.dev/cran/__linux__/noble/latest"
#ENV LANG=en_US.UTF-8

COPY scripts/bin/ /rocker_scripts/bin/
#COPY scripts/setup_R.sh /rocker_scripts/setup_R.sh

ENV RSTUDIO_VERSION="2025.05.1+513"
ENV DEFAULT_USER="user"
RUN pacman --noconfirm -Sy systemd
COPY scripts/install_rstudio_arch.sh /rocker_scripts/install_rstudio_arch.sh
COPY scripts/install_s6init.sh /rocker_scripts/install_s6init.sh
COPY scripts/default_user.sh /rocker_scripts/default_user.sh
COPY scripts/init_set_env_arch.sh /rocker_scripts/init_set_env.sh
COPY scripts/init_userconf.sh /rocker_scripts/init_userconf.sh
COPY scripts/pam-helper.sh /rocker_scripts/pam-helper.sh
RUN /rocker_scripts/install_rstudio_arch.sh

EXPOSE 8787
ENTRYPOINT ["/init"]

#COPY scripts/install_pandoc.sh /rocker_scripts/install_pandoc.sh
#RUN /rocker_scripts/install_pandoc.sh
#RUN sudo -u user paru -Sy --noconfirm pandoc-bin
#RUN sudo -u user paru -Sy --noconfirm quarto-cli
#COPY scripts/install_quarto.sh /rocker_scripts/install_quarto.sh
#RUN /rocker_scripts/install_quarto.sh
RUN pacman --noconfirm -Sy gdal
RUN pacman --noconfirm -Sy proj
RUN pacman --noconfirm -Sy geos
RUN pacman --noconfirm -Sy arrow
RUN pacman --noconfirm -Sy podofo
RUN sudo -u user paru -Sy --noconfirm udunits
RUN sudo -u user paru -Sy --noconfirm gcc-fortran
COPY scripts /rocker_scripts
RUN cd && echo "install.packages(c('RTriangle', 'raster', 'viridis', 'ggplot2'), repos='https://cran.stat.unipd.it/')" > tmp.R
RUN cd && Rscript tmp.R
RUN cd && echo "install.packages(c('sf','mapview'), repos='https://cran.stat.unipd.it/')" > tmp.R
RUN cd && Rscript tmp.R
#RUN sudo -u user paru -Sy v8-r
#RUN cd /home/user/ && sudo -u user paru -G v8-r  
#RUN cd /home/user/v8-r && sudo -u user makepkg --noconfirm -si
#RUN cd && echo "install.packages('V8', repos='https://cran.stat.unipd.it/')" > tmp.R
#RUN cd && Rscript tmp.R
#RUN cd && echo "install.packages('rmapshaper', repos='https://cran.stat.unipd.it/')" > tmp.R
#RUN cd && Rscript tmp.R
#RUN cd && echo "install.packages('tigris', repos='https://cran.stat.unipd.it/')" > tmp.R
#RUN cd && Rscript tmp.R

RUN cd && echo "install.packages(c('leafsync', 'latex2exp', 'ggmap'), repos='https://cran.stat.unipd.it/')" > tmp.R
RUN cd && Rscript tmp.R
RUN cd && rm tmp.R

RUN cd && echo "install.packages(c('patchwork'), repos='https://cran.stat.unipd.it/')" > tmp.R
RUN cd && Rscript tmp.R
RUN cd && rm tmp.R

FROM rstudio AS package
RUN cd /home/user/ && git clone --recursive https://github.com/fdaPDE/fdaPDE-R
RUN cd /home/user/ && R CMD build fdaPDE-R
RUN cd /home/user/ && R CMD INSTALL fdaPDE2_2.0-0.tar.gz
RUN cd /home/user/ && rm fdaPDE2_2.0-0.tar.gz

