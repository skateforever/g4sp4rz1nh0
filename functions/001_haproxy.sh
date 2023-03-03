#!/bin/bash

haproxy_create_file(){
# Haproxy
echo "global
    daemon
    maxconn 2000
    maxcompcpuusage 50
    spread-checks 5

defaults
    timeout connect ${MINIMUM_TIMEOUT}s
    timeout server ${MINIMUM_TIMEOUT}s
    timeout client ${MINIMUM_TIMEOUT}s
    timeout check ${MINIMUM_TIMEOUT}s

userlist L1
    group G1 users ${USER_ID}
    user ${USER_ID} insecure-password ${MASTER_PROXY_PASSWORD}
    
listen stats
	bind  ${HAPROXY_LISTEN_ADDR}:${HAPROXY_MASTER_PROXY_STAT_PORT}
    mode http
	stats  auth ${USER_ID}:${HAPROXY_MASTER_PROXY_STAT_PWD}
    stats  enable
    stats  hide-version
    stats  realm Ghost\ Busters
    stats  uri ${HAPROXY_MASTER_PROXY_STAT_URI}
    #stats socket ${HAPROXY_DIR_TEMP_FILES=}/haproxy_stats.sock mode 600 level admin
    stats refresh 5s

frontend MASTER_SOCKS
    bind ${HAPROXY_LISTEN_ADDR}:${HAPROXY_MASTER_SOCKS_PORT}
    default_backend TOR_INSTANCES
    
frontend MASTER_PROXY
    bind ${HAPROXY_LISTEN_ADDR}:${HAPROXY_MASTER_PROXY_PORT}
    default_backend PRIVOXY_INSTANCES
    mode http
    #option http_proxy
    $( if [ "${INCLUDE_SECURITY_HEADERS_IN_HTTP_RESPONSE}" = "yes" ]; then
    echo "#http-response del-header X-Frame-Options
    http-response del-header X-XSS-Protection
    http-response del-header X-Content-Type-Options
    http-response del-header Strict-Transport-Security
    http-response del-header Referrer-Policy
    http-response set-header X-Frame-Options DENY
    http-response set-header X-XSS-Protection 1;mode=block
    http-response set-header X-Content-Type-Options nosniff
    http-response set-header Strict-Transport-Security max-age=31536000;includeSubDomains;preload
    http-response set-header Referrer-Policy no-referrer-when-downgrade"
    fi )
    ###################### HTTP HEADER TOR BROWNSER SPOOFING FOR HTTP SITES ######################
    #                                                                                            #
    #            Rewrite the http header to looks like a normal TOR BRONSER Header.              3
    #                                                                                            #
    ##############################################################################################  
    http-request del-header X-Forwarded-For
    http-request del-header x-forwarded-for
    http-request del-header Proxy-Connection
    http-request del-header Upgrade-Insecure-Requests
    http-request del-header Accept-Language
    http-request del-header Accept-Encoding
    http-request del-header Connection
    http-request del-header Pragma
    http-request del-header Cache-Control
    http-request del-header User-Agent
    http-request del-header Accept
    http-request del-header DNT
    http-request add-header User-Agent \"${SPOOFED_USER_AGENT}\"
    http-request add-header Accept text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
    http-request add-header Accept-Language en-US,en;q=0.5
    http-request add-header Accept-Encoding gzip,\ deflate
    http-request add-header Connection keep-alive
    http-request add-header Upgrade-Insecure-Requests 1" > "${HAPROXY_MASTER_PROXY_CFG}"
}

haproxy_tor_backend(){
echo "
backend TOR_INSTANCES
    mode tcp
    retries $((RETRIES * COUNTRIES * TOR_INSTANCES))
    balance ${LOAD_BALANCE_ALGORITHM}" >> "${HAPROXY_MASTER_PROXY_CFG}"
}

haproxy_privoxy_backend(){
echo "
backend PRIVOXY_INSTANCES
    retries $((RETRIES * COUNTRIES * TOR_INSTANCES))
    option redispatch
    option http-server-close
    mode http
    http-reuse ${HAPROXY_HTTP_REUSE}
    # Health Check request header spoffing the TOR Brownser header
    balance ${LOAD_BALANCE_ALGORITHM}
    option httpchk GET ${HEALTH_CHECK_URL} HTTP/1.1
    http-check send hdr Host $(echo "${HEALTH_CHECK_URL}" | cut -d ":" -f 2 | sed 's|/||g') hdr User-Agent \"${SPOOFED_USER_AGENT}\" hdr Accept \"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\" hdr Accept-Language \"en-US,en;q=0.5\" hdr Accept-Encoding \"gzip, deflate\" hdr Connection keep-alive hdr Upgrade-Insecure-Requests 1
    default-server error-limit 1 on-error mark-down" >> "${HAPROXY_MASTER_PROXY_CFG}"
}

haproxy_startup(){
# Startup the HAProxy
if [ -s "${HAPROXY_MASTER_PROXY_CFG}" ]; then
    # Executing the MASTER PROXY
    ${HAPROXY_PATH} -f "${HAPROXY_MASTER_PROXY_CFG}" >> "${g4sp4rz1nh0_startup_log}" 2>&1 &
else
    echo "The ${HAPROXY_MASTER_PROXY_CFG} file does not exist!"
    echo "Please check what happened!"
    exit 1
fi
}
