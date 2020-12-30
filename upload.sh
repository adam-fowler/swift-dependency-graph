#!/bin/sh

export AWS_PROFILE=website-admin

aws s3 sync html/ s3://swift-dependency-graph.com/
