#!/bin/bash
#
# Initial data for Keystone using python-keystoneclient
#
# Tenant               User      Roles
# ------------------------------------------------------------------
# admin                admin     admin
# service              glance    admin
# service              nova      admin, [ResellerAdmin (swift only)]
# service              cheetah   admin
# service              quantum   admin        # if enabled
# service              heat      admin        # if enabled
# service              swift     admin        # if enabled
# service              cinder    admin        # if enabled
# demo                 admin     admin
# demo                 demo      Member, anotherrole
# invisible_to_admin   demo      Member
# Tempest Only:
# alt_demo             alt_demo  Member
#
# Variables set before calling this script:
# SERVICE_TOKEN - aka admin_token in keystone.conf
# SERVICE_ENDPOINT - local Keystone admin endpoint
# SERVICE_TENANT_NAME - name of tenant containing service accounts
# SERVICE_HOST - host used for endpoint creation
# ENABLED_SERVICES - stack.sh's list of services to start
# DEVSTACK_DIR - Top-level DevStack directory
# KEYSTONE_CATALOG_BACKEND - used to determine service catalog creation

# Defaults
# --------
REGION_NAME=${REGION_NAME:-CORE}
KEYSTONE_TYPE=${KEYSTONE_TYPE:-LOCAL}
SAVI_PASSWORD=${SAVI_PASSWORD:-supersecret}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-secrete}
SERVICE_PASSWORD=${SERVICE_PASSWORD:-$ADMIN_PASSWORD}
export SERVICE_TOKEN=$SERVICE_TOKEN
export SERVICE_ENDPOINT=$SERVICE_ENDPOINT
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}

function get_id () {
    echo `"$@" | awk '/ id / { print $4 }'`
}
if [[ "$KEYSTONE_TYPE" = "LOCAL" ]]; then
# Tenants
# -------
  SAVI_TENANT=$(get_id keystone tenant-create --name=savi)
  ADMIN_TENANT=$(get_id keystone tenant-create --name=admin)
  SERVICE_TENANT=$(get_id keystone tenant-create --name=$SERVICE_TENANT_NAME)
  DEMO_TENANT=$(get_id keystone tenant-create --name=demo1)
  DEMO_TENANT2=$(get_id keystone tenant-create --name=demo2)
  INVIS_TENANT=$(get_id keystone tenant-create --name=invisible_to_admin)


# Users
# -----

  SAVI_USER=$(get_id keystone user-create --name=savi \
                                         --pass="$SAVI_PASSWORD" \
                                         --email=savi@savinetwork.ca)
  ADMIN_USER=$(get_id keystone user-create --name=admin \
                                         --pass="$ADMIN_PASSWORD" \
                                         --email=admin@savinetwork.ca)
  DEMO_USER=$(get_id keystone user-create --name=demo \
                                        --pass="$ADMIN_PASSWORD" \
                                        --email=demo@savinetwork.ca)


# Roles
# -----

  SAVI_ROLE=$(get_id keystone role-create --name=savi)
  ADMIN_ROLE=$(get_id keystone role-create --name=admin)
  KEYSTONEADMIN_ROLE=$(get_id keystone role-create --name=KeystoneAdmin)
  KEYSTONESERVICE_ROLE=$(get_id keystone role-create --name=KeystoneServiceAdmin)
# ANOTHER_ROLE demonstrates that an arbitrary role may be created and used
# TODO(sleepsonthefloor): show how this can be used for rbac in the future!
  ANOTHER_ROLE=$(get_id keystone role-create --name=anotherrole)

#Services
#Cheetah
  CHEETAH_SERVICE=$(get_id keystone service-create \
    --name=cheetah \
    --type=control \
    --description="Cheetah Control Service")


#keystone
  KEYSTONE_SERVICE=$(get_id keystone service-create \
    --name=keystone \
    --type=identity \
    --description="Keystone Identity Service")


