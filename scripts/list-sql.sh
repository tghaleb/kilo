#!/bin/sh
ls -1 sql/ | sed  's@\(.*\).sql@sql_\1: "sql/\1.sql",@g'
