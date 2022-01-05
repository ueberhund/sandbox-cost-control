# sandbox-cost-control
This repo sets up infrastructure so you can monitor costs in an AWS child account and turn off all access when a certain budget threshold is crossed. When a child account crosses the budget threshold you set up, a Service Control Policy is applied to the account that performs a `Deny` on `"*"`. This effectively denies all access to the account. If you have a resource that does not query for permissions (like an already running EC2 instance), it will continue to run. However, anything not already running (like a Lambda function or Step Function) won't be able to execute due to the deny. 

Once the billing for the account resets (at the beginning of the month), the SCP is removed and the account can be accessed again.

## Prerequisites
To use this solution, you must have already turned on Billing Alerts. This is done by going to the **AWS Billing Dashboard**, selecting **Billing preferences** and checking the box that says **Receive Billing Alerts**. Once Billing Alerts are enabled, it can take up to 24 hours for billing data for child accounts to be added to CloudWatch metrics. 

This solution also assumes you have Organizations enabled and have a set of child accounts that you want to monitor. 

## Setting up
To begin setting up, go to [install_stack.sh](install_stack.sh) and modify lines 5-8 to correspond to your environment.

- **ALERT_EMAIL** = this is the email address that should receive notifications from this solution
- **ADMIN_USER_ARN** = this is the arn (or comma delimited list of arns) for the user(s) who should be able to still access the account once it's been locked. This user can delete or turn off resources
- **BUDGET_AMOUNT** = this is the amount you're willing to spend on the account. When you cross this threshold, the SCP will be applied. Please keep in mind that billing data is updated approximately every 6 hours, so there may be a delay between when a resource begins to bill and the CloudWatch rule monitoring spend detects it
- **CHILD_ACCOUNTS_TO_MONITOR** = this is a comma-delimited list of AWS account IDs that you want to monitor. A new CloudWatch billing rule is created for each account, so they can be managed independently.

Once you've modified those fields, run the script

## Using the solution

Once the solution is active, it will monitor your accounts for billing data that goes above the threshold you specify. If an account crosses the billing threshold, you'll receive a message similar to this:

![deactivated account](/images/account_deactivated.png)

The solution will also apply a SCP called **QuarantineSCP** to the account, which denies all actions in the account except for actions from users identified in the `ADMIN_USER_ARN` field. This user can login to the account, turn off resources, etc.

Once the billing cycle resets (the beginning of the month), the account will be reactivated, and you'll receive a message similar to this:

![reactivated account](/images/account_reactivated.png)

The SCP on the account will be removed and you can continue to use the account as normal until the billing metric once again crosses the threshold you specify.
