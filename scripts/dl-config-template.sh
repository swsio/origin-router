#!/bin/bash

docker run --entrypoint=/bin/cat --rm -ti openshift/origin-haproxy-router:v3.11.0 /var/lib/haproxy/conf/haproxy-config.template > haproxy-config.template
