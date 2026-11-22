# Good and bad tests

Adapted from mattpocock/skills (MIT, see LICENSE). Examples in Python/pytest.

## Good: behaviour through the public interface

```python
def test_user_can_check_out_with_valid_cart():
    cart = create_cart()
    cart.add(product)
    result = checkout(cart, payment_method)
    assert result.status == "confirmed"
```

- Tests behaviour callers care about, through the public API only.
- Survives internal refactors.
- The name says WHAT, not HOW.
- One logical assertion per test.

## Bad: coupled to implementation

```python
# BAD: asserts on an internal call
def test_checkout_calls_payment_service(mocker):
    process = mocker.patch("shop.payment_service.process")
    checkout(cart, payment)
    process.assert_called_once_with(cart.total)
```

Red flags: mocking internal collaborators, testing private functions, asserting call counts or order, a name that describes HOW, breaking on a refactor that kept behaviour.

## Bad: verifying through a side channel

```python
# BAD: bypasses the interface
def test_create_user_saves_to_database(db):
    create_user(name="Alice")
    assert db.execute("SELECT 1 FROM users WHERE name = ?", ("Alice",)).fetchone()

# GOOD: verifies through the interface
def test_created_user_is_retrievable():
    user = create_user(name="Alice")
    assert get_user(user.id).name == "Alice"
```

## Bad: tautological

```python
# BAD: expected value recomputed the way the code computes it
def test_total_sums_line_items():
    items = [{"price": 10}, {"price": 5}]
    assert calculate_total(items) == sum(i["price"] for i in items)

# GOOD: independent, known literal
def test_total_sums_line_items():
    assert calculate_total([{"price": 10}, {"price": 5}]) == 15
```