#Nova
#  if [[ "$ENABLED_SERVICES" =~ "n-cpu" ]]; then

    NOVA_USER=$(get_id keystone user-create \
        --name=nova \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=nova@example.com)
    keystone user-role-add \
          --tenant_id $SERVICE_TENANT \
          --user_id $NOVA_USER \
          --role_id $ADMIN_ROLE

    NOVA_SERVICE=$(get_id keystone service-create \
            --name=nova \
            --type=compute \
            --description="Nova Compute Service")

    RESELLER_ROLE=$(get_id keystone role-create --name=ResellerAdmin)
      keystone user-role-add \
          --tenant_id $SERVICE_TENANT \
          --user_id $NOVA_USER \
          --role_id $RESELLER_ROLE
#  fi
#Volume
  if [[ "$ENABLED_SERVICES" =~ "n-vol" ]]; then
     VOLUME_SERVICE=$(get_id keystone service-create \
            --name=volume \
            --type=volume \
            --description="Volume Service")

  fi

#Glance
#  if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
      GLANCE_USER=$(get_id keystone user-create \
        --name=glance \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=glance@example.com)
      keystone user-role-add \
          --tenant_id $SERVICE_TENANT \
          --user_id $GLANCE_USER \
          --role_id $ADMIN_ROLE
      GLANCE_SERVICE=$(get_id keystone service-create \
            --name=glance \
            --type=image \
            --description="Glance Image Service")
#  fi

#Swift
#  if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
      SWIFT_USER=$(get_id keystone user-create \
        --name=swift \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=swift@example.com)
      keystone user-role-add \
          --tenant_id $SERVICE_TENANT \
          --user_id $SWIFT_USER \
          --role_id $ADMIN_ROLE
     SWIFT_SERVICE=$(get_id keystone service-create \
            --name=swift \
            --type="object-store" \
            --description="Swift Service")

#  fi

#Quantum
#  if [[ "$ENABLED_SERVICES" =~ "q-svc" ]]; then
      QUANTUM_USER=$(get_id keystone user-create \
        --name=quantum \
        --pass="$SERVICE_PASSWORD" \
        --tenant_id $SERVICE_TENANT \
        --email=quantum@example.com)
      keystone user-role-add \
          --tenant_id $SERVICE_TENANT \
          --user_id $QUANTUM_USER \
          --role_id $ADMIN_ROLE
      QUANTUM_SERVICE=$(get_id keystone service-create \
            --name=quantum \
            --type=network \
            --description="Quantum Service")
#  fi

#EC2
#  if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
          EC2_SERVICE=$(get_id keystone service-create \
            --name=ec2 \
            --type=ec2 \
            --description="EC2 Compatibility Layer")
#  fi


#S3
  if [[ "$ENABLED_SERVICES" =~ "n-obj" || "$ENABLED_SERVICES" =~ "swift" ]]; then
          S3_SERVICE=$(get_id keystone service-create \
            --name=s3 \
            --type=s3 \
            --description="S3")
  fi

#Temest
  if [[ "$ENABLED_SERVICES" =~ "tempest" ]]; then
      # Tempest has some tests that validate various authorization checks
      # between two regular users in separate tenants
      ALT_DEMO_TENANT=$(get_id keystone tenant-create \
        --name=alt_demo)
      ALT_DEMO_USER=$(get_id keystone user-create \
        --name=alt_demo \
        --pass="$ADMIN_PASSWORD" \
        --email=alt_demo@example.com)
      keystone user-role-add \
          --tenant_id $ALT_DEMO_TENANT \
          --user_id $ALT_DEMO_USER \
          --role_id $MEMBER_ROLE
  fi

#Cinder
#  if [[ "$ENABLED_SERVICES" =~ "c-api" ]]; then
      CINDER_USER=$(get_id keystone user-create --name=cinder \
                                              --pass="$SERVICE_PASSWORD" \
                                              --tenant_id $SERVICE_TENANT \
                                              --email=cinder@example.com)
      keystone user-role-add --tenant_id $SERVICE_TENANT \
                             --user_id $CINDER_USER \
                             --role_id $ADMIN_ROLE
      CINDER_SERVICE=$(get_id keystone service-create \
            --name=cinder \
            --type=volume \
            --description="Cinder Service")
