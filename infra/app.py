#!/usr/bin/env python3
import os
import aws_cdk as cdk

from stacks.network_stack import NetworkStack
from stacks.database_stack import DatabaseStack
from stacks.storage_stack import StorageStack
from stacks.queue_stack import QueueStack
from stacks.lambda_stack import LambdaStack
from stacks.api_stack import ApiStack

app = cdk.App()

env = cdk.Environment(
    account=os.environ.get("CDK_DEFAULT_ACCOUNT", "000000000000"),
    region=os.environ.get("CDK_DEFAULT_REGION", "us-east-1"),
)

network = NetworkStack(app, "SproutNetwork", env=env)

database = DatabaseStack(
    app, "SproutDatabase", vpc=network.vpc, rds_sg=network.rds_sg, env=env
)

storage = StorageStack(app, "SproutStorage", env=env)

queues = QueueStack(app, "SproutQueues", env=env)

lambdas = LambdaStack(
    app,
    "SproutLambdas",
    vpc=network.vpc,
    lambda_sg=network.lambda_sg,
    queues=queues,
    database_secret_arn=database.secret.secret_arn,
    env=env,
)

ApiStack(app, "SproutApi", lambdas=lambdas, env=env)

app.synth()
