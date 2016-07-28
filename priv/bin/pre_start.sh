#!/bin/sh

# Set CONFORM_SCHEMA_PATH, the path to the schema.exs file to use
# Use $RELEASE_CONFIG_DIR/$REL_NAME.schema.exs if exists, otherwise releases/VSN/$REL_NAME.schema.exs
if [ -z "$CONFORM_SCHEMA_PATH" ]; then
    if [ -f "$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs" ]; then
        CONFORM_SCHEMA_PATH="$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs"
    else
        CONFORM_SCHEMA_PATH="$REL_DIR/$REL_NAME.schema.exs"
    fi
fi

# Set CONFORM_CONF_PATH, the path to the .conf file to use
# Use $RELEASE_CONFIG_DIR/$REL_NAME.conf if exists, otherwise releases/VSN/$REL_NAME.conf
if [ -z "$CONFORM_CONF_PATH" ]; then
    if [ -f "$RELEASE_CONFIG_DIR/$REL_NAME.conf" ]; then
        CONFORM_CONF_PATH="$RELEASE_CONFIG_DIR/$REL_NAME.conf"
    else
        CONFORM_CONF_PATH="$REL_DIR/$REL_NAME.conf"
    fi
fi

__schema_destination="$RELEASE_CONFIG_DIR/$REL_NAME.schema.exs"
__conf_destination="$RELEASE_CONFIG_DIR/$REL_NAME.conf"

# Convert .conf to sys.config using conform escript
if [ -f "$CONFORM_SCHEMA_PATH" ]; then
    if [ -f "$CONFORM_CONF_PATH" ]; then
        EXTRA_OPTS="$EXTRA_OPTS -conform_schema ${CONFORM_SCHEMA_PATH} -conform_config $CONFORM_CONF_PATH"

        __conform="$REL_DIR/conform"
        result="$("$BINDIR/escript" "$__conform" --conf "$CONFORM_CONF_PATH" --schema "$CONFORM_SCHEMA_PATH" --config "$SYS_CONFIG_PATH" --output-dir "$RELEASE_CONFIG_DIR")"
        exit_status="$?"
        if [ "$exit_status" -ne 0 ]; then
            exit "$exit_status"
        fi
        if [ ! -r "$RELEASE_CONFIG_DIR/sys.config" ]; then
            echo "conform succeeded, but no sys.config was generated at \"${RELEASE_CONFIG_DIR}/sys.config\"."
            exit 1
        fi
        SYS_CONFIG_PATH="$RELEASE_CONFIG_DIR/sys.config"
    else
        echo "missing .conf, expected it at $CONFORM_CONF_PATH"
        exit 1
    fi
fi
