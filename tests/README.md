# Integration Tests

This directory contains integration tests for the RHEL Patching Automation system.

## Purpose

The integration test suite verifies that all components of the patching system are correctly configured and working together as expected.

## Test Coverage

The integration test suite (`integration_test.yaml`) checks the following:

1. **Inventory File** - Verifies that the Ansible inventory file exists
2. **Package File** - Verifies that `packages_to_patch.txt` exists
3. **Master Playbook Syntax** - Runs syntax check on `master_patch.yaml`
4. **Report Playbook Syntax** - Runs syntax check on `generate_report.yaml`
5. **Package Parser Module** - Tests the custom `package_parser` Ansible module
6. **Roles Directory** - Verifies that the roles directory exists
7. **Library Directory** - Verifies that the library directory exists (contains custom modules)
8. **Ansible Config** - Verifies that `ansible.cfg` exists

## Usage

### Run all integration tests:

```bash
ansible-playbook tests/integration_test.yaml
```

### Expected output

All tests should PASS with output similar to:

```
==========================================
  INTEGRATION TEST RESULTS
==========================================
Inventory file: PASS
Package file: PASS
Master playbook syntax: PASS
Report playbook syntax: PASS
Package parser module: PASS
Roles directory: PASS
Library directory: PASS
Ansible config: PASS
==========================================
Packages parsed: 20
Architectures: x86_64
RHEL versions: el8, el9
==========================================
Total tests: 8
Passed: 8
Failed: 0
==========================================
STATUS: ALL TESTS PASSED
```

### Test failures

If any critical test fails, the playbook will fail with a non-zero exit code and display error messages to help you diagnose the issue.

## Continuous Integration

These tests are designed to be run as part of a CI/CD pipeline to ensure changes don't break the system.

## Adding new tests

To add new tests, edit `tests/integration_test.yaml` and add additional tasks following the existing pattern:

1. Perform the test/check
2. Store the result in the `test_results` dictionary
3. Display the result
4. Mark `critical_failures: true` if the test is critical and fails
