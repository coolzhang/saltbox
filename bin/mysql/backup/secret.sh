#!/bin/bash

realpass="{{ admin_password }}"
if [ $SECRET = "pass4db" ];then
SECRET=$realpass
fi
