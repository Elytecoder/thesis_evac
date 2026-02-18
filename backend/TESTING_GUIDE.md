# Testing Guide

This document explains how to run and understand the test suite for the Evacuation Route Recommendation backend.

---

## Test Coverage

The test suite covers:

### 1. **Model Tests** (8 test files)
- `apps/users/tests/test_models.py` - User model (resident/MDRRMO roles)
- `apps/evacuation/tests/test_models.py` - Evacuation centers
- `apps/hazards/tests/test_models.py` - Baseline hazards and hazard reports
- `apps/routing/tests/test_models.py` - Road segments and route logs

### 2. **Algorithm Tests** (4 test files)
- `apps/validation/tests/test_naive_bayes.py` - Naive Bayes validation
- `apps/validation/tests/test_consensus.py` - Consensus scoring
- `apps/risk_prediction/tests/test_random_forest.py` - Random Forest risk prediction
- `apps/routing/tests/test_dijkstra.py` - Modified Dijkstra routing

### 3. **API Tests** (1 test file)
- `apps/mobile_sync/tests/test_api.py` - All 6 API endpoints

### 4. **Integration Tests** (1 test file)
- `apps/mobile_sync/tests/test_integration.py` - Complete system flows

---

## Running Tests

### Install test dependencies first:

```bash
pip install -r requirements.txt
```

### Run all tests:

```bash
# Using Django's test runner
python manage.py test

# Using pytest (recommended)
pytest
```

### Run specific test files:

```bash
# Test specific app
python manage.py test apps.validation

# Test specific file
pytest apps/validation/tests/test_naive_bayes.py

# Test specific class
pytest apps/validation/tests/test_naive_bayes.py::NaiveBayesValidatorTests

# Test specific method
pytest apps/validation/tests/test_naive_bayes.py::NaiveBayesValidatorTests::test_validate_valid_report
```

### Run tests with coverage:

```bash
pip install coverage
coverage run --source='.' manage.py test
coverage report
coverage html  # Generate HTML report
```

### Run tests by category:

```bash
# Unit tests only
pytest -m unit

# Integration tests only
pytest -m integration

# API tests only
pytest -m api
```

---

## Test Categories

### Model Tests
Test database schema, validation, and relationships.

**Example test cases:**
- Creating models with required fields
- Default values
- String representations
- Model relationships (ForeignKey, reverse lookups)
- Field validation

### Algorithm Tests
Test the ML/algorithm logic independent of Django.

**Example test cases:**
- Training with data
- Prediction accuracy
- Edge cases (empty data, extreme values)
- Score clamping to [0, 1]
- Fallback behavior

### API Tests
Test REST endpoints with various scenarios.

**Example test cases:**
- Successful requests (200, 201)
- Authentication (401, 403)
- Validation errors (400)
- Not found (404)
- Permission checks (MDRRMO vs Resident)

### Integration Tests
Test complete user flows through the system.

**Example test cases:**
- Resident flow: bootstrap → report → route
- MDRRMO flow: view pending → approve/reject
- Consensus scoring with multiple reports
- System behavior with missing data

---

## Test Data

All tests use:
- **In-memory SQLite database** (fast, isolated)
- **Mock data** created in `setUp()` methods
- **Test fixtures** where needed

Tests do NOT use:
- Production database
- External APIs
- Real MDRRMO data
- Actual file uploads

---

## Writing New Tests

### Template for model tests:

```python
from django.test import TestCase
from apps.myapp.models import MyModel

class MyModelTests(TestCase):
    def setUp(self):
        """Create test data."""
        pass
    
    def test_create_model(self):
        """Test model creation."""
        obj = MyModel.objects.create(field='value')
        self.assertEqual(obj.field, 'value')
```

### Template for API tests:

```python
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from apps.users.models import User

class MyAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='test', password='pass'
        )
        self.token = Token.objects.create(user=self.user)
    
    def test_endpoint(self):
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Token {self.token.key}'
        )
        response = self.client.get('/api/endpoint/')
        self.assertEqual(response.status_code, 200)
```

---

## Common Assertions

```python
# Status codes
self.assertEqual(response.status_code, 200)
self.assertEqual(response.status_code, 201)  # Created
self.assertEqual(response.status_code, 400)  # Bad request
self.assertEqual(response.status_code, 401)  # Unauthorized
self.assertEqual(response.status_code, 403)  # Forbidden
self.assertEqual(response.status_code, 404)  # Not found

# Response data
self.assertIn('key', response.data)
self.assertEqual(response.data['field'], 'value')
self.assertIsInstance(response.data, list)
self.assertGreater(len(response.data), 0)

# Model state
self.assertEqual(obj.field, expected_value)
self.assertTrue(obj.is_active)
self.assertIsNotNone(obj.created_at)

# Numbers
self.assertGreater(score, 0.5)
self.assertLess(risk, 0.3)
self.assertGreaterEqual(value, 0.0)
self.assertLessEqual(value, 1.0)
```

---

## Troubleshooting

### Tests fail with "No module named 'apps'"
- Make sure you're running from the project root (`backend/`)
- Check that `DJANGO_SETTINGS_MODULE=config.settings` is set

### Tests fail with "django.core.exceptions.ImproperlyConfigured"
- Run `python manage.py migrate` first
- Check that `config/settings.py` is correct

### Tests fail with "sklearn not found"
- Install scikit-learn: `pip install scikit-learn`
- Or: tests should fall back gracefully (check test output)

### Tests are slow
- Use pytest instead of Django test runner (faster)
- Tests use in-memory database (should be fast)
- Check for unnecessary database queries

---

## Continuous Integration

To set up CI/CD (GitHub Actions, GitLab CI, etc.):

```yaml
# Example .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
        with:
          python-version: 3.11
      - run: pip install -r requirements.txt
      - run: python manage.py migrate
      - run: pytest --cov
```

---

## Test Statistics

Total test files: **14**
Total test cases: **~100+**

Coverage target: **80%+** for:
- Models
- Services/algorithms
- API views
- Critical business logic

---

## Next Steps

After running tests:

1. **Check coverage**: Aim for 80%+ on critical code
2. **Fix failing tests**: All tests should pass before deployment
3. **Add tests**: When adding new features, write tests first (TDD)
4. **Review results**: Use test output to find bugs early

For production deployment, ensure:
- ✅ All tests pass
- ✅ No security warnings
- ✅ Mock data is clearly marked
- ✅ Real MDRRMO data integration is documented
