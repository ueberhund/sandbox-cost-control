#!/usr/bin/env bash

set -e 

ALERT_EMAIL='<EMAIL ADDRESS GOES HERE>'
ADMIN_USER_ARN='<ARN OF THE USER WHO SHOULD BE ABLE TO STILL LOGIN TO THE BLOCKED ACCOUNTS GOES HERE. YOU CAN USE A COMMA IF YOU HAVE MULTIPLE ARNS>'
BUDGET_AMOUNT='<BUDGET AMOUNT>'
CHILD_ACCOUNTS_TO_MONITOR=<ACCOUNT IDS YOU WANT TO MONITOR, SEPARATED BY A COMMA>
STACK_NAME_BASE='billing-alert'

#Check to make sure all required commands are installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install and then re-run the installer"
    exit
fi

if ! command -v aws &> /dev/null
then
    echo "aws could not be found. Please install and then re-run the installer"
    exit
fi

REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity | jq '.Account' -r)

if [ -z "$REGION" ]; then
    echo "Please set a region by running 'aws configure'"
    exit
fi

echo "Creating infrastructure stack..."
STACK_ID=$( aws cloudformation create-stack --stack-name ${STACK_NAME_BASE}-infra \
  --template-body file://billing-alert-infra.yml \
  --parameters ParameterKey=AlertEmail,ParameterValue=${ALERT_EMAIL} \
               ParameterKey=AdminUserArn,ParameterValue=${ADMIN_USER_ARN} \
  --capabilities CAPABILITY_IAM \
  | jq -r .StackId \
)

echo "Waiting on ${STACK_ID} create completion..."
aws cloudformation wait stack-create-complete --stack-name ${STACK_ID}
CFN_OUTPUT=$(aws cloudformation describe-stacks --stack-name ${STACK_ID} | jq .Stacks[0].Outputs)
BILLING_ALARM_TOPIC=$(echo $CFN_OUTPUT | jq '.[]| select(.OutputKey | contains("BillingAlarmTopic")).OutputValue' -r)

for accountId in ${CHILD_ACCOUNTS_TO_MONITOR//,/$IFS}
do
    echo "Creating monitor for account #${accountId}"
    STACK_ID=$( aws cloudformation create-stack --stack-name ${STACK_NAME_BASE}-acct-${accountId} \
        --template-body file://account-billing-alert.yml \
        --parameters ParameterKey=DefaultBudgetAmount,ParameterValue=${BUDGET_AMOUNT} \
                     ParameterKey=AccountToMonitor,ParameterValue=${accountId} \
                     ParameterKey=SNSTopic,ParameterValue=${BILLING_ALARM_TOPIC} \
        --capabilities CAPABILITY_IAM \
        | jq -r .StackId \
    )
    aws cloudformation wait stack-create-complete --stack-name ${STACK_ID}
done

echo "Deployment complete!"