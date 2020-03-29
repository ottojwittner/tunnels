#!/bin/bash
#
# Add/remove network delay
#
# Author: Otto J Wittner
#

LINK="both"

# Parse arguments
while getopts ":a:rios" opt; do
    case $opt in
        a)
    	    # Add delay
	    DELAY=${OPTARG}
	    ACTION="add"
            ;;
        r)
            # Remove delay
            ACTION="remove"
            ;;
	i)
	    # INPUT ONLY
	    LINK="input"
	    ;;
	o)
	    # OUTPUT ONLY
	    LINK="output"
	    ;;
	s)
	    # SHOW STATUS
	    ACTION="show"
	    ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))  # (Shift away parsed arguments)

if [ $# -lt 1 ]
then
    # No parameters given. Output help info.
    echo "Usage: `basename $0` [-a <delay in ms>] [-rio] interface-name"
    echo "  -a <delay in ms>  Add delay to link(s)"
    echo "  -r                Remove delay"
    echo "  -i                Input direction only"
    echo "  -o                Output direction only"
    exit 1
fi

IF=$1
case $ACTION in
    add)
           # Add delay
	   if [  ${LINK} = "output"  -o  ${LINK} = "both"  ]
	   then
               # Add to outgoing link
               tc qdisc add dev $IF root netem delay ${DELAY}ms
           fi
	   if [  ${LINK} = "input"  -o  ${LINK} = "both"  ]
	   then
               # Add to incoming link 
               modprobe ifb
               ip link set dev ifb0 up
               tc qdisc add dev $IF ingress
               tc filter add dev $IF parent ffff: protocol ip u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb0
               tc qdisc add dev ifb0 root netem delay ${DELAY}ms
           fi
           ;;
 remove)
           # Clean up
           tc qdisc delete dev $IF root 2> /dev/null
           tc qdisc delete dev ifb0 root 2> /dev/null
           tc filter delete dev $IF parent ffff:  2> /dev/null
           tc qdisc delete dev $IF ingress 2> /dev/null
           rmmod ifb 2> /dev/null
           ;;
 show)
           # Show status for tc and qdisc
           tc qdisc show dev $IF
           tc filter show dev $IF
           tc qdisc show dev ifb0 2> /dev/null
           ;;

     \?)
            echo "No action specified. Use -a or -r ." >&2
            exit 1
            ;;
esac
