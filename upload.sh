#!/bin/sh

aws s3 sync html/ s3://swift-dependency-graph.com/
