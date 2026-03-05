#!/bin/bash

cp -r .i3status/ ~/.config/bin/
chmod +x workspace-app-launcher.sh
i3-msg reload
i3-msg restart
