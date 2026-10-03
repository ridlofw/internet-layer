# ==============================================================================
# Makefile - IoT Internet Layer Simulation
# Shortcuts for lab deployment, verification, and service execution
# ==============================================================================

SHELL := /bin/bash

.PHONY: help up down status test server client clean lint

help:
	@echo "IoT Internet Layer Laboratory Management"
	@echo "-----------------------------------------"
	@echo "make up      : Deploy dual-stack topology (sudo)"
	@echo "make down    : Teardown lab namespaces cleanly (sudo)"
	@echo "make status  : Display interface IP and routing tables"
	@echo "make test    : Run automated connectivity verification suite"
	@echo "make server  : Launch IPv6 HTTP server inside 'iot-cloud'"
	@echo "make client  : Execute IPv6 HTTP socket client inside 'iot-sensor'"
	@echo "make clean   : Alias for make down"
	@echo "make lint    : Run syntax and style checks on bash/python"

up:
	sudo bash scripts/network_lab.sh up

down:
	sudo bash scripts/network_lab.sh down

status:
	sudo bash scripts/network_lab.sh status

test:
	sudo bash scripts/verify_connectivity.sh

server:
	sudo ip netns exec iot-cloud python3 scripts/ipv6_http_server.py

client:
	sudo ip netns exec iot-sensor python3 scripts/ipv6_http_client.py

clean: down

lint:
	@echo "Checking Python files..."
	python3 -m py_compile scripts/*.py
	@echo "All Python scripts syntax check PASSED."
