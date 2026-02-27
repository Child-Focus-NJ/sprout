from aws_cdk import Stack, CfnOutput
import aws_cdk.aws_apigateway as apigw
from constructs import Construct

from stacks.lambda_stack import LambdaStack


class ApiStack(Stack):
    def __init__(
        self, scope: Construct, construct_id: str, lambdas: LambdaStack, **kwargs
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        api = apigw.RestApi(
            self,
            "SproutApi",
            rest_api_name="Sprout Integration API",
            description="API Gateway for Sprout Lambda integrations",
            deploy_options=apigw.StageOptions(stage_name="v1"),
        )

        # /zoom
        zoom = api.root.add_resource("zoom")
        zoom_meeting = zoom.add_resource("meeting")
        zoom_meeting.add_method(
            "POST",
            apigw.LambdaIntegration(lambdas.zoom_meeting_fn),
        )

        # /optima
        optima = api.root.add_resource("optima")
        optima_sync = optima.add_resource("sync")
        optima_sync.add_method(
            "POST",
            apigw.LambdaIntegration(lambdas.optima_sync_fn),
        )

        # /mailchimp
        mailchimp = api.root.add_resource("mailchimp")

        send_email = mailchimp.add_resource("send-email")
        send_email.add_method(
            "POST",
            apigw.LambdaIntegration(lambdas.mailchimp_realtime_fn),
        )

        send_sms = mailchimp.add_resource("send-sms")
        send_sms.add_method(
            "POST",
            apigw.LambdaIntegration(lambdas.mailchimp_realtime_fn),
        )

        member = mailchimp.add_resource("member")
        member.add_method(
            "POST",
            apigw.LambdaIntegration(lambdas.mailchimp_realtime_fn),
        )

        tags = mailchimp.add_resource("tags")
        tags.add_method(
            "POST",
            apigw.LambdaIntegration(lambdas.mailchimp_realtime_fn),
        )

        self.api_url = api.url

        CfnOutput(self, "ApiUrl", value=api.url, description="API Gateway base URL")
