#!/bin/bash
# MoonOS Installer - Locale Configuration
# Locale and language configuration

# Get available locales
get_available_locales() {
    local locales=()
    if [[ -f /usr/share/i18n/SUPPORTED ]]; then
        while IFS= read -r line; do
            locales+=("$line")
        done < /usr/share/i18n/SUPPORTED
    fi
    echo "${locales[@]}"
}

# Get available timezones
get_available_timezones() {
    local timezones=()
    if [[ -d /usr/share/zoneinfo ]]; then
        while IFS= read -r -d '' tz; do
            timezones+=("${tz#/usr/share/zoneinfo/}")
        done < <(find /usr/share/zoneinfo -type f -print0 | sort -z)
    fi
    echo "${timezones[@]}"
}

# Get available keyboards
get_available_keyboards() {
    local keyboards=(
        "us"
        "uk"
        "de"
        "fr"
        "it"
        "es"
        "pt"
        "nl"
        "be"
        "ch"
        "at"
        "dk"
        "no"
        "se"
        "fi"
        "pl"
        "cz"
        "sk"
        "hu"
        "ro"
        "bg"
        "hr"
        "si"
        "rs"
        "ua"
        "by"
        "ru"
        "jp"
        "kr"
        "cn"
        "tw"
    )
    echo "${keyboards[@]}"
}

# Configure locale
configure_locale() {
    ui_header "Locale Configuration"

    # Select locale
    echo "Available locales:"
    echo ""
    echo "  1) en_US.UTF-8 (English - United States)"
    echo "  2) en_GB.UTF-8 (English - United Kingdom)"
    echo "  3) de_DE.UTF-8 (German - Germany)"
    echo "  4) fr_FR.UTF-8 (French - France)"
    echo "  5) es_ES.UTF-8 (Spanish - Spain)"
    echo "  6) it_IT.UTF-8 (Italian - Italy)"
    echo "  7) pt_PT.UTF-8 (Portuguese - Portugal)"
    echo "  8) nl_NL.UTF-8 (Dutch - Netherlands)"
    echo "  9) Custom..."
    echo ""

    local choice
    while true; do
        echo -n "Select locale [1-9]: "
        read -r choice

        case "$choice" in
            1) INSTALL_CONFIG[locale]="en_US.UTF-8"; break ;;
            2) INSTALL_CONFIG[locale]="en_GB.UTF-8"; break ;;
            3) INSTALL_CONFIG[locale]="de_DE.UTF-8"; break ;;
            4) INSTALL_CONFIG[locale]="fr_FR.UTF-8"; break ;;
            5) INSTALL_CONFIG[locale]="es_ES.UTF-8"; break ;;
            6) INSTALL_CONFIG[locale]="it_IT.UTF-8"; break ;;
            7) INSTALL_CONFIG[locale]="pt_PT.UTF-8"; break ;;
            8) INSTALL_CONFIG[locale]="nl_NL.UTF-8"; break ;;
            9)
                echo -n "Enter locale (e.g., en_US.UTF-8): "
                read -r INSTALL_CONFIG[locale]
                break
                ;;
            *)
                echo "Invalid selection. Please try again."
                ;;
        esac
    done

    ui_message "Locale set to: ${INSTALL_CONFIG[locale]}"
}

# Configure timezone
configure_timezone() {
    ui_header "Timezone Configuration"

    echo "Common timezones:"
    echo ""
    echo "  1) UTC"
    echo "  2) America/New_York (Eastern Time)"
    echo "  3) America/Chicago (Central Time)"
    echo "  4) America/Denver (Mountain Time)"
    echo "  5) America/Los_Angeles (Pacific Time)"
    echo "  6) Europe/London (GMT)"
    echo "  7) Europe/Berlin (CET)"
    echo "  8) Europe/Paris (CET)"
    echo "  9) Asia/Tokyo (JST)"
    echo " 10) Asia/Shanghai (CST)"
    echo " 11) Custom..."
    echo ""

    local choice
    while true; do
        echo -n "Select timezone [1-11]: "
        read -r choice

        case "$choice" in
            1) INSTALL_CONFIG[timezone]="UTC"; break ;;
            2) INSTALL_CONFIG[timezone]="America/New_York"; break ;;
            3) INSTALL_CONFIG[timezone]="America/Chicago"; break ;;
            4) INSTALL_CONFIG[timezone]="America/Denver"; break ;;
            5) INSTALL_CONFIG[timezone]="America/Los_Angeles"; break ;;
            6) INSTALL_CONFIG[timezone]="Europe/London"; break ;;
            7) INSTALL_CONFIG[timezone]="Europe/Berlin"; break ;;
            8) INSTALL_CONFIG[timezone]="Europe/Paris"; break ;;
            9) INSTALL_CONFIG[timezone]="Asia/Tokyo"; break ;;
            10) INSTALL_CONFIG[timezone]="Asia/Shanghai"; break ;;
            11)
                echo -n "Enter timezone (e.g., America/New_York): "
                read -r INSTALL_CONFIG[timezone]
                break
                ;;
            *)
                echo "Invalid selection. Please try again."
                ;;
        esac
    done

    ui_message "Timezone set to: ${INSTALL_CONFIG[timezone]}"
}

