# When to mock

Adapted from mattpocock/skills (MIT, see LICENSE). Examples in Python.

Mock at **system boundaries** only:

- External APIs (LLM providers, payment, email)
- Time and randomness
- Databases and the file system, when a test instance is impractical (prefer a real test DB or `tmp_path`)

Everything you own (your modules, your classes, internal collaborators) runs for real in the test.

## Design boundaries to be mockable

**Inject the dependency** instead of constructing it inside:

```python
# Easy to mock
def process_payment(order, payment_client):
    return payment_client.charge(order.total)

# Hard to mock
def process_payment(order):
    client = StripeClient(os.environ["STRIPE_KEY"])
    return client.charge(order.total)
```

**Prefer one function per external operation** over one generic fetcher:

```python
# GOOD: each operation mocks independently, one shape each
class Api:
    def get_user(self, user_id): ...
    def get_orders(self, user_id): ...
    def create_order(self, data): ...

# BAD: the mock needs conditional logic to fake each endpoint
class Api:
    def fetch(self, endpoint, **options): ...
```

## A mock must be able to fail

A mock that returns fixtures regardless of its input cannot catch a bug in that input. When the risk is in the request (the query, the prompt, the payload), assert on what the mock received.
