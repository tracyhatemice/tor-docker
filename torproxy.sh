#!/usr/bin/env bash
#===============================================================================
#          FILE: torproxy.sh
#
#         USAGE: ./torproxy.sh
#
#   DESCRIPTION: Configuration helper for torproxy docker container
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: David Personette (dperson@gmail.com),
#  ORGANIZATION:
#       CREATED: 09/28/2014 12:11
#      REVISION: 1.0
#===============================================================================

set -o nounset                              # Treat unset variables as an error
set -o errexit                              # Exit on error
set -o pipefail                             # Exit on pipe failure

### bandwidth: set the BW available for relaying
# Env:
#   KiB/s) KiB/s of data that can be relayed
# Return: Updated configuration file
bandwidth() { local kbs="${1:-10}" file=/etc/tor/torrc
    sed -i '/^RelayBandwidth/d' "$file"
    echo "RelayBandwidthRate $kbs KB" >>"$file"
    echo "RelayBandwidthBurst $(( kbs * 2 )) KB" >>"$file"
}

### exitnode: Allow exit traffic
# Env:
#   N/A)
# Return: Updated configuration file
exitnode() { local file=/etc/tor/torrc
    sed -i '/^ExitPolicy/d' "$file"
}

### exitnode_country: Only allow traffic to exit in a specified country
# Env:
#   LOCATION: country where we want to exit
# Return: Updated configuration file
exitnode_country() { local country="$1" file=/etc/tor/torrc
    sed -i '/^StrictNodes/d; /^ExitNodes/d' "$file"
    echo "StrictNodes 1" >>"$file"
    echo "ExitNodes {$country}" >>"$file"
}

### hidden_service: setup a hidden service
# Env:
#   SERVICE: hidden service configuration in the format '<port>;<host:port>'
# Return: Updated configuration file
hidden_service() { local port="$1" host="$2" file=/etc/tor/torrc
    sed -i '/^HiddenServicePort '"$port"' /d' "$file"
    grep -q '^HiddenServiceDir' "$file" ||
        echo "HiddenServiceDir /var/lib/tor/hidden_service" >>"$file"
    echo "HiddenServicePort $port $host" >>"$file"
}

### newnym: setup new circuits
# Env:
#   N/A)
# Return: New circuits for tor connections
newnym() { local file=/etc/tor/run/control.authcookie
    echo -e 'AUTHENTICATE "'"$(cat "$file")"'"\nSIGNAL NEWNYM\nQUIT' |
                nc 127.0.0.1 9051
    if ps -ef | grep -Ev 'grep|torproxy.sh' | grep -q tor; then return 0; fi
}

### password: setup a hashed password
# Env:
#   PASSWORD: passwd to set
# Return: Updated configuration file
password() { local passwd="$1" file=/etc/tor/torrc hash
    sed -i '/^HashedControlPassword/d' "$file"
    sed -i '/^ControlPort/s/ 9051/ [::]]:9051/' "$file"
    hash=$(su - tor -s /bin/bash -c "tor --hash-password \"\$1\" 2>/dev/null | tail -n 1" -- - "$passwd")
    echo "HashedControlPassword $hash" >>"$file"
}

### usage: Help
# Env:
#   none)
# Return: Help text
usage() { local RC="${1:-0}"
    echo "Usage: ${0##*/} [command]

Configuration is environment-variable based:
    BW          Configure tor relaying bandwidth in KB/s
    EXITNODE    Allow this to be an exit node for tor traffic
    LOCATION    Configure tor to only use exit nodes in specified country
    PASSWORD    Configure tor HashedControlPassword for control port
    SERVICE     Configure tor hidden service as '<port>;<host:port>'
    NEWNYM      Generate new circuits now (only when tor is already running)
    USERID      Set the UID for the tor user
    GROUPID     Set the GID for the tor user

Other variables beginning with TOR_ map to torrc keys.
The 'command' (if provided and valid) will be run instead of torproxy.
" >&2
    exit $RC
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [[ "${1:-}" == -* ]]; then
    echo "ERROR: CLI config flags were removed; use environment variables instead."
    usage 2
fi

[[ "${BW:-""}" ]] && bandwidth "$BW"
[[ "${EXITNODE:-""}" ]] && exitnode
[[ "${LOCATION:-""}" ]] && exitnode_country "$LOCATION"
[[ "${PASSWORD:-""}" ]] && password "$PASSWORD"
[[ "${SERVICE:-""}" ]] && { IFS=';' read -r port host <<< "$SERVICE"; hidden_service "$port" "$host"; }
[[ "${USERID:-""}" =~ ^[0-9]+$ ]] && usermod -u "$USERID" -o tor
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]] && groupmod -g "$GROUPID" -o tor
while IFS='=' read -r raw_name raw_val; do
    name="${raw_name#TOR_}"
    val="\"$raw_val\""
    [[ "$name" =~ _ ]] && continue
    [[ "$val" =~ ^\"([0-9]+|false|true)\"$ ]] && val="$(sed 's|"||g' <<< "$val")"
    if grep -q "^$name" /etc/tor/torrc; then
        sed -i "/^$name/s| .*| $val|" /etc/tor/torrc
    else
        echo "$name $val" >>/etc/tor/torrc
    fi
done < <(printenv | grep '^TOR_')

chown -Rh tor /etc/tor /var/lib/tor /var/log/tor 2>&1 |
            grep -iv 'Read-only' || :