#  fi

#Heat
if [[ "$ENABLED_SERVICES" =~ "heat" ]]; then
HEAT_USER=$(get_id keystone user-create --name=heat \
                                              --pass="$SERVICE_PASSWORD" \
                                              --tenant_id $SERVICE_TENANT \
                                              --email=heat@example.com)
    keystone user-role-add --tenant_id $SERVICE_TENANT \
                           --user_id $HEAT_USER \
                           --role_id $ADMIN_ROLE
fi

# Add Roles to Users in Tenants

  keystone user-role-add --user_id $SAVI_USER --role_id $SAVI_ROLE --tenant_id $SAVI_TENANT
  keystone user-role-add --user_id $ADMIN_USER --role_id $ADMIN_ROLE --tenant_id $ADMIN_TENANT
  keystone user-role-add --user_id $ADMIN_USER --role_id $ADMIN_ROLE --tenant_id $DEMO_TENANT
  keystone user-role-add --user_id $ADMIN_USER --role_id $ADMIN_ROLE --tenant_id $DEMO_TENANT2
  keystone user-role-add --user_id $DEMO_USER --role_id $ANOTHER_ROLE --tenant_id $DEMO_TENANT

# TODO(termie): these two might be dubious
  keystone user-role-add --user_id $ADMIN_USER --role_id $KEYSTONEADMIN_ROLE --tenant_id $ADMIN_TENANT
  keystone user-role-add --user_id $ADMIN_USER --role_id $KEYSTONESERVICE_ROLE --tenant_id $ADMIN_TENANT


# The Member role is used by Horizon and Swift so we need to keep it:
  MEMBER_ROLE=$(get_id keystone role-create --name=Member)
  keystone user-role-add --user_id $DEMO_USER --role_id $MEMBER_ROLE --tenant_id $DEMO_TENANT
  keystone user-role-add --user_id $DEMO_USER --role_id $MEMBER_ROLE --tenant_id $INVIS_TENANT

else
  if [[ "$ENABLED_SERVICES" =~ "c-control" ]]; then
    CHEETAH_SERVICE = $(keystone service-id cheetah)
  fi
  if [[ "$ENABLED_SERVICES" =~ "key" ]]; then
    KEYSTONE_SERVICE=$(keystone service-id keystone)
  fi
  if [[ "$ENABLED_SERVICES" =~ "n-cpu" ]]; then
    NOVA_SERVICE=$(keystone service-id nova)
  fi
  if [[ "$ENABLED_SERVICES" =~ "n-vol" ]]; then
    VOLUME_SERVICE=$(keystone service-id volume)
  fi
  if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
    GLANCE_SERVICE=$(keystone service-id glance)
  fi
  if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    SWIFT_SERVICE=$(keystone service-id swift)
  fi
  if [[ "$ENABLED_SERVICES" =~ "q-svc" ]]; then
    QUANTUM_SERVICE=$(keystone service-id quantum)
  fi
  if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    EC2_SERVICE=$(keystone service-id ec2)
  fi
  if [[ "$ENABLED_SERVICES" =~ "n-obj" || "$ENABLED_SERVICES" =~ "swift" ]]; then
    S3_SERVICE=$(keystone service-id s3)
  fi
  if [[ "$ENABLED_SERVICES" =~ "c-api" ]]; then
    CINDER_SERVICE=$(keystone service-id cinder)
  fi
  if [[ "$ENABLED_SERVICES" =~ "heat" ]]; then
    CINDER_SERVICE=$(keystone service-id heat)
  fi
fi


