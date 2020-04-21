#!/bin/bash

if [[ $EUID -ne 0 ]] ; then 
  echo "Only root can run this script (use sudo)"
  exit 1
fi

ETC_DIR="/etc/acme"
CONFIG="${ETC_DIR}/config"

GetConfig() {
  #ACME_URL="https://acme-staging-v02.api.letsencrypt.org/directory"
  ACME_URL="https://acme-v02.api.letsencrypt.org/directory"
  ACME_DIR="/var/www/acme-challenge"
  RENEW_AGE=14
  DAYS=365
  CURVE=secp384r1
  source "${CONFIG}"
  TYPE_RSA=true
  TYPE_EC=true
  SELF=false
}

if [[ -f "${CONFIG}" ]] ; then
  source "${CONFIG}"
  if [[ ! -f "${ETC_DIR}/account.key" ]] ; then
    echo Generating your ACME account key
    openssl genrsa -out "${ETC_DIR}/account.key" 4096
    echo
  fi
else
  if [[ "$1" != install ]] ; then
    echo "Not installed"
    exit 1
  fi
fi


CmdHelp() {
  echo "Usage: ${BASH_SOURCE[0]} [install|create|renew|list]"; exit 1
  exit 1
}


CmdInstall() {
  #if [[ -f "${CONFIG}" ]] ; then;  echo "Already installed"; exit 1; fi
  echo "Installing"
  if [[ "${BASH_SOURCE[0]}" != "/usr/local/bin/acme.sh" ]]; then
    echo -n "Copy "
    cp -vf ${BASH_SOURCE[0]} /usr/local/bin/acme.sh
    chmod 755 /usr/local/bin/acme.sh
  fi

  if which apt-get &> /dev/null; then
    dpkg -V acme-tiny || apt-get install acme-tiny
  else
    python3 -m pip install --upgrade acme-tiny
  fi 

  [[ -f "${CONFIG}" ]] && return

  echo -n "Symlink "; ln -vsf /usr/local/bin/acme.sh /etc/cron.daily/
  local TXT=$(cat << HDC
# Copy or symlink this file into /etc/httpd/conf.d and reload Apache
Alias /.well-known/acme-challenge /var/www/acme-challenge
<Directory "/var/www/acme-challenge">
    Options             None
    AllowOverride       None
    ForceType           text/plain
</Directory>
HDC
  )

  mkdir -p "${ETC_DIR}"
  echo -e "ACME_URL=\"${ACME_URL}\"\nACME_DIR=\"${ACME_DIR}\"\nHOSTS=\"www smtp\"\nTYPE_RSA=true\nTYPE_EC=true" > "${CONFIG}"
  echo "Created ${CONFIG}" 
  echo "${TXT}" > "${ETC_DIR}/acme-challenge.conf"
  echo -e "#!/bin/bash\n" > "${ETC_DIR}/deploy.sh"
  chmod u+x "${ETC_DIR}/deploy.sh"  
  echo "Creating ${ETC_DIR}/acme-challenge.conf"
  #[[ -d "/etc/httpd/conf.d" ]] && ln -srvf "${ETC_DIR}/acme-challenge.conf" "/etc/httpd/conf.d/"
  echo "Please review the configuration before you proceed"
}

DaysValid() {
  if [[ ! -f "$1" ]]; then
    echo 0
    return
  fi
  local D=$(openssl x509 -in "$1" -enddate -noout | cut -d'=' -f2)
  local D=$(date -d "$D" "+%s")
  local NOW=$(date "+%s")
  echo $(( (D-NOW+3600)/3600/24 ))
}

GetRSAcert() {
  if [[ "${ACME_URL}" ]]; then 
    mkdir -p "${ACME_DIR}" 
    openssl genrsa -out rsa.key.new 4096
    openssl req -new -sha256 -key rsa.key.new -subj "/" -addext "subjectAltName=${NAMES}" > rsa.csr.new
    /usr/local/bin/acme-tiny --account-key ../account.key --csr rsa.csr.new --directory-url="${ACME_URL}" --acme-dir "${ACME_DIR}" > rsa.crt.new || exit $?
    openssl verify -untrusted rsa.crt.new rsa.crt.new || exit $?
    mv -f rsa.crt.new rsa.crt
    mv -f rsa.key.new rsa.key
    mv -f rsa.csr.new rsa.csr
  else
    openssl req -x509 -sha256 -newkey rsa:4096 -nodes -subj "/" -addext "subjectAltName=${NAMES}" -keyout rsa.key -out rsa.crt -days ${DAYS}
  fi

}

