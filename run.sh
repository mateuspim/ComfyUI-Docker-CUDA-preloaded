#!/bin/bash
# Pre-create bind-mount directories so Docker doesn't create them as root
mkdir -p models custom_nodes/.last_commits output input workflows

docker compose up
