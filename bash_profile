#!/bin/bash
# ONOS developer BASH profile conveniences
# Simply include in your own .bash_aliases or .bash_profile

# Root of the ONOS source tree
export ONOS_ROOT=${ONOS_ROOT:-~/onos}

# Setup some environmental context for developers
if [ -z "${JAVA_HOME}" ]; then
    if [ -x /usr/libexec/java_home ]; then
        export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
    elif [ -d /usr/lib/jvm/java-8-oracle ]; then
        export JAVA_HOME="/usr/lib/jvm/java-8-oracle"
    elif [ -d /usr/lib/jvm/java-8-openjdk-amd64 ]; then
        export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
    fi
fi

export MAVEN=${MAVEN:-~/Applications/apache-maven-3.3.1}

export KARAF_VERSION=${KARAF_VERSION:-3.0.3}
export KARAF_ROOT=${KARAF_ROOT:-~/Applications/apache-karaf-$KARAF_VERSION}
export KARAF_LOG=$KARAF_ROOT/data/log/karaf.log

# Setup a path
export PATH="$PATH:$ONOS_ROOT/tools/dev/bin"
export PATH="$PATH:$ONOS_ROOT/tools/test/bin:$ONOS_ROOT/tools/test/scenarios/bin"
export PATH="$PATH:$ONOS_ROOT/tools/build"
export PATH="$PATH:$MAVEN/bin:$KARAF_ROOT/bin"

# Setup cell enviroment
export ONOS_CELL=${ONOS_CELL:-local}

# Setup default web user/password
export ONOS_WEB_USER=onos
export ONOS_WEB_PASS=rocks

# Setup default location of test scenarios
export ONOS_SCENARIOS=$ONOS_ROOT/tools/test/scenarios

# Convenience utility to warp to various ONOS source projects
# e.g. 'o api', 'o dev', 'o'
function o {
    cd $(find $ONOS_ROOT/ -type d | egrep -v '\.git|target|gen-src' | \
        egrep "${1:-$ONOS_ROOT}" | egrep -v "$ONOS_ROOT/.+/src/" | head -n 1)
}

# Short-hand for 'mvn clean install' for us lazy folk
alias mci='mvn clean install'
alias mcis='mvn clean install -DskipTests -Dcheckstyle.skip -U -T 1C'
alias mis='mvn install -DskipTests -Dcheckstyle.skip -U -T 1C'

# Short-hand for ONOS build, package and test.
alias ob='onos-build'
alias obi='onos-build -Dmaven.test.failure.ignore=true'
alias obs='onos-build-selective'
alias obd='onos-build-docs'
alias op='onos-package'
alias ok='onos-karaf'
alias ot='onos-test'
alias ol='onos-log'
alias ow='onos-watch'
alias ocl='onos-check-logs'
alias oi='setPrimaryInstance'
alias pub='onos-push-update-bundle'

# Short-hand for tailing and searching the ONOS (karaf) log
alias tl='$ONOS_ROOT/tools/dev/bin/onos-local-log'
alias ll='less $KARAF_LOG'
alias gl='grep $KARAF_LOG --colour=auto -E -e '

function filterLocalLog {
    tl | grep --colour=always -E -e "${1-org.onlab|org.onosproject}"
}
alias tlo='filterLocalLog'
alias tle='tlo "ERROR|WARN|Exception|Error"'

function filterLog {
    ol | grep --colour=always -E -e "${1-org.onlab|org.onosproject}"
}
alias olo='filterLog'
alias ole='olo "ERROR|WARN|Exception|Error"'

# Pretty-print JSON output
alias pp='python -m json.tool'

# Short-hand to launch Java API docs, REST API docs and ONOS GUI
alias docs='open $ONOS_ROOT/docs/target/site/apidocs/index.html'
alias rsdocs='onos-rsdocs'
alias gui='onos-gui'


# Test related conveniences

# SSH to a specified ONOS instance
alias sshctl='onos-ssh'
alias sshnet='onos-ssh $OCN'


# Sets the primary instance to the specified instance number.
function setPrimaryInstance {
    export OCI=$(env | egrep "OC[0-9]+" | sort | egrep OC${1:-1} | cut -d= -f2)
    echo $OCI
}

# Applies the settings in the specified cell file or lists current cell definition
# if no cell file is given.
function cell {
    if [ -n "$1" ]; then
        [ ! -f $ONOS_ROOT/tools/test/cells/$1 ] && \
            echo "No such cell: $1" >&2 && return 1
        unset ONOS_CELL ONOS_NIC ONOS_IP ONOS_APPS ONOS_BOOT_FEATURES
        unset OCI OCN OCT ONOS_INSTANCES ONOS_USER ONOS_GROUP ONOS_FEATURES
        unset $(env | sed -n 's:\(^OC[0-9]\{1,\}\)=.*:\1 :g p')
        export ONOS_WEB_USER=onos
        export ONOS_WEB_PASS=rocks
        export ONOS_CELL=$1
        . $ONOS_ROOT/tools/test/cells/$1
        export ONOS_INSTANCES=$(env | grep 'OC[0-9]*=' | sort | cut -d= -f2)
        setPrimaryInstance 1 >/dev/null
        cell
    else
        env | egrep "ONOS_CELL"
        env | egrep "OCI"
        env | egrep "OC[0-9]+" | sort
        env | egrep "OC[NT]"
        env | egrep "ONOS_" | egrep -v 'ONOS_ROOT|ONOS_CELL|ONOS_INSTANCES' | sort
    fi
}

cell $ONOS_CELL > /dev/null

# Lists available cells
function cells {
    for cell in $(ls -1 $ONOS_ROOT/tools/test/cells); do
        printf "%-16s  %s\n" \
            "$([ $cell = $ONOS_CELL ] && echo $cell '*' || echo $cell)" \
            "$(grep '^#' $ONOS_ROOT/tools/test/cells/$cell | head -n 1)"
    done
}

# Miscellaneous
function spy {
    ps -ef | egrep "$@" | grep -v egrep
}

function nuke {
    spy "$@" | cut -c7-11 | xargs kill
}

# Edit a cell file by providing a cell name. Opens the cell file in $EDITOR.
function vicell() {
  local apply=false
  local create=false
  local cdf=""
  local cpath="${ONOS_ROOT}/tools/test/cells/"

  if [ -z "$1" ] || [ "$1" = "-h" ] ; then
    printf "usage: vicell [file] [options]\n\noptions:\n"
    printf "\t-a: apply the cell after editing\n"
    printf "\t-e: [editor] set EDITOR to [editor] (default *vi*)\n"
    printf "\t-c: create cell file if none exist\n\n"
    return 1
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      -a) apply=true ;;
      -e) EDITOR=$2; shift ;;
      -c) create=true ;;
      *) cdf="$1" ;;
    esac
    shift
  done

  if [ ! -e "${cpath}${cdf}" ] && [ "$create" = "false" ]; then
       printf "${cdf} : no such cell\n" && return 1
  fi

  if [ -z "${EDITOR}" ] || [ -x "$(which ${EDITOR})" ]; then
    unset EDITOR && vi ${cpath}${cdf}
  else
    $EDITOR ${cpath}${cdf}
  fi
  ($apply) && cell ${cdf}
}

# autocomplete for certain utilities
. ${ONOS_ROOT}/tools/test/bin/ogroup-opts
