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
  if [ -z "$END_IP" ]; then
    read -p "Enter end IP for record: " END_IP
    if [ -z "$END_IP" ]; then
      _err "No end IP found for record."
      return 1
    fi
    echo 'export END_IP="'$END_IP'"' >> ~/.bashrc
  fi

  if [ -z "$CLIENT_API_KEY" ]; then
    read -p "Enter client API key: " CLIENT_API_KEY
    if [ -z "$CLIENT_API_KEY" ]; then
      _err "Invalid API key."
      return 1
    fi
    echo 'export CLIENT_API_KEY="'$CLIENT_API_KEY'"' >> ~/.bashrc
  fi
}

_get_root() {
  txtdomain=$fulldomain
  domain=$(echo "$txtdomain" | cut -d'.' -f2-)
  if [ -z "$domain" ] || [ -z "$txtdomain" ]; then
    _err "We weren't able to determine the records which need to be created."
    return 1
  fi
  _debug "Domain: ${domain}       TXTDomain: ${txtdomain}"

  _domhost="${domain}"
  _txthost="${txtdomain}"
  _debug "Domain: ${domain} found."
  return 0
}

_voidssystems_rest() {
  mode=$1
  request="$2"
  data="$3"

  export _H1="Content-Type: application/json"
  export _H2="x-api-key: ${CLIENT_API_KEY}"

  if [ "$mode" != "GET" ]; then
    _debug data "$data"
    response="$(_post "$data" "$API/$request" "" "$mode")"
  else
    response="$(_get "$API/$request")"
  fi

  if [ "$?" != "0" ]; then
    _err "error $request"
    return 1
  fi
  _debug2 response "$response"
  return 0
}

_check_record() {
  server_record="?type=A&hostname=$_domhost"
  txt_record="?type=TXT&hostname=$_txthost"

  _debug "API ENDPOINTS ${server_record} ${txt_record} WITH HEADER ${apiH2}"

  response="$(_voidssystems_rest GET "$server_record")"
  if [ "$?" != "0" ]; then
    _err "error. failed access to end point"
    return 1
  fi

  if _contains "$response" '{"exists":"true"}'; then
    _err "Record already exists."
    return 1
  fi

  response="$(_voidssystems_rest GET "$txt_record")"
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

  domain_data="{\"type\":\"A\", \"hostname\":\"${_domhost}\", \"target\":\"${END_IP}\"}"
  txt_data="{\"type\":\"TXT\", \"hostname\":\"${_txthost}\", \"target\":\"${txtvalue}\"}"

  _debug "API ENDPOINTS ${API} WITH HEADER ${apiH2} AND DATA ${domain_data} AND ${txt_data}"

  response="$(_voidssystems_rest POST "" "$domain_data")"
  if [ "$?" != "0" ]; then
    _err "error"
    return 1
  fi

  response="$(_voidssystems_rest POST "" "$txt_data")"
  if [ "$?" != "0" ]; then
    _err "error"
    return 1
  fi

  return 0
}

_remove_record() {
  domain_data="{\"type\":\"A\", \"hostname\":\"${_domhost}\"}"
  txt_data="{\"type\":\"TXT\", \"hostname\":\"${_txthost}\"}"

  _debug "API ENDPOINTS ${API} WITH HEADER ${apiH2} AND DATA ${domain_data} AND ${txt_data}"

  response="$(_voidssystems_rest DELETE "" "$domain_data")"
  if [ "$?" != "0" ]; then
    _err "error"
    return 1
  fi

  response="$(_voidssystems_rest DELETE "" "$txt_data")"
  if [ "$?" != "0" ]; then
    _err "error"
    return 1
  fi

  return 0
}
