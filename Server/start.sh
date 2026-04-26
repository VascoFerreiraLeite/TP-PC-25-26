#!/bin/bash

echo "Compiling Erlang files..."
# This compiles every .erl file in the folder into .beam files instantly
erlc *.erl 

echo "Booting Server..."
# This starts the Erlang shell AND automatically runs the supervisor!
erl -eval "main_supervisor:start_link()."