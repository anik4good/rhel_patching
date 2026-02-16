#!/usr/bin/env python3
"""
Ansible Module: package_parser
Parse RPM package strings from a package list file

This module reads a file containing RPM package names and extracts
structured information about each package including:
- name: Package name
- version: Package version
- release: Package release
- arch: Package architecture
- full_version: Combined version-release string
- filename: Original package filename
"""

import os
import re
from ansible.module_utils.basic import AnsibleModule


def parse_package_string(package_string):
    """
    Parse an RPM package string and extract its components.

    Args:
        package_string (str): RPM package string (e.g., "nginx-1.28.2-1.el9.ngx.x86_64.rpm")

    Returns:
        dict: Dictionary containing parsed package information with keys:
              - name: Package name
              - version: Package version
              - release: Package release
              - arch: Package architecture
              - full_version: Combined version-release string
              - filename: Original package string

    Examples:
        >>> parse_package_string("nginx-1.28.2-1.el9.ngx.x86_64.rpm")
        {
            'name': 'nginx',
            'version': '1.28.2',
            'release': '1.el9.ngx',
            'arch': 'x86_64',
            'full_version': '1.28.2-1.el9.ngx',
            'filename': 'nginx-1.28.2-1.el9.ngx.x86_64.rpm'
        }
    """
    # Remove .rpm extension if present
    if package_string.endswith('.rpm'):
        package_string = package_string[:-4]

    # RPM package naming convention: name-version-release.arch.rpm
    # Pattern explanation:
    # ^(.+?)          - Package name (non-greedy match until first dash)
    # -([^-]+)        - Version (everything until next dash)
    # -([^-]+)        - Release (everything until next dot)
    # \.([^.]+)$      - Architecture (everything after last dot)
    pattern = r'^(.+?)-([^-]+)-([^-]+)\.([^.]+)$'

    match = re.match(pattern, package_string)

    if match:
        name, version, release, arch = match.groups()
        return {
            'name': name,
            'version': version,
            'release': release,
            'arch': arch,
            'full_version': f'{version}-{release}',
            'filename': package_string + '.rpm'
        }
    else:
        # Return None or raise an error if pattern doesn't match
        return None


def read_package_file(package_file):
    """
    Read and parse packages from a package list file.

    Args:
        package_file (str): Path to the package list file

    Returns:
        tuple: (list of parsed package dicts, list of error messages)
               The error list contains any lines that couldn't be parsed

    Raises:
        FileNotFoundError: If the package file doesn't exist
    """
    if not os.path.exists(package_file):
        raise FileNotFoundError(f"Package file not found: {package_file}")

    packages = []
    errors = []

    with open(package_file, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()

            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue

            # Parse the package string
            parsed = parse_package_string(line)

            if parsed:
                packages.append(parsed)
            else:
                errors.append({
                    'line': line_num,
                    'content': line,
                    'message': f'Failed to parse package string on line {line_num}'
                })

    return packages, errors


def main():
    """
    Main function for Ansible module execution.
    """
    # Define module arguments
    module_args = dict(
        package_file=dict(type='str', required=True),
    )

    # Initialize the Ansible module
    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    # Get parameters
    package_file = module.params['package_file']

    try:
        # Read and parse the package file
        packages, errors = read_package_file(package_file)

        # Prepare the result
        result = {
            'changed': False,
            'packages': packages,
            'package_count': len(packages),
            'errors': errors,
            'error_count': len(errors),
            'package_file': package_file
        }

        # Add summary information
        if packages:
            # Get unique architectures
            archs = list(set(pkg['arch'] for pkg in packages))
            # Get RHEL versions from release field
            rhel_versions = []
            for pkg in packages:
                if 'el8' in pkg['release'] and 'el8' not in rhel_versions:
                    rhel_versions.append('el8')
                elif 'el9' in pkg['release'] and 'el9' not in rhel_versions:
                    rhel_versions.append('el9')

            result['summary'] = {
                'architectures': sorted(archs),
                'rhel_versions': sorted(rhel_versions)
            }

        # Return the result
        module.exit_json(**result)

    except FileNotFoundError as e:
        module.fail_json(msg=str(e))
    except Exception as e:
        module.fail_json(msg=f"Error parsing package file: {str(e)}")


if __name__ == '__main__':
    main()
