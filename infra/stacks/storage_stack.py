from aws_cdk import Stack, RemovalPolicy, Duration
import aws_cdk.aws_s3 as s3
from constructs import Construct


class StorageStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.reports_bucket = s3.Bucket(
            self,
            "SproutReports",
            bucket_name=None,
            versioned=False,
            removal_policy=RemovalPolicy.RETAIN,
            encryption=s3.BucketEncryption.S3_MANAGED,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            lifecycle_rules=[
                s3.LifecycleRule(
                    id="expire-old-reports",
                    expiration=Duration.days(365),
                    enabled=True,
                ),
            ],
        )
