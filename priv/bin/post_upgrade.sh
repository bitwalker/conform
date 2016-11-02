#!/bin/sh

if [ -f "$REL_DIR/../$TARGET_VERSION/sys.config.bak" ]; then
    mv "$REL_DIR/../$TARGET_VERSION/sys.config.bak" "$REL_DIR/../$TARGET_VERSION/sys.config"
fi
