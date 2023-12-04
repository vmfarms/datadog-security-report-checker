#!/bin/bash

MOD_ADDR=https://github.com/turbot/steampipe-mod-aws-compliance.git
MOD_LOCAL_FOLDER=steampipe-mod-aws-compliance
CONTROL_CSV_FILE=controls.csv

check_commands() {
    for cmd in "$@"
    do
        if ! command -v "$cmd" &> /dev/null
        then
            echo "Required command not found: $cmd"
            exit 1
        fi
    done
}

clone_model() {
    address=$1
    folder=$2
    [ ! -d "$folder" ] && git clone $address $folder || cd $folder; git pull; cd - &> /dev/null
}

create_report_folder () {
    [ ! -d "reports" ] && mkdir "reports"
    local report_location="reports/$(date '+%Y%m%d-%H%M%S')"
    mkdir $report_location
    cp "template/README.md" $report_location
    echo "$PWD/$report_location"
}

check_sp_aws_plugin () {
    steampipe plugin update aws || steampipe plugin install aws
}

check_commands steampipe git aws
check_sp_aws_plugin
clone_model $MOD_ADDR $MOD_LOCAL_FOLDER
aws iam generate-credential-report | cat - &> /dev/null
report_location=$(create_report_folder)

while IFS="," read -r control_name pretty_name
do
    [ -z "$pretty_name" ] && pretty_name=$control_name
    cd $MOD_LOCAL_FOLDER
    steampipe check $control_name --output md --export $report_location/$control_name.md &> /dev/null
    [ $? > 0 ] && status="❌" || status="✅"
    echo "|$status|[$pretty_name]($control_name.md)|" >> $report_location/README.md
    cd - &> /dev/null
done < <(tail -n +2 $CONTROL_CSV_FILE)

echo "Your report has been created. Check the `report` folder."
