#!/usr/bin/env sh

# This is informal acme.sh DNS API plugin for Crazy Domain DNS provider.
# It have been successfully tested under Debian & Ubuntu systems but as it's informal 
# use it on your own risk.
# 
# Requires curl and jq
# Author: Irek Pelech
# https://seniorlinuxadmin.co.uk


####################  Private functions below ##################################

init() {
  ## Get PHPSESSID & Ajax Token
  REQ_DATA=$(curl -s -c - https://www.crazydomains.co.uk/members/login/ | egrep "csrf-token|PHPSESSID")
  PHPSESSID=$(echo "${REQ_DATA}"|awk '/PHPSESSID/ { print $(NF) }')
  AJAX_TOKEN=$(echo "${REQ_DATA}"|grep 'csrf-token'|cut -d '"' -f4)

  # Login details
  CR_USERNAME="Crazy Domain Username"
  CR_PASSWORD="Crazy Domain Password"

  # Variables
  DNS_ACME_RECORD='_acme-challenge'
  DOMAIN_NAME=$(echo "$1"|cut -d . -f2-)
  SUCCESS='DNS updated successfully'
  ACME_RECORDS_COUNT=0
}

login() {
  LOGIN_STAT=$(curl -s 'https://www.crazydomains.co.uk/members/ajax/member/member-login/' \
    --cookie "PHPSESSID=${PHPSESSID}" \
    -H 'Content-type: application/x-www-form-urlencoded; charset=UTF-8' \
    -H 'Origin: https://www.crazydomains.co.uk' \
    -H 'Referer: https://www.crazydomains.co.uk/members/login/' \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36' \
    --data-raw "ajax_token=${AJAX_TOKEN}&token=true&member_username=${CR_USERNAME}&member_password=${CR_PASSWORD}" \
    --compressed) 
}

get_domain_id() {
  DOMAIN_ID=$(curl -s "https://www.crazydomains.co.uk/members/ajax/dashboard/domain?limit=10&ajax_token=${AJAX_TOKEN}" \
    --cookie "PHPSESSID=${PHPSESSID}" \
    -H 'Referer: https://www.crazydomains.co.uk/members/' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36' \
    --compressed | jq -r ".data.items[] | select(.domainName==\"$DOMAIN_NAME\") | .domainId")
}

get_dns_zone_records() {
  DNS_RECORDS_JSON=$(curl -s 'https://www.crazydomains.co.uk/members/legacy/ajax/domains/details_info/' \
    --cookie "PHPSESSID=${PHPSESSID}" \
    -H 'Origin: https://www.crazydomains.co.uk' \
    -H "Referer: https://www.crazydomains.co.uk/members/legacy/domains/details/?id=${DOMAIN_ID}" \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36' \
    -H 'X-Requested-With: XMLHttpRequest' \
    --data-raw "ajax_token=${AJAX_TOKEN}&domain_id=${DOMAIN_ID}" \
    --compressed |jq -r '.data.dns_records[]')
}

logout() {
  curl -s 'https://www.crazydomains.co.uk/members/ajax/member/logout/' \
    --cookie "PHPSESSID=${PHPSESSID}" \
    -H 'Origin: https://www.crazydomains.co.uk' \
    -H 'Referer: https://www.crazydomains.co.uk/members/' \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36' \
    -H 'X-Requested-With: XMLHttpRequest' \
    --data-raw "ajax_token=${AJAX_TOKEN}" \
    --compressed &> /dev/null
}

###################  Public functions #####################

#-- dns_cd_add() - Add TXT record --------------------------------------
# Usage: dns_cd_add _acme-challenge.subdomain.domain.com "XyZ123..."

dns_cd_add() {
  fulldomain=$1
  RECORD_CONTENT=$2

  init $fulldomain
  login
  get_domain_id
  get_dns_zone_records

  ## Count TXT records in Zone (count start from 0)
  TXT_RECORDS_COUNT=$(echo ${DNS_RECORDS_JSON} | jq -r . | grep -c "txt_records")
  TXT_RECORDS_COUNT=$((TXT_RECORDS_COUNT-1))

  ADD_REC_OUTPUT=$(curl -s 'https://www.crazydomains.co.uk/members/legacy/ajax/domains/records-process/' \
    --cookie "PHPSESSID=${PHPSESSID}" \
    -H 'Origin: https://www.crazydomains.co.uk' \
    -H "Referer: https://www.crazydomains.co.uk/members/legacy/domains/details/?id=${DOMAIN_ID}" \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36' \
    -H 'X-Requested-With: XMLHttpRequest' \
    --data-raw "edited_records%5B0%5D%5Bsubdomain%5D=${DNS_ACME_RECORD}&edited_records%5B0%5D%5Btxt%5D=${RECORD_CONTENT}&edited_records%5B0%5D%5Btype%5D=txt_records&edited_records%5B0%5D%5Baction%5D=new_record&edited_records%5B0%5D%5Bthis_is_new_record%5D=true&edited_records%5B0%5D%5Brecord_id%5D=txt_records_new_${TXT_RECORDS_COUNT}&action=dns&domain_id=${DOMAIN_ID}" \
    --compressed)

  DNS_STATUS=$(echo "${ADD_REC_OUTPUT}" |jq -r '.message' )
    if [ "${DNS_STATUS}" != "${SUCCESS}" ]; then
      echo "Adding DNS record failed."
      logout
      return 1
    else
      DNS_RECORDS_JSON=$(echo "${ADD_REC_OUTPUT}" | jq -r '.data.dns_records[]')
      echo "DNS record added successfully."
      logout
      return 0
    fi
}

dns_cd_rm() {
  fulldomain=$1
  RECORD_CONTENT=$2

  init $fulldomain
  login
  get_domain_id
  get_dns_zone_records

  RECORD_ID=$(echo $DNS_RECORDS_JSON | jq -r ".| select(.content==\"$RECORD_CONTENT\") | .record_id")
  
  DEL_REC_OUTPUT=$(curl -s 'https://www.crazydomains.co.uk/members/legacy/ajax/domains/records-process/' \
      --cookie "PHPSESSID=${PHPSESSID}" \
      -H 'Origin: https://www.crazydomains.co.uk' \
      -H "Referer: https://www.crazydomains.co.uk/members/legacy/domains/details/?id=${DOMAIN_ID}" \
      -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36' \
      -H 'X-Requested-With: XMLHttpRequest' \
      --data-raw "deleted_records%5B%5D=$RECORD_ID&action=dns&domain_id=${DOMAIN_ID}" \
      --compressed)

  DNS_STATUS=$(echo "${DEL_REC_OUTPUT}" |jq -r '.message' )
  if [ "${DNS_STATUS}" != "${SUCCESS}" ]; then
    echo "Removing DNS record failed."
    logout
    return 1
  else 
    echo "DNS record removed successfully."
    logout
    return 0
  fi 
}
