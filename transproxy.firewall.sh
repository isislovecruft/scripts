#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
#
# transproxy.firewall.sh
# ----------------------
# A script for appending iptables (and ip6tables) rules which setup a Tor
# Transproxy for a specific user, including configurable settings for:
#
#   * Setting up a Transproxy on either a Tor relay or a Tor client.
#
#   * Allowing only the ICMP and IGMP types strictly required for common
#     packet routing protocols, or disabling ICMP and IGMP entirely.
#
#   * Tagging packets which appear to be Garbage Probes coming from the Great
#     Firewall of the P.R.C., and sending these raw packets to an NFLOG
#     virtual capture interface (which can be a .pcap file) for later offline
#     analysis.
#
# TODO: I don't think ip6tables Transproxies work, though I currently cannot
# recall why, and am not currently able to re-test. Someone with a good
# knowledge of IPv6 and of analysing traffic patterns for proxy leakage should
# take a look at this. For now, a big red WARNING will print out for anyone
# who decides to risk using it.
#
# :author: isis lovecruft <isis@torproject.org> 0xA3ADB67A2CDB8B35
# :license: AGPLv3 https://www.gnu.org/licenses/agpl-3.0.txt
# :version: 0.1.17
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

if [[ "$(id -u)" != "0" ]]; then echo "Must be run with sudo." ; exit 1 ; fi

## IPv6
##########################
CREATE_IPV4_RULES=true
CREATE_IPV6_RULES=true
FOUR=$(which iptables)
SIX=$(which ip6tables)

## Tor
##########################
TOR_RELAY=false
TOR_OR_PORTS="9001"
TOR_DIR_PORTS="9030"

TOR_CLIENT=true
TOR_SOCKS_PORTS="9050 9150"
TOR_CONTROL_PORTS="9051 9151"

TRANSPROXY=true
TOR_TRANS_PORTS="9040"
TOR_DNS_PORTS="5353"
TRANSPROXY_USERS="anon"

GARBAGE=false
GARBAGE_PROBES="$TOR_SOCKS_PORTS $TOR_CONTROL_PORTS $TOR_DIR_PORTS $TOR_OR_PORTS"

## ICMP and IGMP are ownerless, meaning that outgoing "pings" do not belong to
## a specific user. If a Tor-ified user can be manipulated into sending a
## ping, they can be de-anonymised.
##
## Note that this disables pings and icmp-based traceroutes for *all* users.
IPv4_BLOCK_OUTGOING_PINGS=true
IPv6_BLOCK_OUTGOING_PINGS=true

###############################################################################
## GARBAGE PROBE PACKET TAGGING
###############################################################################
## This has to go before the invalid packet rules, to catch the garbage probes:
if $GARBAGE ; then
    if test -n "$GARBAGE_PROBES"; then
        for port in $GARBAGE_PROBES ; do
            sudo iptables -A INPUT -p tcp --dport "$port" -j CONNMARK --set-mark 1
            sudo iptables -A INPUT -p udp --dport "$port" -j CONNMARK --set-mark 1
        done
    fi

## Catch the INVALID garbage probe packets of len==40 before they hit the
## invalid DROP filter (these seem to always go to the ORPort), and send them
## to the NFLOG, so that we can log them to a file and look at them later.
##
## To dump these packets to a file as they arrive in the NFLOG, do:
##
##    $ tcpdump -i nflog:30 -w garbage.pcap
##
    if test -n "$GARBAGE_PROBES"; then
        for port in $TOR_OR_PORTS ; do
            sudo iptables -A INPUT -p tcp --dport "$port" -m state --state INVALID \
                 -j LOG --log-prefix "iptables: Garbage to ORPort: " --log-level 7
            sudo iptables -A INPUT -p tcp --dport "$port" -m state --state INVALID \
                 -m connmark --mark 1 \
                 -j NFLOG --nflog-prefix "GARBAGE PROBE " --nflog-group 30
            sudo iptables -A INPUT -p tcp --dport "$port" -m state --state INVALID \
                 -j REJECT --reject-with tcp-reset
        done
    fi
fi

##--------------##
##  TOR RULES   ##
##______________##

