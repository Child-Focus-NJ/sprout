from aws_cdk import Stack, Duration
import aws_cdk.aws_sqs as sqs
from constructs import Construct


class QueueStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.zoom_attendance_dlq = sqs.Queue(
            self,
            "ZoomAttendanceDlq",
            queue_name="sprout-zoom-attendance-dlq",
            retention_period=Duration.days(14),
        )

        self.mailchimp_batch_dlq = sqs.Queue(
            self,
            "MailchimpBatchDlq",
            queue_name="sprout-mailchimp-batch-dlq",
            retention_period=Duration.days(14),
        )

        self.zoom_attendance_queue = sqs.Queue(
            self,
            "ZoomAttendanceQueue",
            queue_name="sprout-zoom-attendance",
            visibility_timeout=Duration.seconds(300),
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=3,
                queue=self.zoom_attendance_dlq,
            ),
        )

        self.mailchimp_batch_queue = sqs.Queue(
            self,
            "MailchimpBatchQueue",
            queue_name="sprout-mailchimp-batch",
            visibility_timeout=Duration.seconds(300),
            dead_letter_queue=sqs.DeadLetterQueue(
                max_receive_count=3,
                queue=self.mailchimp_batch_dlq,
            ),
        )
