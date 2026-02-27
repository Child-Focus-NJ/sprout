from aws_cdk import Stack, RemovalPolicy, Duration
import aws_cdk.aws_ec2 as ec2
import aws_cdk.aws_rds as rds
from constructs import Construct


class DatabaseStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        vpc: ec2.Vpc,
        rds_sg: ec2.SecurityGroup,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.instance = rds.DatabaseInstance(
            self,
            "SproutDb",
            engine=rds.DatabaseInstanceEngine.postgres(
                version=rds.PostgresEngineVersion.VER_16,
            ),
            instance_type=ec2.InstanceType.of(
                ec2.InstanceClass.BURSTABLE3, ec2.InstanceSize.MICRO
            ),
            vpc=vpc,
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS
            ),
            security_groups=[rds_sg],
            database_name="sprout_production",
            credentials=rds.Credentials.from_generated_secret("sprout"),
            multi_az=False,
            allocated_storage=20,
            max_allocated_storage=50,
            removal_policy=RemovalPolicy.SNAPSHOT,
            deletion_protection=True,
            backup_retention=Duration.days(7),
        )

        self.secret = self.instance.secret
