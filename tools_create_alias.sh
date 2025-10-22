#!/bin/bash

# ==============================================================================
# Script: tools_create_alias.sh
# Description: Tools sederhana create alias
# Author: Salman Mustapa
# ==============================================================================

#Settings Color
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'
BOLD='\033[1m'

# Banner Asci View
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════╗"
echo "║         🔥 CREATE ALIAS - Bash Style 🔥       ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${RESET}"

# Input alias name
read -p "Input Alias Name: " alias_name
if [[ -z "$alias_name" ]]; then
	echo -e "${RED} Alias name cannot be empty!${RESET}"
	exit 1
fi

# Input alias command
read -p "Input Command: " alias_command
if [[ -z "$alias_command" ]]; then
	echo -e "${RED} Command cannot be empty!${RESET}"
	exit 1
fi

# Create Aias in New Line
echo "" >> ~/.bashrc
echo "alias $alias_name=\"$alias_command\"" >> ~/.bashrc

# Terapkan Perubahan
echo -e "${CYAN}"
echo -e "Save Configuration bashrc ...${RESET}"
save

# Show Summary
echo -e "${GREEN}"
echo -e "✅ Successful add alias"
echo -e "You can run with: ${BOLD}$alias_name${RESET}"
echo -e "${CYAN}---------------------------------------------${RESET}"
echo -e "${BOLD}🎉 Enjoy your new alias, keep_learn!${RESET}"






