from aws_cdk import Stack, CfnOutput
import aws_cdk.aws_elasticbeanstalk as eb
import aws_cdk.aws_iam as iam
from constructs import Construct


class EbStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        api_url: str,
        reports_bucket_name: str,
        zoom_attendance_queue_url: str,
        mailchimp_batch_queue_url: str,
        database_url: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        eb_role = iam.Role(
            self,
            "EbInstanceRole",
            assumed_by=iam.ServicePrincipal("ec2.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name(
                    "AWSElasticBeanstalkWebTier"
                ),
            ],
        )

        instance_profile = iam.CfnInstanceProfile(
            self,
            "EbInstanceProfile",
            roles=[eb_role.role_name],
        )

        app = eb.CfnApplication(
            self,
            "SproutApp",
            application_name="sprout",
        )

        env = eb.CfnEnvironment(
            self,
            "SproutEnv",
            application_name=app.application_name,
            environment_name="sprout-production",
            solution_stack_name="64bit Amazon Linux 2023 v4.4.4 running Docker",
            option_settings=[
                eb.CfnEnvironment.OptionSettingProperty(
                    namespace="aws:autoscaling:launchconfiguration",
                    option_name="InstanceType",
                    value="t3.small",
                ),
                eb.CfnEnvironment.OptionSettingProperty(
                    namespace="aws:autoscaling:launchconfiguration",
                    option_name="IamInstanceProfile",
                    value=instance_profile.ref,
                ),
                eb.CfnEnvironment.OptionSettingProperty(
                    namespace="aws:elasticbeanstalk:application:environment",
                    option_name="RAILS_ENV",
                    value="production",
                ),
                eb.CfnEnvironment.OptionSettingProperty(
                    namespace="aws:elasticbeanstalk:application:environment",
                    option_name="DATABASE_URL",
                    value=database_url,
                ),
                eb.CfnEnvironment.OptionSettingProperty(
                    namespace="aws:elasticbeanstalk:application:environment",
                    option_name="API_GATEWAY_URL",
                    value=api_url,
                ),
                eb.CfnEnvironment.OptionSettingProperty(
                    namespace="aws:elasticbeanstalk:application:environment",
                    option_name="SQS_ZOOM_ATTENDANCE_URL",
                    value=zoom_attendance_queue_url,
                ),
                eb.CfnEnvironment.OptionSettingProperty(
                    namespace="aws:elasticbeanstalk:application:environment",
                    option_name="SQS_MAILCHIMP_BATCH_URL",
                    value=mailchimp_batch_queue_url,
                ),
                eb.CfnEnvironment.OptionSettingProperty(
                    namespace="aws:elasticbeanstalk:application:environment",
                    option_name="S3_REPORTS_BUCKET",
                    value=reports_bucket_name,
                ),
            ],
        )

        CfnOutput(
            self,
            "EbEndpointUrl",
            value=env.attr_endpoint_url,
            description="Elastic Beanstalk environment URL",
        )
