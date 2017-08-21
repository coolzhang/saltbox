#!/bin/bash

realpass="{{ backup_password }}"
if [ $SECRET = "pass4db" ];then
SECRET=$realpass
fi
