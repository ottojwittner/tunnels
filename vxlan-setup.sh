#! /bin/bash
#
# Create and setup vxlan tunnel
#
# Author: Otto J Wittner
#

MCADDR="233.0.224.4"
RHOST=""
RPORT="5995"
VXLAN="vxlan0"
#VXLANIP="10.100.100.$(( ( RANDOM % 255 )  + 1 ))/24"   # random last byte
TUNIP=""
VXBRIDGE="vxbr0"
SRCPORT="33100 33110"

USAGE="Usage: `basename $0` [-m mcaddr | -r hostaddr | -p port |-h] tunnel-device [bridge-device]\n
  -h                Help message\n
  -m mcaddr         Multicast address (default $MCADDR)\n
  -r hostadd        Host address of remote tunnel endpoint (if not set, use mcaddr)\n
  -p port           Port of remote tunnel endpoint, i.e. destinasion port (default $RPORT)\n
  -P \"min max\"    Min and max port in source port range\n
  -i ip address     IP address of tunnel inside (default dhcp)\n
  -d                Delete tunnel\n
  -q		    Be quiet, don't output info messages\n
  tunnel-device     Name of tunnel endpoint exit device\n
  bridge-device     Name of device to bridge with tunnel\n
  "

ACTION="add"

# Output info message
function msg ()
{
    if [ -z "$QUIT" ]
    then
	echo $*
    fi
}


# Parse options
while getopts "m:r:p:P:i:hdq" opt
do
    case $opt in 
	h)
	    echo -e $USAGE
	    exit 0
	    ;;
	m)
	    MCADDR=$OPTARG; 
	    ;;
	r)
	    RHOST=$OPTARG; 
	    ;;
	p)
	    RPORT=$OPTARG; 
	    ;;
	P)
	    SRCPORT="$OPTARG"; 
	    ;;
	i)
	    TUNIP=$OPTARG;
	    ;;
	d)
	    ACTION="del"
	    ;;
	q)  QUIT="yes"
	    ;;
	\?)
	    echo "Invalid option: -$OPTARG" >&2
	    echo -e $USAGE
	    exit 1
	    ;;
    esac
done
shift $(($OPTIND - 1))  # (Shift away parsed arguments)

# root user required
if [ `whoami` != 'root' ]
then
    msg "Root access required. Run 'sudo `basename $0` $@'."
    exit 1;
fi

TDEV="$1"   # Tunnel device
BDEV="$2"   # Bridge device

# Use multicast as default if no remote host is given
ADDR="group $MCADDR ttl 15"
if [ "$RHOST" ]
then
    ADDR="remote $RHOST"
fi

case $ACTION in
    "add")
	if [ -z "$TDEV" ]
	then
	    # No device given. Show status
	    msg "Tunnel status:"
	    ip -h link show $VXLAN
	    brctl show $VXBRIDGE
	    #ip addr show $VXLAN
	else
	    # Create tunnel endpoint
	    msg "Cleaning up old tunnel (if any)..."
	    ip link set $VXLAN down 2> /dev/null
	    ip link del $VXLAN 2> /dev/null
	    msg "Creating new tunnel endpoint as device $VXLAN  (dstip $ADDR dstport $RPORT srcport $SRCPORT tdev $TDEV) ..."
	    ip link add $VXLAN type vxlan id 1 $ADDR dstport $RPORT srcport $SRCPORT dev $TDEV
	    ip link set $VXLAN up

	    TUNIPDEV=$VXLAN  # Device to get inside-tunnel-ip

	    if [ "$BDEV" ]
	    then
		# Create bridge
		msg "Cleanin up old bridge (if any)..."
		ifconfig $VXBRIDGE down 2> /dev/null
		brctl delbr $VXBRIDGE 2> /dev/null
		msg "Creating new bridge $VXBRIDGE with devices $VXLAN and $BDEV..."
		brctl addbr $VXBRIDGE
		brctl addif $VXBRIDGE $VXLAN
		brctl addif $VXBRIDGE $BDEV
		ifconfig $VXBRIDGE up
		msg "Disabling iptables for bridges..."
                # Turn off iptables for bridges
                sysctl net.bridge.bridge-nf-call-iptables=0
 
		TUNIPDEV=$BDEV # Set IP of bride instead
	    fi
	    if [ "$TUNIP" ]
	    then
		# Set static IP for tunnel inside device
		msg "Setting IP address $TUNIP one device $TUNIPDEV..."
#		ip addr add $TUNIP dev $TUNIPDEV
		ifconfig $TUNIPDEV $TUNIP 
	    else
		# Set IP with DHCP
		msg "Setting IP address on device $TUNIPDEV with DHCP..."
		dhclient $TUNIPDEV
	    fi
	fi
	;;
    "del")
	# Remove tunnel endpoint
	msg "Cleaning up bridge and vxlan tunnel..."
	ifconfig $VXBRIDGE down 2> /dev/null
	brctl delbr $VXBRIDGE 2> /dev/null
	ip link set $VXLAN down 2> /dev/null
	ip link del $VXLAN
	;;
esac
	
	