# Endpoints
# --------
# Keystone
if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
 if [[ "$KEYSTONE_TYPE" = 'LOCAL' ]]; then
    IFS=","
    for region in $REGIONS
    do
       keystone endpoint-create \
        --region $region \
      --service_id $KEYSTONE_SERVICE \
      --publicurl "http://$KEYSTONE_SERVICE_HOST:\$(public_port)s/v2.0" \
      --adminurl "http://$KEYSTONE_SERVICE_HOST:\$(admin_port)s/v2.0" \
      --internalurl "http://$KEYSTONE_SERVICE_HOST:\$(public_port)s/v2.0"
    done
   fi
fi
# Nova
if [[ "$ENABLED_SERVICES" =~ "n-cpu" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $NOVA_SERVICE \
            --publicurl "http://$SERVICE_HOST:\$(compute_port)s/v2/\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:\$(compute_port)s/v2/\$(tenant_id)s" \
            --internalurl "http://$SERVICE_HOST:\$(compute_port)s/v2/\$(tenant_id)s"
    fi
    # Nova needs ResellerAdmin role to download images when accessing
    # swift through the s3 api. The admin role in swift allows a user
    # to act as an admin for their tenant, but ResellerAdmin is needed
    # for a user to act as any tenant. The name of this role is also
    # configurable in swift-proxy.conf
fi

# Volume
if [[ "$ENABLED_SERVICES" =~ "n-vol" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $VOLUME_SERVICE \
            --publicurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s" \
            --internalurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s"
    fi
fi

#Heat
if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
   if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $HEAT_CFN_SERVICE \
            --publicurl "http://$SERVICE_HOST:$HEAT_API_CFN_PORT/v1" \
            --adminurl "http://$SERVICE_HOST:$HEAT_API_CFN_PORT/v1" \
            --internalurl "http://$SERVICE_HOST:$HEAT_API_CFN_PORT/v1"
    fi
fi

# Glance
if [[ "$ENABLED_SERVICES" =~ "g-api" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $GLANCE_SERVICE \
            --publicurl "http://$SERVICE_HOST:9292/v1" \
            --adminurl "http://$SERVICE_HOST:9292/v1" \
            --internalurl "http://$SERVICE_HOST:9292/v1"
    fi
fi

# Swift
if [[ "$ENABLED_SERVICES" =~ "swift" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $SWIFT_SERVICE \
            --publicurl "http://$SERVICE_HOST:8080/v1/AUTH_\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:8080/v1" \
            --internalurl "http://$SERVICE_HOST:8080/v1/AUTH_\$(tenant_id)s"
    fi
fi

if [[ "$ENABLED_SERVICES" =~ "q-svc" ]]; then
   if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $QUANTUM_SERVICE \
            --publicurl "http://$SERVICE_HOST:9696/" \
            --adminurl "http://$SERVICE_HOST:9696/" \
            --internalurl "http://$SERVICE_HOST:9696/"
    fi
fi

# EC2
if [[ "$ENABLED_SERVICES" =~ "n-api" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $EC2_SERVICE \
            --publicurl "http://$SERVICE_HOST:8773/services/Cloud" \
            --adminurl "http://$SERVICE_HOST:8773/services/Admin" \
            --internalurl "http://$SERVICE_HOST:8773/services/Cloud"
    fi
fi

# S3
if [[ "$ENABLED_SERVICES" =~ "n-obj" || "$ENABLED_SERVICES" =~ "swift" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $S3_SERVICE \
            --publicurl "http://$SERVICE_HOST:$S3_SERVICE_PORT" \
            --adminurl "http://$SERVICE_HOST:$S3_SERVICE_PORT" \
            --internalurl "http://$SERVICE_HOST:$S3_SERVICE_PORT"
    fi
fi

if [[ "$ENABLED_SERVICES" =~ "c-api" ]]; then
    if [[ "$KEYSTONE_CATALOG_BACKEND" = 'sql' ]]; then
        keystone endpoint-create \
            --region ${REGION_NAME} \
            --service_id $CINDER_SERVICE \
            --publicurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s" \
            --adminurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s" \
            --internalurl "http://$SERVICE_HOST:8776/v1/\$(tenant_id)s"
    fi
fi

ls

