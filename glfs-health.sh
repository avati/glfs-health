#!/bin/bash

#
# Usage: $0 VOLUME [HOST [TRANSPORT]]
#

DEFAULT_HOST=localhost
DEFAULT_PORT=6996
DEFAULT_TYPE=tcp
DEFAULT_NAME=test


mnt=/tmp/.glusterfs.mnt.$$;
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
        NAME=$1
    fi

    if test "x$2" != "x"; then
        HOST=$2
    fi

    if test "x$3" != "x"; then
        TYPE=$3
    fi
}


function glfs()
{
    mkdir -p $mnt;
    $glfs -s $HOST --volfile-id $NAME -l $log -p $pid -LTRACE $mnt &
    sleep 0.3;
}


function cleanup()
{
    [ -f $pid ] && kill -TERM `cat $pid`;
    umount -l $mnt >/dev/null 2>&1;
    rm -rf $conf $pid #$log;
    rmdir $mnt;
}


function watsup()
{
    ans="Unknown Error"

    for i in $(seq 1 10); do
	if grep -iq "failed to fetch volume file (key:$NAME)" $log; then
	    ans="Volume $NAME does not exist"
	    break;
	fi

	if grep -iq 'failed to get the port number for remote subvolume' $log; then
	    ans="Volume $NAME is not started"
	    break;
	fi

	if grep -iq 'DNS resolution failed on host' $log; then
	    ans=$(sed -n s/'.*DNS resolution failed on host '/'DNS resolution failed: '/p $log | tail -n 1);
	    break
	fi

        if grep -iq 'connection refused' $log; then
            ans=$(sed -n s/'.*connection to \([^ ]*\) failed (Connection refused).*'/'Brick \1 crashed'/p $log | tail -n 1)
            break
        fi

        if grep -iq ': got RPC_CLNT_CONNECT' $log; then
            ans="Server Unresponsive"
        fi

        if grep -iq 'socket header signature does not match :O' $log; then
            ans="Unknown service encountered"
            break
        fi

        if grep -iq ': SETVOLUME on remote-host failed:' $log; then
            ans=$(sed -n s/'.*: SETVOLUME on remote-host failed: '//p $log | tail -n 1);
            break
        fi

        if grep -iq 'attached to remote volume' $log; then
            ans="OK"
            break
        fi

        sleep 0.3
    done

    echo $ans
}


function main()
{
    trap cleanup EXIT;

    parse_cmd_args "$@"

    glfs;

    watsup;
}


main "$@"
