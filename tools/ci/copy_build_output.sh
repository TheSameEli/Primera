#!/bin/bash

mkdir -p \
    $1/icons \
    $1/tgui/public \

cp tgstation.dmb tgstation.rsc $1/
cp -r icons/* $1/icons/
cp -r tgui/public/* $1/tgui/public/

# BANDASTATION ADDITION START - Bundle generated Russian names for runtime consumers.
mkdir -p $1/modular_bandastation/translations/public
cp modular_bandastation/translations/public/ru_names.toml $1/modular_bandastation/translations/public/
# BANDASTATION ADDITION END
