#!/usr/bin/env python3
"""
Test script for package_parser module
Tests the module functionality independently of Ansible
"""

import sys
import os

# Add the library directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'library'))

# Import the parser functions
from package_parser import parse_package_string, read_package_file


def test_parse_package_string():
    """Test the parse_package_string function"""
    print("Testing parse_package_string...")

    test_cases = [
        {
            'input': 'nginx-1.28.2-1.el9.ngx.x86_64.rpm',
            'expected': {
                'name': 'nginx',
                'version': '1.28.2',
                'release': '1.el9.ngx',
                'arch': 'x86_64'
            }
        },
        {
            'input': 'curl-8.7.1-1.el9_5.x86_64.rpm',
            'expected': {
                'name': 'curl',
                'version': '8.7.1',
                'release': '1.el9_5',
                'arch': 'x86_64'
            }
        }
    ]

    passed = 0
    failed = 0

    for test in test_cases:
        result = parse_package_string(test['input'])
        if result is None:
            print(f"  FAIL: Could not parse '{test['input']}'")
            failed += 1
            continue

        success = True
        for key, expected_value in test['expected'].items():
            if result.get(key) != expected_value:
                print(f"  FAIL: '{test['input']}' - {key}: expected '{expected_value}', got '{result.get(key)}'")
                success = False
                break

        if success:
            print(f"  PASS: {test['input']}")
            passed += 1
        else:
            failed += 1

    return passed, failed


def test_read_package_file():
    """Test the read_package_file function"""
    print("\nTesting read_package_file...")

    package_file = os.path.join(os.path.dirname(__file__), '..', 'packages_to_patch.txt')

    if not os.path.exists(package_file):
        print(f"  FAIL: Package file not found: {package_file}")
        return 0, 1

    try:
        packages, errors = read_package_file(package_file)

        print(f"  PASS: Read {len(packages)} packages")
        if errors:
            print(f"  WARNING: {len(errors)} parsing errors")

        # Display some sample packages
        print("\n  Sample packages:")
        for pkg in packages[:3]:
            print(f"    - {pkg['name']} {pkg['version']}-{pkg['release']} ({pkg['arch']})")

        # Get unique architectures
        archs = list(set(pkg['arch'] for pkg in packages))
        print(f"\n  Architectures: {', '.join(sorted(archs))}")

        # Get RHEL versions
        rhel_versions = []
        for pkg in packages:
            if 'el8' in pkg['release'] and 'el8' not in rhel_versions:
                rhel_versions.append('el8')
            elif 'el9' in pkg['release'] and 'el9' not in rhel_versions:
                rhel_versions.append('el9')

        print(f"  RHEL versions: {', '.join(sorted(rhel_versions))}")

        return len(packages), len(errors)

    except Exception as e:
        print(f"  FAIL: {str(e)}")
        return 0, 1


def main():
    """Main test function"""
    print("=" * 50)
    print("Package Parser Module Tests")
    print("=" * 50)

    passed, failed = test_parse_package_string()
    packages, errors = test_read_package_file()

    print("\n" + "=" * 50)
    print("Test Summary")
    print("=" * 50)
    print(f"Parse tests: {passed} passed, {failed} failed")
    print(f"File read: {packages} packages parsed, {errors} errors")

    if failed == 0 and errors == 0:
        print("\nSTATUS: ALL TESTS PASSED")
        return 0
    else:
        print("\nSTATUS: SOME TESTS FAILED")
        return 1


if __name__ == '__main__':
    sys.exit(main())
