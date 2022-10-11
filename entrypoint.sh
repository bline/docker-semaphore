#!/bin/bash

set -e

parse_env() {
  prefix="$1"
  while IFS='=' read -r -d '' n v; do
    if [[ $n = ${prefix}_* && $n = *_FILE ]]; then
      export "${n/_FILE}=$(<$v)";
      unset "${n}"
    fi
  done < <(env -0)
}

tolower() {
  txt="$1"
  echo "$txt" | tr '[:lower:]' '[:upper:]'
}

parse_cfg() {
  file="$1"
  prefix="$2"
  jquery='to_entries|map("\(.key)=\(.value|tostring)")|.[]'
  while IFS='=' read n v; do
    if [ "$n" = "postgres" -o "$n" = "mysql" -o "$n" = "bolt" ]; then
      while IFS='=' read pn pv; do
        if [ "$pn" = "options" ]; then
          while IFS='=' read on ov; do
            varname="${prefix}_DB_OPTIONS_$(tolower $on)"
            if [ -z "${!varname}" ]; then
              export "${varname}=${ov}"
            fi
          done < <(echo "$ov" | jq -r "$jquery")
        else
          varname="${prefix}_DB_$(tolower $pn)"
          if [ -z "${!varname}" ]; then
            export "${varname}=${pv}"
          fi
        fi
      done < <(echo "$v" | jq -r "$jquery")
    elif [ "$n" = "ldap_mappings" ]; then
      while IFS='=' read ln lv; do
        varname="${prefix}_LDAP_MAPPINGS_$(tolower $ln)"
        if [ -z "${!varname}" ]; then
          export "${varname}=${lv}"
        fi
      done < <(echo "$v" | jq -r "$jquery")
    else
      varname="${prefix}_$(tolower $n)"
      if [ -z "${!varname}" ]; then
        export "${varname}=${v}"
      fi
    fi
  done < <(cat "$file" | jq -r "$jquery")
}

echoerr() { printf "%s\n" "$*" >&2; }

CONFIG_PATH="${SEMAPHORE_CONFIG_PATH:-/etc/semaphore}"
unset SEMAPHORE_CONFIG_PATH

CONFIG_FILE="${CONFIG_PATH}/config.json"
MERGED_CONFIG_FILE="${CONFIG_PATH}/config-merged.json"

parse_env "SEMAPHORE"
if [ -f "${CONFIG_FILE}" ]; then
  parse_cfg "${CONFIG_FILE}" "SEMAPHORE"
fi

# Semaphore Admin env config
ADMIN="${SEMAPHORE_ADMIN:-admin}"
unset SEMAPHORE_ADMIN
ADMIN_EMAIL="${SEMAPHORE_ADMIN_EMAIL:-admin@localhost}"
unset SEMAPHORE_ADMIN_EMAIL
ADMIN_NAME="${SEMAPHORE_ADMIN_NAME:-Semaphore Admin}"
unset SEMAPHORE_ADMIN_NAME
ADMIN_PASSWORD="${SEMAPHORE_ADMIN_PASSWORD:-semaphorepassword}"
unset SEMAPHORE_ADMIN_PASSWORD

export SEMAPHORE_TMP_PATH="${SEMAPHORE_TMP_PATH:-/tmp/semaphore}"

# Semaphore database env config
export SEMAPHORE_DB_DIALECT="${SEMAPHORE_DB_DIALECT:-bolt}"
export SEMAPHORE_DB_HOST="${SEMAPHORE_DB_HOST:-/var/lib/semaphore/database.bolt}"
export SEMAPHORE_DB_PORT="${SEMAPHORE_DB_PORT:-}"
export SEMAPHORE_DB_NAME="${SEMAPHORE_DB_NAME:-semaphore}"
export SEMAPHORE_DB_USER="${SEMAPHORE_DB_USER:-semaphore}"
export SEMAPHORE_DB_PASS="${SEMAPHORE_DB_PASS:-semaphore}"
#Semaphore LDAP env config
export SEMAPHORE_LDAP_ENABLED="${SEMAPHORE_LDAP_ENABLED:-no}"
export SEMAPHORE_LDAP_SERVER="${SEMAPHORE_LDAP_SERVER:-}"
export SEMAPHORE_LDAP_NEEDTLS="${SEMAPHORE_LDAP_NEEDTLS:-no}"
export SEMAPHORE_LDAP_BINDDN="${SEMAPHORE_LDAP_DN_BIND:-}"
export SEMAPHORE_LDAP_PASSWORD="${SEMAPHORE_LDAP_PASSWORD:-}"
export SEMAPHORE_LDAP_SEARCHDN="${SEMAPHORE_LDAP_SEARCHDN:-}"
export SEMAPHORE_LDAP_SEARCHFILTER="${SEMAPHORE_LDAP_SEARCHFILTER:-(uid=%s)}"
export SEMAPHORE_LDAP_MAPPINGS_DN="${SEMAPHORE_LDAP_MAPPINGS_DN:-dn}"
export SEMAPHORE_LDAP_MAPPINGS_UID="${SEMAPHORE_LDAP_MAPPINGS_UID:-uid}"
export SEMAPHORE_LDAP_MAPPINGS_CN="${SEMAPHORE_LDAP_MAPPINGS_CN:-cn}"
export SEMAPHORE_LDAP_MAPPINGS_MAIL="${SEMAPHORE_LDAP_MAPPINGS_MAIL:-mail}"

export SEMAPHORE_ACCESS_KEY_ENCRYPTION="${SEMAPHORE_ACCESS_KEY_ENCRYPTION:-cFcXI5qHzCDqtS4xCnblOACuNu5AmKHkvxK7abwR8Eg=}"

envtpl < /config.json.tpl > "${MERGED_CONFIG_FILE}"

dbdialect=`cat ${MERGED_CONFIG_FILE} | jq -r '.dialect'`
dbhost=`cat ${MERGED_CONFIG_FILE} | jq -r .${dbdialect}.host`;

if [ "${dbdialect}" != 'bolt' ]; then
  # wait for the database to be up
  IFS=":" read -r dbhost dbport < <(echo "$dbhost")
  echoerr "Waiting for database ${dbhost}:${dbport} to be up ..."
  TIMEOUT=30
  while ! $(nc -z "$dbhost" "$dbport") >/dev/null 2>&1; do
      TIMEOUT=$(expr $TIMEOUT - 1)
      if [ $TIMEOUT -eq 0 ]; then
          echoerr "Could not connect to database server. Exiting."
          exit 1
      fi
      echo -n "."
      sleep 1
  done
fi

if ! semaphore user get --login "${ADMIN}" --config "${MERGED_CONFIG_FILE}" >/dev/null 2>&1; then
  echo "semaphore user add --admin --email ${ADMIN_EMAIL} --login ${ADMIN} --name ${ADMIN_NAME} --password ${ADMIN_PASSWORD} --config ${MERGED_CONFIG_FILE}"
  if ! semaphore user add --admin --email "${ADMIN_EMAIL}" --login "${ADMIN}" --name "${ADMIN_NAME}" --password "${ADMIN_PASSWORD}" --config "${MERGED_CONFIG_FILE}"; then
    echoerr "failed to add admin user"
    exit 1
  fi
fi

exec "$@" --config "${MERGED_CONFIG_FILE}"

