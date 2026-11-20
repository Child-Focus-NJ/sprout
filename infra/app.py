#!/usr/bin/env python3
import os
import aws_cdk as cdk

from stacks.network_stack import NetworkStack
from stacks.database_stack import DatabaseStack
from stacks.storage_stack import StorageStack
from stacks.queue_stack import QueueStack
from stacks.iam_stack import IamStack

app = cdk.App()

env = cdk.Environment(
    account=os.environ.get("CDK_DEFAULT_ACCOUNT", "000000000000"),
    region=os.environ.get("CDK_DEFAULT_REGION", "us-east-1"),
)

IamStack(app, "SproutIam", env=env)

network = NetworkStack(app, "SproutNetwork", env=env)

database = DatabaseStack(
    app, "SproutDatabase", vpc=network.vpc, rds_sg=network.rds_sg, env=env
)

storage = StorageStack(app, "SproutStorage", env=env)

QueueStack(app, "SproutQueues", env=env)

app.synth()
