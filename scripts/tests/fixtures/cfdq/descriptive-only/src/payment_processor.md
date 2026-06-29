# PaymentProcessor — descriptive-only fixture code

This fixture exists to exercise the feedforward arm (AC-11). The spec has a
descriptive-only ## Architecture (no normative SHALL commitments). The code
here is illustrative but the fixture's purpose is to trigger the design-review
FF arm finding, not to be reviewed as a deliverable.

```python
class PaymentProcessor:
    def validate_payment(self, amount, card): ...
    def charge_card(self, card, amount): ...
    def settle_payment(self, payment_id): ...
    def notify_customer(self, customer_id, status): ...
```

Callers must invoke these in order. The spec never committed to whether this
should be a deep module or expose the sequence.
