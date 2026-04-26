import aws_cdk
from aws_cdk import Stack, CfnOutput
import aws_cdk.aws_iam as iam
from constructs import Construct


class IamStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        github_org: str = "Child-Focus-NJ",
        github_repo: str = "sprout",
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # ── MFA enforcement policy (attached to all groups) ──────────
        mfa_policy = iam.ManagedPolicy(
            self,
            "RequireMFA",
            managed_policy_name="SproutRequireMFA",
            statements=[
                # Let users manage their own MFA, password, and access keys
                iam.PolicyStatement(
                    sid="AllowSelfServiceUserActions",
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "iam:GetAccountPasswordPolicy",
                        "iam:ChangePassword",
                        "iam:GetUser",
                        "iam:DeleteVirtualMFADevice",
                        "iam:ListMFADevices",
                        "iam:EnableMFADevice",
                        "iam:ResyncMFADevice",
                        "iam:CreateAccessKey",
                        "iam:DeleteAccessKey",
                        "iam:ListAccessKeys",
                        "iam:UpdateAccessKey",
                    ],
                    resources=[
                        f"arn:aws:iam::{self.account}:user/${{aws:username}}",
                        f"arn:aws:iam::{self.account}:mfa/${{aws:username}}",
                    ],
                ),
                # These actions don't support per-user ARNs
                iam.PolicyStatement(
                    sid="AllowMFADeviceManagement",
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "iam:CreateVirtualMFADevice",
                        "iam:ListVirtualMFADevices",
                    ],
                    resources=["*"],
                ),
                # Block everything if MFA is not active
                iam.PolicyStatement(
                    sid="BlockEverythingWithoutMFA",
                    effect=iam.Effect.DENY,
                    not_actions=[
                        "iam:CreateVirtualMFADevice",
                        "iam:EnableMFADevice",
                        "iam:GetUser",
                        "iam:ChangePassword",
                        "iam:ListMFADevices",
                        "iam:ListVirtualMFADevices",
                        "iam:ResyncMFADevice",
                        "sts:GetSessionToken",
                    ],
                    resources=["*"],
                    conditions={
                        "BoolIfExists": {
                            "aws:MultiFactorAuthPresent": "false",
                        },
                    },
                ),
            ],
        )

        # ── Admin group ──────────────────────────────────────────────
        self.admins = iam.Group(
            self, "Admins", group_name="SproutAdmins"
        )
        self.admins.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AdministratorAccess")
        )
        self.admins.add_managed_policy(mfa_policy)

        # ── Developer group ──────────────────────────────────────────
        self.developers = iam.Group(
            self, "Developers", group_name="SproutDevelopers"
        )
        self.developers.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("PowerUserAccess")
        )
        self.developers.add_managed_policy(mfa_policy)

        # ── Viewer group ─────────────────────────────────────────────
        self.viewers = iam.Group(
            self, "Viewers", group_name="SproutViewers"
        )
        self.viewers.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("ReadOnlyAccess")
        )
        self.viewers.add_managed_policy(mfa_policy)

        # ── GitHub Actions OIDC ──────────────────────────────────────
        github_oidc_provider = iam.OpenIdConnectProvider(
            self,
            "GitHubOidc",
            url="https://token.actions.githubusercontent.com",
            client_ids=["sts.amazonaws.com"],
        )

        self.github_actions_role = iam.Role(
            self,
            "GitHubActionsRole",
            role_name="SproutGitHubActionsRole",
            max_session_duration=aws_cdk.Duration.minutes(15),
            assumed_by=iam.WebIdentityPrincipal(
                github_oidc_provider.open_id_connect_provider_arn,
                conditions={
                    "StringLike": {
                        "token.actions.githubusercontent.com:sub": f"repo:{github_org}/{github_repo}:*",
                    },
                    "StringEquals": {
                        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
                    },
                },
            ),
        )
        self.github_actions_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("PowerUserAccess")
        )

        # ── Outputs ──────────────────────────────────────────────────
        CfnOutput(
            self,
            "GitHubActionsRoleArn",
            value=self.github_actions_role.role_arn,
            description="ARN for GitHub Actions OIDC role — use in workflow as role-to-assume",
        )
