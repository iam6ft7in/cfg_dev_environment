---
description: Python rules — uv, ruff, pytest, src layout, Python 3.12+
paths: ["**/*.py", "**/pyproject.toml", "**/requirements*.txt"]
---

# Python Rules

## Environment Management
- Always use uv for virtual environments: `uv venv`, `uv add`, `uv run`
- Virtual environment lives at .venv/ in project root (gitignored)
- Python minimum version: 3.12 — use 3.12+ features freely
- Dependencies declared in pyproject.toml, not requirements.txt

## Code Quality
- Linting and formatting: ruff (replaces flake8, black, isort)
- Run before committing: `uv run ruff check .` and `uv run ruff format .`
- Line length: 88 characters (ruff default)
- Use type hints for all function signatures in new code

## Project Structure
- Use src/ layout: source code lives in src/{package_name}/
- Tests live in tests/ (not inside src/)
- Entry point: src/{package_name}/main.py
- Configuration: pyproject.toml only (no setup.py, no setup.cfg)

## Import Standards
- Prefer absolute imports over relative imports
- Group imports: stdlib, third-party, local (ruff handles ordering)

## Testing
- Test framework: pytest
- Run tests: `uv run pytest`
- Test files: tests/test_*.py or tests/*_test.py
- Aim for meaningful test names: test_altitude_hold_activates_at_threshold

## Security
- Secrets via environment variables, loaded with python-dotenv
- .env is gitignored; .env.example is committed with placeholder values
- Never hardcode credentials, API keys, or passwords

## Variable Syntax Note
- Python uses f-strings: f"{variable}" — this is the standard
- The ${variable} curly brace rule does NOT apply to Python (different syntax)
