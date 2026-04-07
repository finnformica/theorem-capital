#!/usr/bin/env python3
"""
Pine Script syntax validator for the sessions indicator.
Checks for common Pine Script v6 compatibility issues.
"""

import re
import os

class PineScriptValidator:
    """Validates Pine Script code for common syntax and compatibility issues"""

    def __init__(self):
        self.issues = []
        self.warnings = []

    def check_version_directive(self, code):
        """Check for proper version directive"""
        version_pattern = r'//@version=(\d+)'
        match = re.search(version_pattern, code)

        if not match:
            self.issues.append("Missing version directive. Add //@version=6")
        elif match.group(1) != '6':
            self.warnings.append(f"Using version {match.group(1)}, consider upgrading to version 6")

    def check_deprecated_functions(self, code):
        """Check for deprecated function calls"""
        deprecated_functions = {
            r'\bint\s*\(': 'int() is deprecated, use math.floor() instead',
            r'\bround\s*\(': 'round() is deprecated, use math.round() instead',
            r'\babs\s*\(': 'abs() is deprecated, use math.abs() instead',
            r'\bmax\s*\(': 'max() is deprecated, use math.max() instead',
            r'\bmin\s*\(': 'min() is deprecated, use math.min() instead'
        }

        for pattern, message in deprecated_functions.items():
            if re.search(pattern, code):
                # Check if it's already fixed with math.
                fixed_pattern = pattern.replace(r'\b', r'\bmath\.')
                if not re.search(fixed_pattern, code):
                    self.issues.append(message)

    def check_array_operations(self, code):
        """Check for proper array operations"""
        # Check for array.new usage
        if 'array.new<' not in code and 'array.new_' in code:
            self.warnings.append("Consider using array.new<type>() syntax for better type safety")

        # Check for proper array cleanup
        if 'array.push(' in code and 'array.shift(' not in code:
            self.warnings.append("Consider implementing array cleanup to prevent memory issues")

    def check_drawing_object_limits(self, code):
        """Check for proper drawing object limits"""
        if 'max_boxes_count=' not in code and 'box.new(' in code:
            self.warnings.append("Consider setting max_boxes_count in indicator() declaration")

        if 'max_labels_count=' not in code and 'label.new(' in code:
            self.warnings.append("Consider setting max_labels_count in indicator() declaration")

    def check_historical_data_access(self, code):
        """Check for proper historical data access patterns"""
        # Look for historical reference patterns
        historical_patterns = [r'\[\s*\d+\s*\]', r'hour\[\d+\]', r'minute\[\d+\]']

        for pattern in historical_patterns:
            if re.search(pattern, code):
                if 'na(' not in code:
                    self.warnings.append("Consider adding null checks for historical data access")
                break

    def check_performance_issues(self, code):
        """Check for potential performance issues"""
        # Check for loops in main execution
        if re.search(r'for\s+\w+\s*=.*in.*drawBarLayers', code):
            self.warnings.append("Heavy operations in loops may cause performance issues")

        # Check for excessive historical lookback
        if re.search(r'for\s+i\s*=.*\d{3,}', code):  # Looking for numbers 100+
            self.warnings.append("Large historical lookback may cause timeouts")

    def validate_file(self, filepath):
        """Validate a Pine Script file"""
        try:
            with open(filepath, 'r') as f:
                code = f.read()

            self.issues = []
            self.warnings = []

            # Run all checks
            self.check_version_directive(code)
            self.check_deprecated_functions(code)
            self.check_array_operations(code)
            self.check_drawing_object_limits(code)
            self.check_historical_data_access(code)
            self.check_performance_issues(code)

            return {
                'file': filepath,
                'issues': self.issues,
                'warnings': self.warnings,
                'status': 'FAIL' if self.issues else 'PASS'
            }

        except FileNotFoundError:
            return {
                'file': filepath,
                'issues': [f"File not found: {filepath}"],
                'warnings': [],
                'status': 'ERROR'
            }

    def print_report(self, result):
        """Print validation report"""
        print(f"\nPine Script Validation Report")
        print(f"File: {result['file']}")
        print(f"Status: {result['status']}")
        print("=" * 50)

        if result['issues']:
            print("\n❌ ISSUES (must fix):")
            for issue in result['issues']:
                print(f"  • {issue}")

        if result['warnings']:
            print("\n⚠️  WARNINGS (should consider):")
            for warning in result['warnings']:
                print(f"  • {warning}")

        if not result['issues'] and not result['warnings']:
            print("✅ No issues found!")

def main():
    """Run Pine Script validation on the indicator file"""
    validator = PineScriptValidator()

    indicator_path = "/Users/finnformica/Documents/programming/theorem-capital/trading-view-indicators/theorems_sessions_bottom_pane.pine"

    result = validator.validate_file(indicator_path)
    validator.print_report(result)

    return result['status'] == 'PASS'

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)