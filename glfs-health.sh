#!/bin/sh

#
# Usage: $0 [HOST [PORT [TRANSPORT [VOLUME]]]]
#

DEFAULT_HOST=localhost
DEFAULT_PORT=6996
DEFAULT_TYPE=tcp
DEFAULT_NAME=client


conf=/tmp/.glusterfs.vol.$$;
log=/tmp/.glusterfs.log.$$;
pid=/tmp/.glusterfs.pid.$$;
glfs=`which glusterfs 2>/dev/null`;
glfs=/usr/local/sbin/glusterfs;


function parse_cmd_args()
{
    HOST=$DEFAULT_HOST;
    PORT=$DEFAULT_PORT;
    TYPE=$DEFAULT_TYPE;
    NAME=$DEFAULT_NAME;

    if test "x$1" != "x"; then
        HOST=$1
    fi

    if test "x$2" != "x"; then
        PORT=$2
    fi

    if test "x$3" != "x"; then
        TYPE=$3
    fi

    if test "x$4" != "x"; then
        NAME=$4
    fi
}


function spit_vol()
{
cat > $conf <<EOF

volume client
  type protocol/client
  option remote-host $HOST
  option remote-port $PORT
  option transport-type $TYPE
  option remote-subvolume $NAME
  option ping-timeout 2
end-volume

volume server
  type protocol/server
  option transport-type tcp
  option auth.addr.client.allow *
  subvolumes client
end-volume

EOF
}


function glfs()
{
    $glfs -f $conf -l $log -p $pid -LTRACE
}


function cleanup()
{
    kill -TERM `cat $pid`;
    rm -rf $conf $log $pid;
}


function watsup()
{
    ans="Host unreachable"

    for i in $(seq 1 10); do
        if grep -iq 'connection refused' $log; then
            ans="Connection refused"
            break
        fi

        if grep -iq 'client: got GF_EVENT_CHILD_UP' $log; then
            ans="Server Unresponsive"
        fi

        if grep -iq 'socket header signature does not match :O' $log; then
            ans="Unknown service encountered"
            break
        fi

        if grep -iq 'client: SETVOLUME on remote-host failed:' $log; then
            ans=$(sed -n s/'.*client: SETVOLUME on remote-host failed: '//p $log | tail -n 1);
            break
        fi

        if grep -iq 'attached to remote volume' $log; then
            ans="OK"
            break
        fi

        usleep 300000
    done

    echo $ans
}


function main()
{
    trap cleanup EXIT;

    parse_cmd_args "$@"

    spit_vol;
    glfs;

    watsup;
}


main "$@"
