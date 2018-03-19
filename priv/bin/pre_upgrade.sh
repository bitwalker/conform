#!/bin/sh

# Set CONFORM_SCHEMA_PATH, the path to the schema.exs file to use
# Use $RELEASE_CONFIG_DIR/$REL_NAME.schema.exs if exists, otherwise releases/VSN/$REL_NAME.schema.exs
if [ -z "$CONFORM_SCHEMA_PATH" ]; then
    if [ -f "$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs" ]; then
        CONFORM_SCHEMA_PATH="$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs"
    else
        CONFORM_SCHEMA_PATH="$REL_DIR/../$TARGET_VERSION/$REL_NAME.schema.exs"
    fi
fi

# Set CONFORM_CONF_PATH, the path to the .conf file to use
# Use $RELEASE_CONFIG_DIR/$REL_NAME.conf if exists, otherwise releases/VSN/$REL_NAME.conf
if [ -z "$CONFORM_CONF_PATH" ]; then
    if [ -f "$RELEASE_CONFIG_DIR/$REL_NAME.conf" ]; then
        CONFORM_CONF_PATH="$RELEASE_CONFIG_DIR/$REL_NAME.conf"
    else
        CONFORM_CONF_PATH="$REL_DIR/../$TARGET_VERSION/$REL_NAME.conf"
    fi
fi

__schema_destination="$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs"
__conf_destination="$RELEASE_CONFIG_DIR/$REL_NAME.conf"

# Convert .conf to sys.config using conform escript
if [ -f "$CONFORM_SCHEMA_PATH" ]; then
    if [ -f "$CONFORM_CONF_PATH" ]; then
        EXTRA_OPTS="$EXTRA_OPTS -conform_schema ${CONFORM_SCHEMA_PATH} -conform_config $CONFORM_CONF_PATH"

        # Backup original sys.config, it will be moved back in post_upgrade.sh
        cp "$REL_DIR/../$TARGET_VERSION/sys.config" "$REL_DIR/../$TARGET_VERSION/sys.config.bak"

        __conform="$REL_DIR/../$TARGET_VERSION/conform"
        # Clobbers input sys.config
        if ! result="$("$BINDIR/escript" "$__conform" --conf "$CONFORM_CONF_PATH" --schema "$CONFORM_SCHEMA_PATH" --config "$REL_DIR/../$TARGET_VERSION/sys.config" --output-dir "$REL_DIR/../$TARGET_VERSION")"; then
            exit_status="$?"
            echo "Error reading $CONFORM_CONF_PATH . This may be due to syntax errors or unquoted values" >&2
            echo "The parser reported:" >&2
            echo "$result" >&2
            exit "$exit_status"
        fi
        tmpfile=$(mktemp "${SYS_CONFIG_PATH}.XXXXXX")
        echo "%%Generated - edit $RELEASE_CONFIG_DIR/$REL_NAME.conf or $RELEASE_CONFIG_DIR/$REL_NAME.conf/sys.config" >> "$tmpfile"
        cat "$REL_DIR/../$TARGET_VERSION/sys.config" >> $tmpfile
        mv "$tmpfile" "${SYS_CONFIG_PATH}"
    else
        echo "missing .conf, expected it at $CONFORM_CONF_PATH"
        exit 1
    fi
fi
