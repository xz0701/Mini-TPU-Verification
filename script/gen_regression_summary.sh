#!/usr/bin/env bash
set -u

sim_dir="${1:-sim}"
out_file="${2:-${sim_dir}/regression_summary.txt}"

mkdir -p "$(dirname "${out_file}")"

fail_count=0
pass_count=0
total_count=0

is_known_uvm_test() {
    local test="$1"

    if [ -z "${REGRESSION_UVM_TESTS:-}" ]; then
        return 0
    fi

    [[ " ${REGRESSION_UVM_TESTS} " == *" ${test} "* ]]
}

get_uvm_count() {
    local label="$1"
    local log="$2"
    awk -v label="${label}" '$1 == label && $2 == ":" {value=$3} END {if (value == "") print "NA"; else print value}' "${log}"
}

get_cov_total() {
    local log="$1"
    local line

    line="$(grep -E 'Functional coverage: .*total=[0-9.]+%' "${log}" | tail -n 1 || true)"
    if [ -z "${line}" ]; then
        printf "NA"
    else
        printf "%s" "${line##*total=}"
    fi
}

get_test_info() {
    local base="$1"
    local array="NA"
    local test="unknown"

    if [[ "${base}" =~ ^run_tb_mini_tpu_uvm_([0-9]+x[0-9]+)_(.*)\.log$ ]]; then
        array="${BASH_REMATCH[1]}"
        test="${BASH_REMATCH[2]}"
    elif [[ "${base}" =~ ^run_tb_systolic_smoke_([0-9]+x[0-9]+)\.log$ ]]; then
        array="${BASH_REMATCH[1]}"
        test="directed_systolic_smoke"
    elif [[ "${base}" =~ ^run_tb_axi_lite_smoke_([0-9]+x[0-9]+)\.log$ ]]; then
        array="${BASH_REMATCH[1]}"
        test="directed_axi_lite_smoke"
    elif [[ "${base}" =~ ^run_(.*)\.log$ ]]; then
        test="${BASH_REMATCH[1]}"
    fi

    printf "%s|%s" "${array}" "${test}"
}

has_error_text() {
    local log="$1"

    grep -Eiq 'Error-|Fatal|FAILED|(^|[^A-Z])FAIL([^A-Z]|$)|MISMATCH|Timeout|ASSERT|Assertion' "${log}"
}

print_cov_report_summary() {
    local report_xml="${sim_dir}/cov_report/session.xml"

    if [ ! -f "${report_xml}" ]; then
        printf "Coverage report: NA\n"
        return
    fi

    printf "Coverage report: %s\n" "${sim_dir}/cov_report"
    grep -E '<metric name="[^"]+" value="[0-9.]+%"' "${report_xml}" |
        sed -E 's/.*name="([^"]+)".*value="([^"]+)".*/  \1: \2/' |
        sort -u
}

{
    printf "Mini TPU Regression Summary\n"
    printf "Generated: %s\n" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf "Log directory: %s\n\n" "${sim_dir}"

    printf "%-8s %-34s %-8s %-8s %-8s %-10s %s\n" \
        "ARRAY" "TEST" "STATUS" "ERRORS" "FATALS" "COV" "LOG"
    printf "%-8s %-34s %-8s %-8s %-8s %-10s %s\n" \
        "-----" "----" "------" "------" "------" "---" "---"

    while IFS= read -r log; do
        base="$(basename "${log}")"
        info="$(get_test_info "${base}")"
        array="${info%%|*}"
        test="${info#*|}"

        if [[ "${base}" =~ ^run_tb_mini_tpu_uvm_ ]] && ! is_known_uvm_test "${test}"; then
            continue
        fi

        errors="$(get_uvm_count "UVM_ERROR" "${log}")"
        fatals="$(get_uvm_count "UVM_FATAL" "${log}")"
        cov="$(get_cov_total "${log}")"
        status="PASS"

        total_count=$((total_count + 1))

        if [ "${errors}" != "NA" ] && [ "${errors}" != "0" ]; then
            status="FAIL"
        fi
        if [ "${fatals}" != "NA" ] && [ "${fatals}" != "0" ]; then
            status="FAIL"
        fi
        if [ "${errors}" = "NA" ] && [ "${fatals}" = "NA" ] && ! grep -Eq '(^|[^A-Z])PASS([^A-Z]|$)' "${log}"; then
            status="FAIL"
        fi
        if has_error_text "${log}"; then
            if ! grep -q 'UVM_ERROR :    0' "${log}" && ! grep -q 'UVM_FATAL :    0' "${log}"; then
                status="FAIL"
            fi
        fi

        if [ "${status}" = "PASS" ]; then
            pass_count=$((pass_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi

        printf "%-8s %-34s %-8s %-8s %-8s %-10s %s\n" \
            "${array}" "${test}" "${status}" "${errors}" "${fatals}" "${cov}" "${log}"
    done < <(find "${sim_dir}" -maxdepth 1 -type f -name 'run_*.log' | sort)

    printf "\nTotals: pass=%0d fail=%0d total=%0d\n\n" "${pass_count}" "${fail_count}" "${total_count}"
    print_cov_report_summary
} > "${out_file}"

cat "${out_file}"
exit "${fail_count}"
