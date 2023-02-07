#!/usr/bin/env sh

# VoidsSystems Customer Domain amce Helper
# This script is intended to be run via
# acme.sh on managed customer systems
# to allow customers to create and renew
# SSL certificates on their client
# subdomain e.g (client.voids.systems)
# without the need for support staff
# to create TXT records.

# API Calls to be made
# GET https://api.voids.systems/api/dns?type=TYPE&hostname=hostname -H "x-api-key: KEY"
# POST https://api.voids.systems/api/dns -H "x-api-key: KEY" -d '{"type":"TYPE", "hostname":"HOSTNAME", "target":"IP/TXT"}'
# DELETE https://api.voids.systems/api/dns -H "x-api-key: KEY" -d '{"type":"TYPE", "hostname":"HOSTNAME", ("target":"IP/TXT")}'

API="https://api.voids.systems/api/dns"

dns_voidssystems_add() {
  fulldomain=$1
  txtvalue=$2

  _check_config

  _info "Using voidssystems-register to add the TXT record"
  _get_root
  _create_record
  _debug fulldomain "$fulldomain"
  _debug txtvalue "$txtvalue"
}

dns_voidssystems_rm() {
  fulldomain=$1
  txtvalue=$2

  _check_config

  _info "Using voidssystems-clean to remove the TXT record"
  _get_root
  _remove_record
  _debug fulldomain "$fulldomain"
  _debug txtvalue "$txtvalue"
}

####################  Private functions below ##################################

_check_config() {
  if command -v python &>/dev/null; then
    source <(python ../config.py)
  else
    _err "Python is not installed. Please install it to use this script."
    exit 1
  fi

  if [ -z "$END_IP" ]; then
    _err "You need to specify an end IP in the config.ini file."
    return 1
  fi
  _saveaccountconf_mutable END_IP "$END_IP"

  if [ -z "$CLIENT_API_KEY" ]; then
    _err "You need to specify a client API Key in the config.ini file."
    return 1
  fi
  _saveaccountconf_mutable CLIENT_API_KEY "$CLIENT_API_KEY"
}

_get_root() {
  domain=$fulldomain
  subdomain=${domain%.voids.systems}
  txtdomain="_acme-challenge.${domain}"

  if [ -z "$domain" ] || [ -z "$subdomain" ] || [ -z "$txtdomain" ]; then
    _err "We weren't able to determine the records which need to be created."
    return 1
  fi

  _debug "Domain: ${domain}       TXTDomain: ${subdomain}     Subdomain: ${txtdomain}"

  _domhost="${domain}"
  _txthost="${txtdomain}"
  _subhost="${subdomain}"
  _debug "Domain: ${domain} found."
  return 0
}

_check_record() {
  server_record="${API}?type=A&hostname=$_domhost"
  txt_record="${API}?type=TXT&hostname=$_txthost"

  header="x-api-key: ${CLIENT_API_KEY}"

  _debug "API ENDPOINTS ${server_record} ${txt_record} WITH HEADER ${header}"

  response="$(_get "$server_record" "$header")"
  if [ "$?" != "0" ]; then
    _err "error. failed access to end point"
    return 1
  fi

  if _contains "$response" '{"exists":"true"}'; then
    _err "Record already exists."
    return 1
  fi

  response="$(_get "$txt_record" "$header")"
  if [ "$?" != "0" ]; then
    _err "error. failed access to end point"
    return 1
  fi

  if _contains "$response" '{"exists":"true"}'; then
    _err "Record already exists."
    return 1
  fi
}

_create_record() {
  _check_record
  header="x-api-key: ${CLIENT_API_KEY}"

  domain_data='{"type":"A", "hostname":"${_domhost}", "target":"${END_IP}"}'
  txt_data='{"type":"TXT", "hostname":"${_txthost}", "target":"${txtvalue}"}'

  _debug "API ENDPOINTS ${api} WITH HEADER ${header} AND DATA "

  response="$(_post "$API" "$header" "$domain_data")"
  if [ "$?" != "0" ]; then
    _err "error"
    return 1
  fi

  response="$(_post "$api" "$header" "$txt_data")"
  if [ "$?" != "0" ]; then
    _err "error"
    return 1
  fi

  return 0
}

_remove_record() {
  server_record="https://api.corp-jamo.tech/dns/v1/records/remove.php?access=$JTECH_KEY&hostname=$_subhost&target=$JTECH_ENDIP&type=A"
  txt_record="https://api.corp-jamo.tech/dns/v1/records/remove.php?access=$JTECH_KEY&hostname=$_txthost&target=$txtvalue&type=TXT"
  _debug "API ENDPOINTS $server_record $txt_record"

  response="$(_get "$server_record")"
  if [ "$?" != "0" ]; then
    _err "error"
    return 1
  fi

  response="$(_get "$txt_record")"
  if [ "$?" != "0" ]; then
    _err "error"
    return 1
  fi

  return 0
}
