travis_retry() {
  local result=0
  local count=1
  local -a waits=(${TRAVIS_RETRY_INTERVALS//,/ })
  if [[ "${#waits[@]}" -eq 0 ]]; then
    waits=(1 1)
  fi
  waits=("${waits[@]}" 0)
  for wait in "${waits[@]}"; do
    [[ "${result}" -ne 0 ]] && {
      echo -e "\\n${ANSI_RED}The command \"${*}\" failed. Retrying, ${count} of ${#waits[@]}.${ANSI_RESET}\\n" >&2
    }
    "${@}" && { result=0 && break; } || result="${?}"
    count="$((count + 1))"
    [[ "${wait}" -eq 0 ]] || sleep $wait
  done

  [[ "${count}" -gt "${#waits[@]}" ]] && {
    echo -e "\\n${ANSI_RED}The command \"${*}\" failed ${#waits[@]} times.${ANSI_RESET}\\n" >&2
  }

  return "${result}"
}
