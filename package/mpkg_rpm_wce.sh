#!/bin/sh

# ---------------------------------------------------------------
# Copyright 2007 Przemyslaw Czerpak (druzus/at/priv.onet.pl)
# simple script to build Harbour-WinCE cross build RPMs
#
# See LICENSE.txt for licensing terms.
# ---------------------------------------------------------------

test_reqrpm() {
  rpm -q --whatprovides "$1" >/dev/null 2>&1
}

get_rpmmacro() {
  _R="$(rpm --showrc | sed -e "/^-14:.${1}[^a-z0-9A-Z_]/ !d" -e "s/^-14: ${1}.//")"
  _X="$(echo "${_R}" | sed -e 's/.*\(%{\([^}]*\)}\).*/\2/')"
  while [ "${_X}" != "${_R}" ]; do
    _Y=$(get_rpmmacro "${_X}")
    if [ -n "${_Y}" ]; then
      _R="$(echo "${_R}" | sed -e "s!%{${_X}}!${_Y}!g")"
      _X="$(echo "${_R}" | sed -e 's/.*\(%{\([^}]*\)}\).*/\2/')"
    else
      _X="${_R}"
    fi
  done
  printf %s "${_R}"
}

cd "$(dirname "$0")" || exit

. ./mpkg_ver.sh
hb_verfull=$(hb_get_ver)
hb_verstat=$(hb_get_ver_status)

NEED_RPM='make gcc binutils cegcc-mingw32ce'

FORCE=''

while [ $# -gt 0 ]; do
  if [ "$1" = '--force' ]; then
    FORCE='yes'
  else
    INST_PARAM="${INST_PARAM} $1"
  fi
  shift
done

TOINST_LST=''
for i in ${NEED_RPM}; do
  test_reqrpm "${i}" || TOINST_LST="${TOINST_LST} ${i}"
done

OLDPWD="${PWD}"

if [ -z "${TOINST_LST}" ] || [ "${FORCE}" = 'yes' ]; then
  cd "$(dirname "$0")" || exit
  . ./mpkg_src.sh
  stat="$?"
  if [ -z "${hb_filename}" ]; then
    echo "The script ./mpkg_src.sh didn't set archive name to \${hb_filename}"
    exit 1
  elif [ "${stat}" != 0 ]; then
    echo 'Error during packing the sources in ./mpkg_src.sh'
    exit 1
  elif [ -f "${hb_filename}" ]; then
    if ( [ "$(id -u)" != 0 ] || [ -f /.dockerenv ] ) && \
       [ ! -f "${HOME}/.rpmmacros" ]; then
      RPMDIR="${HOME}/RPM"
      mkdir -p \
        "${RPMDIR}/BUILD" \
        "${RPMDIR}/RPMS" \
        "${RPMDIR}/SOURCES" \
        "${RPMDIR}/SPECS" \
        "${RPMDIR}/SRPMS"
      echo "%_topdir ${RPMDIR}" > "${HOME}/.rpmmacros"
    else
      RPMDIR=$(get_rpmmacro '_topdir')
    fi

    mv -f "${hb_filename}" "${RPMDIR}/SOURCES/"
    # Required for rpmbuild versions < 4.13.0
    chown "$(id -u)" "${RPMDIR}/SOURCES/$(basename "${hb_filename}")"

    sed -e "s|^%define version .*$|%define version ${hb_verfull}|g" \
        -e "s|^%define verstat .*$|%define verstat ${hb_verstat}|g" \
        harbour-wce.spec.in > "${RPMDIR}/SPECS/harbour-wce.spec"
    cd "${RPMDIR}/SPECS" || exit

    # shellcheck disable=SC2086
    rpmbuild -ba harbour-wce.spec ${INST_PARAM}

    if [ -f /.dockerenv ]; then
      rm -rf "${OLDPWD}/RPM"
      cp -r "${RPMDIR}" "${OLDPWD}"
    fi
  else
    echo "Cannot find archive file: ${hb_filename}"
    exit 1
  fi
else
  echo 'If you want to build Harbour compiler'
  echo 'you have to install the folowing RPM files:'
  echo "${TOINST_LST}"
  exit 1
fi
