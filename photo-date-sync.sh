#!/bin/bash

print_help() {
    echo -e "
$(c_yellow_regular NAME)

    photo-date-sync - Media file date sync script.

$(c_yellow_regular SYNOPSIS)

    $(c_white_underline photo-date-sync) [-i | --input DIRECTORY] [-t | --test]
                    [-d | --debug] [-h | --help]

$(c_yellow_regular DESCRIPTION)

    Sync media file date based on the file name. File name should be in the
    format 'ABC_YYYYMMDD_hhmmss_XYZ' where:

         ABC - any prefix text (i.e. 'IMG', 'VID', 'FILE', etc.)
        YYYY - year, 4 numbers (0000 - 9999)
          MM - month, 2 numbers (01 - 12)
          DD - day, 2 numbers (01 - 31)
          hh - hour, 2 numbers (00 - 24)
          mm - minutes, 2 numbers (00 - 59)
          ss - seconds, 2 numbers (00 - 59)
         XYZ - any suffix text (i.e. '0001', 'edited', 'copy', etc.)

    Required dependency tools for the script operation:

    sudo apt install libimage-exiftool-perl

$(c_yellow_regular OPTIONS)

    -i, --input DIRECTORY
        Input directory to process all media files inside. Script will
        recursively check all media files inside. Current directory if not
        provided.

    -t, --test
        Test mode. No actual changes to the files would be made. Script will
        only print any planned changes. Useful for the test run.

    -d, --debug
        Debug mode. Print all debug information.

    -h, --help
        Print this help message.
"
}

ctrl_c() {
    echo
    warn "Script canceled with CTRL+C"
    exit_failure
}

parse_command_line() {
    local long_opts="input:,test,debug,help"
    local short_opts="i:tdh"
    local getopt_cmd
    getopt_cmd=$(getopt -o ${short_opts} --long "${long_opts}" -q -n $(basename ${0}) -- "${@}")

    if [[ ${?} -ne 0 ]]; then
        error "Getopt failed. Unsupported script arguments present: ${@}"
        print_help
        exit_failure
    fi

    eval set -- "${getopt_cmd}"

    while true; do
        case "${1}" in
            -i|--input) INPUT_DIRECTORY=${2};;
            -t|--test) TEST_MODE="true";;
            -d|--debug) SCRIPT_DEBUG="true";;
            -h|--help) print_help; exit 0;;
            --) shift; break;;
        esac
        shift
    done
}

init_global_variables() {
    INPUT_DIRECTORY=${INPUT_DIRECTORY:="$(pwd)"}
    SCRIPT_DEBUG=${SCRIPT_DEBUG:="false"}
    TEST_MODE=${TEST_MODE:="false"}

    debug "INPUT_DIRECTORY: ${INPUT_DIRECTORY}"
}

