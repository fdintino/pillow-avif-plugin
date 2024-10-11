.DEFAULT_GOAL := help

.PHONY: clean
clean:
	rm src/pillow_avif/*.so || true
	rm -r build || true
	find . -name __pycache__ | xargs rm -r || true

.PHONY: coverage
coverage:
	python3 -c "import pytest" > /dev/null 2>&1 || python3 -m pip install pytest
	python3 -m pytest -qq
	rm -r htmlcov || true
	python3 -c "import coverage" > /dev/null 2>&1 || python3 -m pip install coverage
	python3 -m coverage report

.PHONY: install
install:
	python3 -m pip -v install .

.PHONY: install-coverage
install-coverage:
	CFLAGS="-coverage -Werror=implicit-function-declaration" python3 -m pip -v install .

.PHONY: debug
debug:
# make a debug version if we don't have a -dbg python. Leaves in symbols
# for our stuff, kills optimization, and redirects to dev null so we
# see any build failures.
	make clean > /dev/null
	CFLAGS='-g -O0' python3 -m pip -v install . > /dev/null

.PHONY: release-test
release-test:
	python3 Tests/check_release_notes.py
	python3 -m pip install -e .[tests]
	python3 -m pytest tests
	python3 -m pip install .
	python3 -m pytest -qq

.PHONY: sdist
sdist:
	python3 -m build --help > /dev/null 2>&1 || python3 -m pip install build
	python3 -m build --sdist
	python3 -m twine --help > /dev/null 2>&1 || python3 -m pip install twine
	python3 -m twine check --strict dist/*

.PHONY: test
test:
	python3 -c "import pytest" > /dev/null 2>&1 || python3 -m pip install pytest
	python3 -m pytest -qq

.PHONY: lint
lint:
	python3 -c "import tox" > /dev/null 2>&1 || python3 -m pip install tox
	python3 -m tox -e lint

.PHONY: lint-fix
lint-fix:
	python3 -c "import black" > /dev/null 2>&1 || python3 -m pip install black
	python3 -m black .