function transproxy {
    prog=$1
    printf "Using %s...\n" $prog

    if $TOR_CLIENT ; then
        printf "Creating Tor client rules...\n"

        ## REJECT SocksPort REQUESTS FOR ALL EXCEPT LOCALHOST
        ## Tor does this by default, but just to be extra sure...
        if test -n "$TOR_SOCKS_PORTS"; then
            for port in $TOR_SOCKS_PORTS ; do
                ## Send non-loopback packets destined for our SocksPort to the
                ## Garbage Probe collector:
                if test $GARBAGE ; then
                    $prog -A INPUT ! -i lo -p tcp --dport "$port" \
                        -m connmark --mark 1 \
                        -j NFLOG --nflog-prefix "GARBAGE PROBE " --nflog-group 30
                fi

                printf "\tREJECTing non-loopback traffic to SocksPort %s...\n" $port
                $prog -A INPUT ! -i lo -p tcp --dport "$port" \
                    -j LOG --log-prefix "iptables: SocksPort: " --log-level 7
                $prog -A INPUT ! -i lo -p tcp --dport "$port" \
                    -j REJECT --reject-with tcp-reset
            done
        fi

        if test -n "$TOR_CONTROL_PORTS"; then
            for port in $TOR_CONTROL_PORTS ; do
                printf "\tREJECTing non-loopback traffic to ControlPort %s...\n" $port
                if test $GARBAGE ; then
                    $prog -A INPUT ! -i lo -p tcp --dport "$port" \
                        -m connmark --mark 1 \
                        -j NFLOG --nflog-prefix "GARBAGE PROBE " --nflog-group 30
                fi
                $prog -A INPUT ! -i lo -p tcp --dport "$port" \
                    -j LOG --log-prefix "iptables: ControlPort: " --log-level 7
                $prog -A INPUT ! -i lo -p tcp --dport "$port" \
                    -j REJECT --reject-with tcp-reset
            done
        fi
    fi
    ## /end TOR_CLIENT ruleset generation

    if $TOR_RELAY ; then
        printf "Creating Tor relay rules...\n"
        if test -n "$TOR_OR_PORTS"; then
            for port in $TOR_OR_PORTS ; do
                printf "\tACCEPTing TCP traffic to ORPort %s...\n" $port
                $prog -A INPUT -p tcp --dport "$port" -j ACCEPT
            done
        fi

        if test -n "$TOR_DIR_PORTS"; then
            for port in $TOR_DIR_PORTS ; do
                printf "\tACCEPTing TCP traffic to DirPort %s...\n" $port
                $prog -A INPUT -p tcp --dport "$port" -j ACCEPT
            done
        fi
    fi

    ############################################################################
    ## TRANSPROXY CONFIGURATION
    ############################################################################
    ## ICMP SETTINGS
    ## -------------
    ## Due to non-ownership, correlations could be made between Tor DNS requests
    ## and non-Tor DNS requests, so TransProxy'd users should avoid outgoing
    ## pinging.
    ##

    ## BLOCK INCOMING ICMP PINGS:
    ## Destination-unreachable(3), source-quench(4) and time-exceeded(11) are
    ## required.
    ##
    ## For ping and traceroute you want echo-request(8) and echo-reply(0)
    ## enabled. You might be able to disable them, but it would probably
    ## break things.
    if [[ "$prog" == "$(which iptables)" ]] ; then
        printf "\nSetting up ICMPv4 rules...\n"
        for icmptype in 3 4 11 0 8 ; do
            printf "\tACCEPTing incoming ICMPv4 type %s...\n" "$icmptype"
            $prog -A INPUT -p icmp -m icmp --icmp-type $icmptype -j ACCEPT
        done

        ## REJECT ALL OTHER ICMP TYPES:
        printf "\tREJECTing all other incoming ICMPv4 types...\n"
        $prog -A INPUT -p icmp \
            -m limit --limit 5/min --limit-burst 5000 \
            -j LOG --log-prefix "iptables: ICMP !0/3/4/8/11: " --log-level 7
        $prog -A INPUT -p icmp \
            -j REJECT --reject-with icmp-host-unreachable

        ## To GLOBALLY BLOCK outgoing pings which are not types 0, 3, 4, 8, or
        ## 11, for Tor TransProxy, set IPv4_BLOCK_OUTGOING_PINGS=true
        if $IPv4_BLOCK_OUTGOING_PINGS ; then
            printf "\nSetting up outgoing ICMPv4 ping blocking...\n"
            for icmptype in 3 4 11 0 8 ; do
                printf "\tACCEPTing outgoing ICMPv4 type %s...\n" "$icmptype"
                $prog -A OUTPUT -p icmp -m icmp --icmp-type $icmptype -j ACCEPT
            done
            printf "\tREJECTing all other outgoing ICMPv4 types...\n"
            $prog -A OUTPUT -p icmp \
                -j REJECT --reject-with icmp-host-unreachable
        fi

    elif [[ "$prog" == "$(which ip6tables)" ]] ; then
        printf "\nSetting up ICMPv6 rules...\n"

        ## We need at least icmpv6-destination-unreachable(1) and
        ## icmpv6-time-exceeded(3) in order to not break everything.
        ##
        ## For ping and traceroute you want echo-request(128) and
        ## echo-reply(129) enabled. You might be able to disable them, but it
        ## would probably break things.

        ## ICMPv6 type 1 := Destination Unreachable
        ## ICMPv6 type 3 := Time Exceeded
        ## ICMPv6 type 128 := Echo Request
        ## ICMPv6 type 129 := Echo Reply
        for icmptype in 1 3 128 129 ; do
            printf "\tACCEPTing incoming ICMPv6 type %s...\n" "$icmptype"
            $prog -A INPUT -p icmpv6 -m icmp6 --icmpv6-type $icmptype -j ACCEPT
        done

        ## To GLOBALLY BLOCK outgoing pings which are not types 0, 3, 4, 8, or
        ## 11, for Tor TransProxy, set IPv6_BLOCK_OUTGOING_PINGS=true
        if $IPv6_BLOCK_OUTGOING_PINGS ; then
            printf "\nSetting up outgoing ICMPv6 ping blocking...\n"
            for icmptype in 1 3 128 129 ; do
                printf "\tACCEPTing outgoing ICMPv6 type %s...\n" "$icmptype"
                $prog -A OUTPUT -p icmpv6 -m icmp6 --icmpv6-type $icmptype -j ACCEPT
            done
            printf "\tREJECTing all other outgoing ICMPv6 types...\n"
            $prog -A OUTPUT -p icmpv6 -j REJECT --reject-with address-unreachable
        fi

        ## Neighbour Discovery Protocol (NDP)
        ## ==================================
        ## XXX we should probably try to find a way to disable all the NDP
        ##     crap, once connected to a suitable router, but so far it seems
        ##     most commercial/home routers are too crappy to understand SEND:

        ## ICMPv6 type 134 := Router Advertisement (NDP)
        ## ---------------------------------------------
        ## Routers advertise their presence together with various link and
        ## Internet parameters either periodically, or in response to a Router
        ## Solicitation message.
        ##
        ## ICMPv6 type 135 := Neighbor Solicitation (NDP)
        ## ----------------------------------------------
        ## Used by nodes to determine the Link Layer address of a neighbor, or
        ## to verify that a neighbor is still reachable via a cached Link
        ## Layer address.
        ##
        ## ICMPv6 type 136 := Neighbor Advertisement (NDP)
        ## -----------------------------------------------
        ## Used by nodes to respond to a Neighbor Solicitation message
        ##
        ## ICMPv6 type 138 := Router Renumbering
        ## ---------------------------------------------------------------------
        printf "\nSetting up ICMPv6 NDP rules...\n"
        for ndptype in 134 135 136 138 ; do
            printf "\tACCEPTing incoming ICMPv6 type %s (NDP)...\n" "$ndptype"
            $prog -A INPUT -p icmpv6 -m icmp6 --icmpv6-type $ndptype -j ACCEPT
        done

        for ndptype in 134 135 136 138 ; do
            printf "\tACCEPTing outgoing ICMPv6 type %s (NDP)...\n" "$ndptype"
            $prog -A OUTPUT -p icmpv6 -m icmp6 --icmpv6-type $ndptype -j ACCEPT
        done

        ## SEND Protocol ICMPv6 NDP packets
        ## --------------------------------
        ## The Secure Neighbor Discovery (SEND) protocol is a security
        ## extension of the Neighbor Discovery Protocol (NDP) in IPv6 defined
        ## in RFC 3971 and updated by RFC 6494.
        ##
        ## The Neighbor Discovery Protocol (NDP) is responsible in IPv6 for
        ## discovery of other network nodes on the local link, to determine
        ## the link layer addresses of other nodes, and to find available
        ## routers, and maintain reachability information about the paths to
        ## other active neighbor nodes (RFC 4861). This protocol is insecure
        ## and susceptible to malicious interference. It is the intent of SEND
        ## to provide an alternate mechanism for securing NDP with a
        ## cryptographic method that is independent of IPsec, the original and
        ## inherent method of securing IPv6 communications.
        ##
        ## SEND uses Cryptographically Generated Addresses (CGA) and other new
        ## NDP options for the ICMPv6 packet types used in NDP.
        ## ---------------------------------------------------------------------
        ## ICMPv6 type 148 := Certification Path Solicitation
        ## ICMPv6 type 148 := Certification Path Advertisement
        printf "\nSetting up ICMPv6 SEND rules...\n"
        for sendtype in 148 149 ; do
            printf "\tACCEPTing incoming ICMPv6 type %s (SEND)...\n" "$sendtype"
            $prog -A INPUT -p icmpv6 -m icmp6 --icmpv6-type $sendtype -j ACCEPT
            printf "\tACCEPTing outgoing ICMPv6 type %s (SEND)...\n" "$sendtype"
            $prog -A OUTPUT -p icmpv6 -m icmp6 --icmpv6-type $sendtype -j ACCEPT
        done

        ## REJECT ALL OTHER ICMPV6 TYPES:
        printf "\nREJECTing all other ICMPv6 types...\n"
        $prog -A INPUT -p icmpv6 -m limit --limit 5/min --limit-burst 5000 \
            -j LOG --log-prefix "ICMPv6 !1,3,128-129,134-136,138,148-149: " --log-level 7
        $prog -A INPUT -p icmpv6 -j REJECT --reject-with icmp6-addr-unreachable
    fi

    ## ----------------
    ## TCP/UDP SETTINGS
    ## ----------------
    if $TRANSPROXY ; then
        if [[ "$prog" == "$(which iptables)" ]]; then
            printf "\nSetting up IPv4 Transproxy rules...\n"
            localaddr="127.0.0.1"
        elif [[ "$prog" == "$(which ip6tables)" ]] ; then
            printf "\nSetting up IPv6 Transproxy rules...\n"
            localaddr="::1"
        fi

        for user in $TRANSPROXY_USERS ; do

            ## ALLOW ANONYMOUS USER ACCESS TO Tor's ControlPort:
            if test -n "$TOR_CONTROL_PORTS"; then
                for tctrlp in $TOR_CONTROL_PORTS; do
                    printf "\tAllowing user %s access to ControlPort %s...\n" "$user" "$tctrlp"
                    $prog -t nat -A OUTPUT -p tcp -m owner --uid-owner $user \
                        -m tcp --syn -d $localaddr --dport $tctrlp -j ACCEPT
                done
            fi

            ## REDIRECT NON-LOOPBACK TCP TO TransPort:
            if test -n "$TOR_TRANS_PORTS"; then
                for ttransp in $TOR_TRANS_PORTS ; do
                    printf "\tRedirecting user %s TCP traffic to TransPort %s...\n" "$user" "$ttransp"
                    $prog -t nat -A OUTPUT ! -o lo -p tcp -m owner --uid-owner $user \
                        -m tcp -j REDIRECT --to-ports $ttransp
                done
            fi

            ## REDIRECT NON-LOOPBACK DNS TO DNSPort:
            if test -n "$TOR_DNS_PORTS"; then
                for tdnsp in $TOR_DNS_PORTS ; do
                    printf "\tRedirecting user %s UDP traffic to DNSPort %s...\n" "$user" "$tdnsp"
                    $prog -t nat -A OUTPUT ! -o lo -p udp \
                        -m owner --uid-owner $user -m udp --dport 53 \
                        -j REDIRECT --to-ports $tdnsp

                    ## AND THEN ALLOW THE TOR_DNS_PORT:
                    printf "\tAllowing incoming UDP to Tor DNSPort %s...\n" "$tdnsp"
                    $prog -A INPUT -p udp --dport $tdnsp -j ACCEPT
                    $prog -A INPUT -p udp --sport $tdnsp -j ACCEPT
                done
            fi

            ## ACCEPT OUTGOING TRAFFIC FOR ANONYMOUS ONLY FROM THE TransPort AND
            ## DNSPort:
            if test -n "$user"; then
                for ttransp in $TOR_TRANS_PORTS ; do
                    printf "\tAllowing outgoing TCP traffic for user %s to Tor TransPort %s...\n" "$user" "$ttransp"
                    $prog -t filter -A OUTPUT -p tcp -m owner --uid-owner $user \
                        -m tcp --dport $ttransp -j ACCEPT
                done

                for tdnsp in $TOR_DNS_PORTS ; do
                    printf "\tAllowing outgoing UDP traffic for user %s to Tor DNSPort %s...\n" "$user" "$tdnsp"
                    $prog -t filter -A OUTPUT -p udp -m owner --uid-owner $user \
                        -m udp --dport $tdnsp -j ACCEPT
                done
            fi

            ## DROP ALL OTHER TRAFFIC FOR USER ANONYMOUS:
            printf "\tLogging all other outgoing traffic for user %s...\n" "$user"
            $prog -t filter -A OUTPUT -m owner --uid-owner $user \
                -j LOG --log-prefix "iptables: TransProxy leak: " --log-level 7
            printf "\tDropping all other outgoing traffic for user %s...\n" "$user"
            $prog -t filter -A OUTPUT -m owner --uid-owner $user -j DROP
        done
    fi
}

red=$(tput setaf 9)
reset=$(tput sgr0)

if $CREATE_IPV4_RULES ; then
    printf "\nCreating IPv4 firewall rules...\n"
    transproxy $(which iptables)
fi

if $CREATE_IPV6_RULES ; then
    printf "\nCreating IPv6 firewall rules...\n"
    printf "%sWARNING:%s " "$red" "$reset"
    printf "The security of using an IPv6 Transproxy has not been fully "
    printf "evaluated! %sDO NOT RELY ON THIS FOR YOUR SECURITY.%s\n" "$red" "$reset"
    transproxy $(which ip6tables)
fi
