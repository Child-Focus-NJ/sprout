import os
from aws_cdk import Stack, Duration
import aws_cdk.aws_lambda as _lambda
import aws_cdk.aws_ec2 as ec2
import aws_cdk.aws_iam as iam
import aws_cdk.aws_lambda_event_sources as event_sources
import aws_cdk.aws_events as events
import aws_cdk.aws_events_targets as targets
from constructs import Construct

from stacks.queue_stack import QueueStack


class LambdaStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        vpc: ec2.Vpc,
        lambda_sg: ec2.SecurityGroup,
        queues: QueueStack,
        database_secret_arn: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Common VPC placement for all functions (needed to reach RDS)
        self._vpc = vpc
        self._lambda_sg = lambda_sg
        self._vpc_subnets = ec2.SubnetSelection(
            subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS
        )

        lambdas_dir = os.path.join(os.path.dirname(__file__), "..", "..", "lambdas")

        shared_layer = _lambda.LayerVersion(
            self,
            "SharedLayer",
            code=_lambda.Code.from_asset(os.path.join(lambdas_dir, "shared")),
            compatible_runtimes=[_lambda.Runtime.RUBY_3_3],
            description="Shared utilities for Sprout Lambda functions",
        )

        common_env = {
            "DATABASE_SECRET_ARN": database_secret_arn,
        }

        # Sync Lambda functions (API Gateway)
        self.zoom_meeting_fn = _lambda.Function(
            self,
            "ZoomMeetingFn",
            function_name="sprout-zoom-meeting",
            runtime=_lambda.Runtime.RUBY_3_3,
            handler="handler.handler",
            code=_lambda.Code.from_asset(os.path.join(lambdas_dir, "zoom_meeting")),
            layers=[shared_layer],
            timeout=Duration.seconds(30),
            memory_size=256,
            environment=common_env,
            vpc=self._vpc,
            vpc_subnets=self._vpc_subnets,
            security_groups=[self._lambda_sg],
        )

        self.optima_sync_fn = _lambda.Function(
            self,
            "OptimaSyncFn",
            function_name="sprout-optima-sync",
            runtime=_lambda.Runtime.RUBY_3_3,
            handler="handler.handler",
            code=_lambda.Code.from_asset(os.path.join(lambdas_dir, "optima_sync")),
            layers=[shared_layer],
            timeout=Duration.seconds(30),
            memory_size=256,
            environment=common_env,
            vpc=self._vpc,
            vpc_subnets=self._vpc_subnets,
            security_groups=[self._lambda_sg],
        )

        self.mailchimp_realtime_fn = _lambda.Function(
            self,
            "MailchimpRealtimeFn",
            function_name="sprout-mailchimp-realtime",
            runtime=_lambda.Runtime.RUBY_3_3,
            handler="handler.handler",
            code=_lambda.Code.from_asset(
                os.path.join(lambdas_dir, "mailchimp_realtime")
            ),
            layers=[shared_layer],
            timeout=Duration.seconds(30),
            memory_size=256,
            environment=common_env,
            vpc=self._vpc,
            vpc_subnets=self._vpc_subnets,
            security_groups=[self._lambda_sg],
        )

        # Async Lambda functions (SQS / EventBridge)
        self.zoom_attendance_fn = _lambda.Function(
            self,
            "ZoomAttendanceFn",
            function_name="sprout-zoom-attendance",
            runtime=_lambda.Runtime.RUBY_3_3,
            handler="handler.handler",
            code=_lambda.Code.from_asset(
                os.path.join(lambdas_dir, "zoom_attendance")
            ),
            layers=[shared_layer],
            timeout=Duration.seconds(300),
            memory_size=256,
            environment=common_env,
            vpc=self._vpc,
            vpc_subnets=self._vpc_subnets,
            security_groups=[self._lambda_sg],
        )

        self.zoom_attendance_fn.add_event_source(
            event_sources.SqsEventSource(
                queues.zoom_attendance_queue,
                batch_size=1,
            )
        )

        self.mailchimp_batch_fn = _lambda.Function(
            self,
            "MailchimpBatchFn",
            function_name="sprout-mailchimp-batch",
            runtime=_lambda.Runtime.RUBY_3_3,
            handler="handler.handler",
            code=_lambda.Code.from_asset(
                os.path.join(lambdas_dir, "mailchimp_batch")
            ),
            layers=[shared_layer],
            timeout=Duration.seconds(300),
            memory_size=256,
            environment=common_env,
            vpc=self._vpc,
            vpc_subnets=self._vpc_subnets,
            security_groups=[self._lambda_sg],
        )

        self.mailchimp_batch_fn.add_event_source(
            event_sources.SqsEventSource(
                queues.mailchimp_batch_queue,
                batch_size=10,
            )
        )

        # EventBridge nightly schedule for mailchimp batch
        events.Rule(
            self,
            "NightlyMailchimpSync",
            schedule=events.Schedule.cron(hour="6", minute="0"),
            targets=[targets.LambdaFunction(self.mailchimp_batch_fn)],
        )

        # IAM permissions - all functions can read database secret
        for fn in [
            self.zoom_meeting_fn,
            self.zoom_attendance_fn,
            self.optima_sync_fn,
            self.mailchimp_realtime_fn,
            self.mailchimp_batch_fn,
        ]:
            fn.add_to_role_policy(
                iam.PolicyStatement(
                    actions=["secretsmanager:GetSecretValue"],
                    resources=[database_secret_arn],
                )
            )
