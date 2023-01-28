FROM debian:bullseye

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8
ENV APT_LISTCHANGES_FRONTEND non

RUN apt-get update
RUN apt-get install --yes gnupg wget
RUN wget -O "/etc/apt/trusted.gpg.d/openmediavault-archive-keyring.asc" https://packages.openmediavault.org/public/archive.key
RUN apt-key add "/etc/apt/trusted.gpg.d/openmediavault-archive-keyring.asc"

RUN echo "deb https://packages.openmediavault.org/public shaitan main" >> /etc/apt/sources.list.d/openmediavault.list

RUN apt-get update
RUN apt-get --yes --auto-remove --show-upgraded \
    --allow-downgrades --allow-change-held-packages \
    --no-install-recommends \
    --option DPkg::Options::="--force-confdef" \
    --option DPkg::Options::="--force-confold" \
    install openmediavault-keyring openmediavault

RUN omv-salt stage run all || true

COPY omv-run.sh /usr/sbin/omv-run.sh
RUN chmod +x /usr/sbin/omv-run.sh

EXPOSE 80

VOLUME /data

ENTRYPOINT /usr/sbin/omv-run.sh