GetECcert() {
  if [[ "${ACME_URL}" ]]; then
    mkdir -p "${ACME_DIR}" 
    openssl ecparam -genkey -name ${CURVE} | openssl ec -out ec.key.new
    openssl req -new -sha256 -key ec.key.new -subj "/" -addext "subjectAltName=${NAMES}" > ec.csr.new 
    /usr/local/bin/acme-tiny --account-key ../account.key --csr ec.csr.new --directory-url="${ACME_URL}" --acme-dir "${ACME_DIR}" > ec.crt.new || exit $?
    openssl verify -untrusted ec.crt.new ec.crt.new || exit $?
    mv -f ec.crt.new ec.crt
    mv -f ec.key.new ec.key
    mv -f ec.csr.new ec.csr
  else
    openssl ecparam -genkey -name ${CURVE} | openssl ec -out ec.key
    openssl req -x509 -sha256 -nodes -subj "/" -addext "subjectAltName=${NAMES}" -key ec.key -out ec.crt -days ${DAYS}
  fi
}


CheckFQDN() {
  echo "$1" | grep -qP '(?=^.{1,254}$)(^(?>(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)'
  return $?
}

CheckIP() {
  [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
  return $?
}

CmdCreate() { 
  cd "${ETC_DIR}" || return 1
  GetConfig;
  local NAMES
  while [[ "${1:0:1}" == "-" ]] ; do
    case "${1}" in
      "-self")
        SELF=true
        ;;
      "-rsa")
        TYPE_RSA=true
        TYPE_EC=false
        ;;
      "-ec")
        TYPE_RSA=false
	TYPE_EC=true
        ;;
      -url=*)
	ACME_URL="${1#"-url="}"
	;;
      -curve=*)
        CURVE="${1#"-curve="}"
	;;
      *)
        echo "Unknown option '$1'"
	exit 1
	;;
    esac
    shift 1
  done
  DOMAIN="$1"
  if CheckFQDN "$1"; then
    NAMES="DNS:$1"
    local FQDN="$1"
  else
    CheckIP "$1" && NAMES="IP:$1"
  fi
  [[ "$NAMES" ]] || CmdHelp
  while shift 1; do
    [[ "$1" ]] || break
    if CheckIP "$1"; then
      NAMES="${NAMES},IP:$1"
    else
      if CheckFQDN "$1"; then
        NAMES="${NAMES},DNS:$1"
      else
        if [[ "$FQDN" ]]; then
          NAMES="${NAMES},DNS:$1.$FQDN"
        else
          echo "'$1' must be FQDN"
          exit 1;
        fi
      fi
    fi 
  done;

  if [[ -d "${DOMAIN}" ]] ; then 
    echo "A configuration for ${DOMAIN} already exists in ${ETC_DIR}"
    return 1
  fi
  
  mkdir -p "${DOMAIN}"
  cd "${DOMAIN}"
  echo -e "DOMAIN=\"${DOMAIN}\"\nNAMES=\"${NAMES}\"\nACME_URL=\"${ACME_URL}\"\nTYPE_RSA=${TYPE_RSA}\nTYPE_EC=${TYPE_EC}\nSELF=${SELF}" > "config"
}


CmdRenew() { 
  local d
  local h
  for d in $(echo ${ETC_DIR}/*/config); do 
    local DEPLOY=false
    unset DOMAIN
    unset HOSTS
    unset ACME_URL
    GetConfig;
    source "$d"    
    cd "$(dirname "$d")"
    [[ "${TYPE_RSA,,}" =~ ^(yes|true|1)$ ]] && (( $(DaysValid "rsa.crt") < ${RENEW_AGE}  )) && GetRSAcert && DEPLOY=true
    [[ "${TYPE_EC,,}" =~ ^(yes|true|1)$ ]] && (( $(DaysValid "ec.crt") < ${RENEW_AGE}  )) && GetECcert && DEPLOY=true
    [[ $DEPLOY == true ]] && [[ -f ./deploy.sh ]] && ./deploy.sh
  done  
}

CmdList() {
  local c
  echo
  for c in $(echo ${ETC_DIR}/*/*.crt); do
    [[ -f "$c" ]] || continue
    echo File: $c
    openssl x509 -in "$c" -noout -text|grep "Issuer:\|DNS:\|IP Address:\|NIST CURVE:"|sed 's/^ */ /'
    openssl x509 -in "$c" -noout -text|grep "Signature Algorithm:"|head -n1|sed 's/^ */ /'
    echo " Validity: $(DaysValid "$c")"
    echo
  done
}

if [[ ! -t 0 ]] && [[ $# == 0 ]]; then
  CmdRenew
  exit $?
fi

case "$1" in 
  "install")
    CmdInstall
  ;;
  "create")
    CmdCreate "${@:2}"
  ;;
  "renew")
    CmdRenew
  ;;
  "list")
    CmdList
  ;;
  *)
    CmdHelp
  ;;
esac
