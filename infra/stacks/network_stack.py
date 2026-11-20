from aws_cdk import Stack
import aws_cdk.aws_ec2 as ec2
from constructs import Construct


class NetworkStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # NAT remains because RDS is placed in PRIVATE_WITH_EGRESS (see database_stack).
        # After Lambdas were removed nothing else needs private egress; switching RDS to
        # PRIVATE_ISOLATED would allow nat_gateways=0 and save ~$30+/month.
        self.vpc = ec2.Vpc(
            self,
            "SproutVpc",
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24,
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24,
                ),
            ],
        )

        self.rds_sg = ec2.SecurityGroup(
            self,
            "RdsSg",
            vpc=self.vpc,
            description="Security group for RDS PostgreSQL",
        )

        self.eb_sg = ec2.SecurityGroup(
            self,
            "EbSg",
            vpc=self.vpc,
            description="Security group for Elastic Beanstalk instances",
            allow_all_outbound=True,
        )

        self.rds_sg.add_ingress_rule(
            peer=self.eb_sg,
            connection=ec2.Port.tcp(5432),
            description="EB to RDS",
        )