# Configure keyboard
configure_keyboard() {
    ui_header "Keyboard Configuration"

    echo "Common keyboard layouts:"
    echo ""
    echo "  1) us (English - US)"
    echo "  2) uk (English - UK)"
    echo "  3) de (German)"
    echo "  4) fr (French)"
    echo "  5) it (Italian)"
    echo "  6) es (Spanish)"
    echo "  7) pt (Portuguese)"
    echo "  8) nl (Dutch)"
    echo "  9) Custom..."
    echo ""

    local choice
    while true; do
        echo -n "Select keyboard [1-9]: "
        read -r choice

        case "$choice" in
            1) INSTALL_CONFIG[keyboard]="us"; break ;;
            2) INSTALL_CONFIG[keyboard]="uk"; break ;;
            3) INSTALL_CONFIG[keyboard]="de"; break ;;
            4) INSTALL_CONFIG[keyboard]="fr"; break ;;
            5) INSTALL_CONFIG[keyboard]="it"; break ;;
            6) INSTALL_CONFIG[keyboard]="es"; break ;;
            7) INSTALL_CONFIG[keyboard]="pt"; break ;;
            8) INSTALL_CONFIG[keyboard]="nl"; break ;;
            9)
                echo -n "Enter keyboard layout (e.g., us): "
                read -r INSTALL_CONFIG[keyboard]
                break
                ;;
            *)
                echo "Invalid selection. Please try again."
                ;;
        esac
    done

    ui_message "Keyboard set to: ${INSTALL_CONFIG[keyboard]}"
}

# Configure hostname
configure_hostname() {
    ui_header "Hostname Configuration"

    echo "The hostname is used to identify your computer on the network."
    echo "It should be a simple name without spaces or special characters."
    echo ""

    local default_hostname="moonos"
    echo -n "Enter hostname [$default_hostname]: "
    read -r hostname

    INSTALL_CONFIG[hostname]="${hostname:-$default_hostname}"

    ui_message "Hostname set to: ${INSTALL_CONFIG[hostname]}"
}

# Create user account
create_user() {
    ui_header "User Account Creation"

    echo "Create a user account for日常 use."
    echo "This user will have sudo access."
    echo ""

    # Username
    local username
    while true; do
        echo -n "Enter username: "
        read -r username

        if [[ "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            break
        fi

        echo "Invalid username. Use lowercase letters, numbers, underscores, and hyphens."
    done

    INSTALL_CONFIG[username]="$username"

    # User password
    local password
    local password_confirm

    while true; do
        echo -n "Enter password for $username: "
        read -s password
        echo ""

        echo -n "Confirm password: "
        read -s password_confirm
        echo ""

        if [[ "$password" == "$password_confirm" ]]; then
            break
        fi

        echo "Passwords do not match. Please try again."
    done

    INSTALL_CONFIG[user_password]="$password"
}

# Confirm installation
confirm_install() {
    ui_header "Installation Summary"

    echo "Please review the installation settings:"
    echo ""
    echo "  Disk:          ${INSTALL_CONFIG[target_disk]}"
    echo "  Hostname:      ${INSTALL_CONFIG[hostname]}"
    echo "  Timezone:      ${INSTALL_CONFIG[timezone]}"
    echo "  Locale:        ${INSTALL_CONFIG[locale]}"
    echo "  Keyboard:      ${INSTALL_CONFIG[keyboard]}"
    echo "  Username:      ${INSTALL_CONFIG[username]}"
    echo "  Desktop:       ${INSTALL_CONFIG[desktop]}"
    echo ""
    echo "  WARNING: All data on ${INSTALL_CONFIG[target_disk]} will be lost!"
    echo ""

    if ! ui_yesno "Proceed with installation?"; then
        echo "Installation cancelled."
        exit 0
    fi
}
