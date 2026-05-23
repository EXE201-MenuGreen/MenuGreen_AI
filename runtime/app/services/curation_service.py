from __future__ import annotations

from app.repositories.user_repository import UserRepository


class CurationService:
    def __init__(self) -> None:
        self.repo = UserRepository()

    def run_nightly(self, limit: int = 200) -> dict:
        events = self.repo.list_unprocessed_feedback_events(limit=limit)
        created = 0
        skipped = 0

        for event in events:
            feedback_id = str(event.get("id"))
            feedback_type = str(event.get("feedback_type") or "")
            user_note = str(event.get("user_note") or "").strip()
            assistant_response = str(event.get("assistant_response") or "").strip()
            corrected_response = str(event.get("corrected_response") or "").strip()

            input_text = user_note
            expected_output = ""
            labels = ["nightly-curation"]

            if feedback_type == "correction":
                expected_output = corrected_response
                labels.append("correction")
            elif feedback_type == "thumbs_up":
                expected_output = assistant_response
                labels.append("thumbs-up")
            elif feedback_type == "rating" and int(event.get("rating") or 0) >= 4:
                expected_output = assistant_response
                labels.append("high-rating")
            else:
                skipped += 1
                continue

            if not input_text or not expected_output:
                skipped += 1
                continue

            payload = {
                "feedback_id": feedback_id,
                "source": "nightly_feedback_curation",
                "input_text": input_text,
                "context_json": {
                    "thread_id": event.get("thread_id"),
                    "feature_area": event.get("feature_area"),
                    "feedback_type": feedback_type,
                },
                "expected_output": expected_output,
                "labels": labels,
                "status": "pending",
            }
            row = self.repo.create_training_sample(payload)
            if row:
                created += 1
            else:
                skipped += 1

        return {
            "total_events": len(events),
            "samples_created": created,
            "samples_skipped": skipped,
        }

