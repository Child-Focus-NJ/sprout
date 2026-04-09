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

        # /volunteer-management-system
        vms = api.root.add_resource("volunteer-management-system")
        vms_sync = vms.add_resource("sync")
        vms_sync.add_method(
            "POST",
            apigw.LambdaIntegration(lambdas.volunteer_management_system_sync_fn),
        )

        # /vms
        vms_root = api.root.add_resource("vms")

        # POST /vms/session/refresh -> VMS Session Refresh Lambda
        vms_session = vms_root.add_resource("session")
        vms_session_refresh = vms_session.add_resource("refresh")
        vms_session_refresh.add_method(
            "POST",
            apigw.LambdaIntegration(lambdas.vms_session_refresh_fn),
        )

        # GET, POST /vms/inquiries -> VMS Lambda
        vms_inquiries = vms_root.add_resource("inquiries")
        vms_inquiries.add_method(
            "GET", apigw.LambdaIntegration(lambdas.vms_fn)
        )
        vms_inquiries.add_method(
            "POST", apigw.LambdaIntegration(lambdas.vms_fn)
        )

        # PUT, DELETE /vms/inquiries/{id} -> VMS Lambda
        vms_inquiry_id = vms_inquiries.add_resource("{id}")
        vms_inquiry_id.add_method(
            "PUT", apigw.LambdaIntegration(lambdas.vms_fn)
        )
        vms_inquiry_id.add_method(
            "DELETE", apigw.LambdaIntegration(lambdas.vms_fn)
        )

        # GET, POST /vms/volunteers -> VMS Lambda
        vms_volunteers = vms_root.add_resource("volunteers")
        vms_volunteers.add_method(
            "GET", apigw.LambdaIntegration(lambdas.vms_fn)
        )
        vms_volunteers.add_method(
            "POST", apigw.LambdaIntegration(lambdas.vms_fn)
        )

        # GET /vms/lookups/{type} -> VMS Lambda
        vms_lookups = vms_root.add_resource("lookups")
        vms_lookup_type = vms_lookups.add_resource("{type}")
        vms_lookup_type.add_method(
            "GET", apigw.LambdaIntegration(lambdas.vms_fn)
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