process_photos() {
    for file in $(find ${INPUT_DIRECTORY} -name '*.jpg'); do
        debug "file ${file}"

        local exif_timestamp="$(exiftool -T -DateTimeOriginal ${file})"

        local exif_year=$(echo ${exif_timestamp} | sed -E 's/([0-9]{4}):[0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/\1/')
        local exif_month=$(echo ${exif_timestamp} | sed -E 's/[0-9]{4}:([0-9]{2}):[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/\1/')
        local exif_day=$(echo ${exif_timestamp} | sed -E 's/[0-9]{4}:[0-9]{2}:([0-9]{2}) [0-9]{2}:[0-9]{2}:[0-9]{2}/\1/')
        local exif_hour=$(echo ${exif_timestamp} | sed -E 's/[0-9]{4}:[0-9]{2}:[0-9]{2} ([0-9]{2}):[0-9]{2}:[0-9]{2}/\1/')
        local exif_minute=$(echo ${exif_timestamp} | sed -E 's/[0-9]{4}:[0-9]{2}:[0-9]{2} [0-9]{2}:([0-9]{2}):[0-9]{2}/\1/')
        local exif_second=$(echo ${exif_timestamp} | sed -E 's/[0-9]{4}:[0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2}:([0-9]{2})/\1/')

        local exif_date="${exif_year}-${exif_month}-${exif_day} ${exif_hour}:${exif_minute}:${exif_second}"

        local file_name=$(basename ${file})

        local file_year=$(echo ${file_name} | sed -E 's/.*_([0-9]{4})[0-9]{2}[0-9]{2}_[0-9]{2}[0-9]{2}[0-9]{2}.*/\1/')
        local file_month=$(echo ${file_name} | sed -E 's/.*_[0-9]{4}([0-9]{2})[0-9]{2}_[0-9]{2}[0-9]{2}[0-9]{2}.*/\1/')
        local file_day=$(echo ${file_name} | sed -E 's/.*_[0-9]{4}[0-9]{2}([0-9]{2})_[0-9]{2}[0-9]{2}[0-9]{2}.*/\1/')
        local file_hour=$(echo ${file_name} | sed -E 's/.*_[0-9]{4}[0-9]{2}[0-9]{2}_([0-9]{2})[0-9]{2}[0-9]{2}.*/\1/')
        local file_minute=$(echo ${file_name} | sed -E 's/.*_[0-9]{4}[0-9]{2}[0-9]{2}_[0-9]{2}([0-9]{2})[0-9]{2}.*/\1/')
        local file_second=$(echo ${file_name} | sed -E 's/.*_[0-9]{4}[0-9]{2}[0-9]{2}_[0-9]{2}[0-9]{2}([0-9]{2}).*/\1/')

        local file_date="${file_year}-${file_month}-${file_day} ${file_hour}:${file_minute}:${file_second}"

        local symbol="=="

        if [[ "${exif_date}" != "${file_date}" ]]; then
            exif_date="$(c_red_regular ${exif_date})"
            file_date="$(c_yellow_regular ${file_date})"
            symbol="->"

            info "${exif_date} ${symbol} ${file_date} | ${file_name}"
        else
            info "${exif_date} ${symbol} ${file_date} | ${file_name}"
            continue
        fi

        if [[ ${TEST_MODE} == true ]]; then
            continue
        fi

        local new_date="${file_year}:${file_month}:${file_day} ${file_hour}:${file_minute}:${file_second}"

        exiftool \
            -overwrite_original \
            -CreateDate="${new_date}" \
            -ModifyDate="${new_date}" \
            -TrackCreateDate="${new_date}" \
            -TrackModifyDate="${new_date}" \
            -MediaCreateDate="${new_date}" \
            -MediaModifyDate="${new_date}" \
            -DateTimeOriginal="${new_date}" \
            ${file} > /dev/null 2>&1
    done
}

main() {
    trap ctrl_c INT
    parse_command_line "${@}"
    init_global_variables

    if [[ ${TEST_MODE} == "true" ]]; then
        warn "Test mode! No actual changes to the files would be made."
    fi

    process_photos && exit_success || exit_failure
}

# Script helpers

# color_text COLOR TYPE "TEXT"
#
# Colors:
#   0 - black
#   1 - red
#   2 - green
#   3 - yellow
#   4 - blue
#   5 - purple
#   6 - cyan
#   7 - white
# Font types:
#   0 - regular
#   1 - bold
#   2 - tint
#   3 - italic
#   4 - underline
#   5, 6 - blink
#   7 - inverted
#   8 - ??? (black)
#   9 - cross out
color_text() {
    local color="${1}"
    local type="${2}"
    local text="$(echo ${@} | cut -d ' ' -f 3-)"
    local start_color="\e[0${type};3${color}m"
    local no_color="\e[00;00m"

    echo -en "${start_color}${text}${no_color}"
}

c_green_regular() { color_text 2 0 "${@}"; }
c_red_bold() { color_text 1 1 "${@}"; }
c_red_regular() { color_text 1 0 "${@}"; }
c_white_bold() { color_text 7 1 "${@}"; }
c_white_tint() { color_text 7 2 "${@}"; }
c_white_underline() { color_text 7 4 "${@}"; }
c_yellow_bold() { color_text 3 1 "${@}"; }
c_yellow_regular() { color_text 3 0 "${@}"; }

log() {
    echo -e "$(date '+%H:%M:%S.%3N') ${@}"
}

debug() {
    if [[ ${SCRIPT_DEBUG} == "true" ]]; then
        log $(c_white_tint "D") "$(c_white_tint ${@})"
    fi
}

info() {
    log $(c_white_bold "I") "${@}"
}

warn() {
    log $(c_yellow_bold "W") "$(c_yellow_regular ${@})"
}

error() {
    log $(c_red_bold "W") "$(c_red_regular ${@})"
}

exit_failure() {
    log $(c_red_regular "Script FAILED ($(date -ud @${SECONDS} +%H:%M:%S))")
    exit 1
}

exit_success() {
    log $(c_green_regular "Script SUCCEEDED ($(date -ud @${SECONDS} +%H:%M:%S))")
    exit 0
}

# Start main
main "${@}"
