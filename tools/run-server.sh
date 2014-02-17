#!/bin/bash
nova boot --key-name $3 --image $2 --flavor $1 --security-groups default $4
