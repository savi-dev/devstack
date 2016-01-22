#!/bin/bash

        keystone endpoint-create \
            --region EDGE-TR-1 \
            --service_id 32a11458a2924db698a523998038425a \
            --publicurl "http://obj-tr-edge-1.savitestbed.ca:8080/v1/AUTH_\$(tenant_id)s" \
            --adminurl "http://10.10.32.11:8080" \
            --internalurl "http://10.10.32.11:8080/v1/AUTH_\$(tenant_id)s"

