[![Build Status](https://github.com/tracyhatemice/tor-docker/actions/workflows/image.yaml/badge.svg)](https://github.com/tracyhatemice/tor-docker/actions/workflows/image.yaml)

# Tor and Privoxy

Tor and Privoxy (web proxy configured to route through tor) docker container,
supervised by `s6-overlay`.

# What is Tor?

Tor is free software and an open network that helps you defend against traffic
analysis, a form of network surveillance that threatens personal freedom and
privacy, confidential business activities and relationships, and state security.

# What is Privoxy?

Privoxy is a non-caching web proxy with advanced filtering capabilities for
enhancing privacy, modifying web page data and HTTP headers, controlling access,
and removing ads and other obnoxious Internet junk.

---

# How to use this image

**NOTE**: this image is setup by default to be a relay only (not an exit node)

## Exposing the port

    sudo docker run -it -p 8118:8118 -p 9050:9050 -d ghcr.io/tracyhatemice/tor:latest

**NOTE**: it will take a while for tor to bootstrap...

Then you can hit privoxy web proxy at `hostname:8118` with your browser or
tor via the socks protocol directly at `hostname:9050`.


## Configuration

This image starts through `s6-overlay` (`/init`) and keeps `tor` and
`privoxy` as independent supervised services.

Configuration is made possible via `torproxy.sh` script, and is environment-variable based (`BW`, `EXITNODE`, `LOCATION`,
`PASSWORD`, `SERVICE`, `NEWNYM`, `USERID`, `GROUPID`, and `TOR_*`).

ENVIRONMENT VARIABLES

 * `TORUSER` - If set use named user instead of 'tor' (for example root)
 * `BW` - As above, set a tor relay bandwidth limit in KB, IE `50`
 * `EXITNODE` - As above, allow tor traffic to access the internet from your IP
 * `LOCATION` - As above, configure the country to use for exit node selection
 * `PASSWORD` - As above, configure HashedControlPassword for control port
 * `SERVICE` - As above, configure hidden service, IE '80;hostname:80'
 * `NEWNYM` - Generate new circuits now (only when tor is already running)
 * `TZ` - Configure the zoneinfo timezone, IE `EST5EDT`
 * `USERID` - Set the UID for the app user
 * `GROUPID` - Set the GID for the app user

Other environment variables beginning with `TOR_` will edit the configuration
file accordingly:

 * `TOR_NewCircuitPeriod=400` will translate to `NewCircuitPeriod 400`

## Examples

For startup-time configuration with `s6-overlay`, prefer environment variables.

### Setting the Timezone

    sudo docker run -it -p 8118:8118 -p 9050:9050 -e TZ=EST5EDT \
                -d ghcr.io/tracyhatemice/tor:latest

### Start torproxy setting the allowed bandwidth:

    sudo docker run -it -p 8118:8118 -p 9050:9050 -e BW=100 -d ghcr.io/tracyhatemice/tor:latest

### Start torproxy configuring it to be an exit node:

    sudo docker run -it -p 8118:8118 -p 9050:9050 -e EXITNODE=1 \
                -d ghcr.io/tracyhatemice/tor:latest

## Test the proxy:

    curl -Lx http://<ipv4_address>:8118 http://jsonip.com/

---

If you wish to adapt the default configuration, use something like the following
to copy it from a running container:

    sudo docker cp torproxy:/etc/tor/torrc /some/torrc

Then mount it to a new container like:

    sudo docker run -it -p 8118:8118 -p 9050:9050 \
                -v /some/torrc:/etc/tor/torrc:ro -d ghcr.io/tracyhatemice/tor:latest

# User Feedback

## Issues

### tor failures (exits or won't connect)

If you are affected by this issue (a small percentage of users are) please try
setting the TORUSER environment variable to root, IE:

    sudo docker run -it -p 8118:8118 -p 9050:9050 -e TORUSER=root -d \
                ghcr.io/tracyhatemice/tor:latest

### Reporting

If you have any problems with or questions about this image, please contact me
through a GitHub issue.

# Credit

torproxy was originally created by [dperson](https://github.com/dperson/torproxy).
