#!/bin/bash

########################################
# Constant
########################################

SHELL_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd)"

OVERLAY_TEMP_DIR="${SHELL_DIR%/}/tmp"

ICON_BADGE_ALPHA="${SHELL_DIR%/}/images/badge-alpha.png"
ICON_BADGE_BETA="${SHELL_DIR%/}/images/badge-beta.png"

########################################
# Utility
########################################

function executeCommand () {
    cmd=$1
    echo "$ $cmd"
    eval $cmd
}

function show_help () {
    echo "Usage: badge.sh --alpha --input /path/to/icon/dir"
    echo
    echo "Options:"
    echo "-a, --alpha     Add ALPHA badge"
    echo "-b, --beta      Add BETA badge"
    echo "-i, --input     Path to input directory"
    echo "-o, --output    Path to output directory (default=input directory)"
}

########################################
# Resize Image
########################################

overlay_image () {
    ########################################
    # Get opts
    ########################################

    OPTS=`getopt -o io: --long input,output: -n 'parse-options' -- "$@"`
    if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
    inputs=()
    output_path=""
    while true; do
        case "$1" in
            -i | --input )
            shift
            for arg in "$@"; do
                if [[ $1 != -* ]]; then
                    inputs+=("$arg")
                    shift
                fi
            done
            ;;
            -o | --output ) output_path=("$2"); shift; shift ;;
            -- ) shift; break ;;
            * ) break ;;
        esac
    done

    ########################################
    # Validation
    ########################################

    ###### Validate input images ######
    if [ ${#inputs[@]} -lt 2 ]; then
        echo
        echo "Please specify input images. At least two input images are required."
        echo
        show_help
        echo
        exit 1
    fi
    ###### Validate output images ######
    if [[ -z "${output_path// }" ]]; then
        echo
        echo "Please specify a output image."
        echo
        show_help
        echo
        exit 1
    fi

    ########################################
    # Main
    ########################################

    ###### Underlay image ######
    underlay_path=${inputs[0]}
    underlay_dir=$(dirname "${underlay_path}")
    underlay_filename=$(basename "${underlay_path}")
    underlay_width=$(identify -format "%w" "${underlay_path}") > /dev/null
    underlay_height=$(identify -format "%h" "${underlay_path}") > /dev/null

    ###### Image paths to be combined ######
    input_image_paths=("${underlay_path}")

    ###### Resize overlay images ######
    overlay_paths=(${inputs[@]:1})
    for overlay_path in ${overlay_paths[@]}; do
        ###### Overlay image ######
        overlay_dir=$(dirname "${overlay_path}")
        overlay_filename=$(basename "${overlay_path}")
        overlay_ext="${overlay_filename##*.}"
        overlay_basename="${overlay_filename%.*}"
        overlay_width=$(identify -format "%w" "${overlay_path}") > /dev/null
        overlay_height=$(identify -format "%h" "${overlay_path}") > /dev/null
        ###### Resized overlay image ######
        resize_overlay_filename="${overlay_basename}-${underlay_width}x${underlay_height}.${overlay_ext}"
        resize_overlay_path="${OVERLAY_TEMP_DIR%/}/${resize_overlay_filename}"
        convert -resize ${underlay_width}x${underlay_height} "${overlay_path}" "${resize_overlay_path}"
        ###### Add image path to be combined ######
        input_image_paths+=("$resize_overlay_path")
    done
    ###### Convert array to string ######
    input_overlay_images=$(printf " %s" "${input_image_paths[@]}")
    ###### Combine images ######
    executeCommand "convert -composite${input_overlay_images} -gravity center ${output_path}"
}


########################################
# Main
########################################

main () {
    ########################################
    # Get opts
    ########################################

    OPTS=`getopt -o abio: --long alpha,beta,input,output: -n 'parse-options' -- "$@"`
    if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

    badge_mode="n/a"
    input_dir=""
    while true; do
        case "$1" in
            -a | --alpha | -b | --beta) badge_mode="${1}"; shift ;;
            -i | --input ) input_dir=("$2"); shift; shift ;;
            -i | --output ) output_dir=("$2"); shift; shift ;;
            -- ) shift; break ;;
            * ) break ;;
        esac
    done

    ########################################
    # Validation
    ########################################

    ###### Varidate badge type ######
    if [[ ${badge_mode} != "--alpha" && ${badge_mode} != "--beta" ]] ; then
        echo
        echo "Please specify a badge type."
        echo
        show_help
        echo
        exit 1
    fi

    ###### Validate icon directory ######
    if [[ -z "${input_dir// }" ]]; then
        echo
        echo "Please specify a output image."
        echo
        show_help
        echo
        exit 1
    fi

    ###### Validate icon directory ######
    if [[ -z "${output_dir// }" ]]; then
        output_dir=${input_dir}
    fi

    ########################################
    # Resize
    ########################################

    ###### Create directory ######
    rm -rf "${OVERLAY_TEMP_DIR}"
    mkdir -p "${OVERLAY_TEMP_DIR}"
    if [[ ${input_dir} != ${output_dir} ]] ; then
        mkdir -p "${output_dir}"
    fi
    ###### Specify badge image ######
    if [[ ${badge_mode} != "--alpha" ]] ; then
        badge_file_path="${ICON_BADGE_ALPHA}"
    elif [[ ${badge_mode} != "--beta" ]] ; then
        badge_file_path="${ICON_BADGE_BETA}"
    fi
    ###### Enumarate all images ######
    for icon_file_path in "${input_dir}"/*; do
        ###### Check image mime-type ######
        mime_type=`file -b --mime-type "$icon_file_path"`
        if [[ $mime_type == "image/png" || $mime_type == "image/jpg" || $mime_type == "image/jpeg" ]] ; then
            ###### Combine images ######
            outpt_filename=$(basename "${icon_file_path}")
            output_file_path="${output_dir%/}/${outpt_filename}"
            overlay_image --input "${icon_file_path}" "${badge_file_path}" --output "${output_file_path}"
        fi
    done
    ###### Remove temporary directory ######
    rm -rf "${OVERLAY_TEMP_DIR}"
}

main $@
