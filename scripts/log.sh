print() {
    local log_level="$1"
    local message="$2"
    local timestamp
    local log_level_str

    case ${log_level} in
        INFO)
          log_level_str="\033[0;32m${log_level}\033[0m"
          ;;
        ERROR)
          log_level_str="\033[0;33m${log_level}\033[0m"
          ;;
        CRITICAL)
          log_level_str="\033[0;31m${log_level}\033[0m"
          ;;
        *)
          log_level_str="${log_level}"
          ;;
    esac

    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    printf "[%s] [%b] [PID:%s] %s\n" "${timestamp}" "${log_level_str}" "$$" "${message}"
}

info() { print INFO "$@"; }

error() {
    print ERROR "$@"
    print ERROR "Error occured with code ${RETURN_CODE}"
}

critical() {
    print CRITICAL "$@"
    print CRITICAL "Exiting with code ${RETURN_CODE}"
    exit ${RETURN_CODE}
}