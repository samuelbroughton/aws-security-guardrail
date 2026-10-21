import json
import os
import boto3

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

TOPIC_ARN = os.environ["TOPIC_ARN"]
OPEN_TO_WORLD = {"0.0.0.0/0", "::/0"}


def covers_ssh(rule):
    """True if the rule allows port 22 (or all traffic)."""
    if rule["IpProtocol"] == "-1":  
        return True
    if rule["IpProtocol"] != "tcp":
        return False
    return rule.get("FromPort", 0) <= 22 <= rule.get("ToPort", 0)


def handler(event, context):
    detail = event.get("detail", {})

    if detail.get("errorCode"):
        return {"status": "ignored", "reason": "API call failed"}

    params = detail.get("requestParameters") or {}
    group_id = params.get("groupId")

    if not group_id and params.get("groupName"):
        groups = ec2.describe_security_groups(GroupNames=[params["groupName"]])
        group_id = groups["SecurityGroups"][0]["GroupId"]

    if not group_id:
        return {"status": "ignored", "reason": "no security group in event"}

    actor = detail.get("userIdentity", {}).get("arn", "unknown")

    rules = ec2.describe_security_group_rules(
        Filters=[{"Name": "group-id", "Values": [group_id]}]
    )["SecurityGroupRules"]

    bad_rules = [
        r for r in rules
        if not r["IsEgress"]
        and (r.get("CidrIpv4") in OPEN_TO_WORLD or r.get("CidrIpv6") in OPEN_TO_WORLD)
        and covers_ssh(r)
    ]

    if not bad_rules:
        return {"status": "compliant", "group": group_id}

    rule_ids = [r["SecurityGroupRuleId"] for r in bad_rules]
    ec2.revoke_security_group_ingress(GroupId=group_id, SecurityGroupRuleIds=rule_ids)

    result = {
        "status": "remediated",
        "group": group_id,
        "rules_removed": rule_ids,
        "changed_by": actor,
        "event_time": detail.get("eventTime"),
    }
    print(json.dumps(result))  

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject="[AUTO-REMEDIATED] SSH opened to the internet",
        Message=json.dumps(result, indent=2),
    )
    return result