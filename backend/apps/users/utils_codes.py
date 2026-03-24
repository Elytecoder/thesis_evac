"""Unique 6-digit display codes (100000–999999) for users and hazard reports."""
import secrets


def allocate_unique_six_digit(model_cls, field_name: str, max_tries: int = 64) -> int:
    for _ in range(max_tries):
        val = secrets.randbelow(900_000) + 100_000
        if not model_cls.objects.filter(**{field_name: val}).exists():
            return val
    raise RuntimeError(f'Could not allocate unique {model_cls.__name__}.{field_name}')
