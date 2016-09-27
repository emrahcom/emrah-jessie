#!/bin/bash

apt-get update && apt-get autoclean && apt-get -dy dist-upgrade && \
    apt-get dist-upgrade && apt-get autoremove --purge
