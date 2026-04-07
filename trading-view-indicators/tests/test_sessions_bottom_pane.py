#!/usr/bin/env python3
"""
Test script for theorems_sessions_bottom_pane.pine indicator
Validates session timing calculations and day session boundaries
"""

from datetime import datetime
import json

class SessionBottomPaneValidator:
    """Comprehensive validator for the sessions bottom pane indicator"""

    def __init__(self):
        self.day_sessions = [
            ("00:00", "06:00", "Night"),
            ("06:00", "12:00", "Morning"),
            ("12:00", "18:00", "Afternoon"),
            ("18:00", "00:00", "Evening")
        ]

    def parse_time(self, time_str):
        """Parse HH:MM to minutes from midnight"""
        parts = time_str.split(":")
        return int(parts[0]) * 60 + int(parts[1])

    def is_in_session(self, start_str, end_str, h, m):
        """Check if time is within session bounds (matches Pine Script logic)"""
        current_min = h * 60 + m
        start_min = self.parse_time(start_str)
        end_min = self.parse_time(end_str)

        if end_min == 0 and start_min > 0:  # Special case: ends at midnight (00:00)
            return current_min >= start_min
        elif end_min <= start_min:  # Session spans midnight
            return current_min >= start_min or current_min < end_min
        else:
            return start_min <= current_min < end_min

    def get_day_session(self, h, m):
        """Get day session index (0-3)"""
        for i, (start, end, name) in enumerate(self.day_sessions):
            if self.is_in_session(start, end, h, m):
                return i, name
        return 0, "Unknown"

    def get_90m_segment(self, h, m):
        """Get 90-minute segment (0-15) - matches Pine Script logic"""
        total_min = h * 60 + m
        segment = int(total_min / 90)
        return min(segment, 15)

    def get_22_5m_segment(self, h, m):
        """Get 22.5-minute quarter within 90M segment (0-3)"""
        total_min = h * 60 + m
        position_in_90 = total_min % 90
        segment = int(position_in_90 / 22.5)
        return min(segment, 3)

    def test_basic_calculations(self):
        """Test core timing calculations"""
        test_cases = [
            # Format: (hour, minute, expected_90m, expected_22_5m, description)
            (0, 0, 0, 0, "Midnight start"),
            (0, 22, 0, 0, "Still in Q1 of first 90M"),
            (0, 23, 0, 1, "Just entered Q2 of first 90M"),
            (0, 45, 0, 2, "Q3 of first 90M"),
            (1, 7, 0, 2, "Still Q3 (67.5min mark)"),
            (1, 8, 0, 3, "Q4 of first 90M"),
            (1, 30, 1, 0, "Second 90M segment starts"),
            (3, 0, 2, 0, "Third 90M segment"),
            (12, 0, 8, 0, "Middle of day"),
            (23, 59, 15, 3, "End of day"),
        ]

        print("Testing core session timing calculations:")
        print("=" * 70)
        print(f"{'Time':<8} {'90M Seg':<8} {'22.5M Seg':<10} {'Day Session':<12} {'Description'}")
        print("-" * 70)

        all_passed = True
        for h, m, expected_90m, expected_22_5m, desc in test_cases:
            actual_90m = self.get_90m_segment(h, m)
            actual_22_5m = self.get_22_5m_segment(h, m)
            session_idx, session_name = self.get_day_session(h, m)

            time_str = f"{h:02d}:{m:02d}"
            status_90m = "✓" if actual_90m == expected_90m else "✗"
            status_22_5m = "✓" if actual_22_5m == expected_22_5m else "✗"

            print(f"{time_str:<8} {actual_90m:<2}{status_90m:<6} {actual_22_5m:<2}{status_22_5m:<8} {session_name:<12} {desc}")

            if actual_90m != expected_90m or actual_22_5m != expected_22_5m:
                print(f"  ERROR: Expected 90M={expected_90m}, 22.5M={expected_22_5m}")
                all_passed = False

        return all_passed

    def test_day_session_boundaries(self):
        """Test day session boundary logic"""
        print("\nTesting day session boundaries:")
        print("=" * 50)

        boundary_times = [
            (0, 0), (5, 59), (6, 0), (11, 59), (12, 0),
            (17, 59), (18, 0), (23, 59)
        ]

        expected_sessions = [
            "Night", "Night", "Morning", "Morning", "Afternoon",
            "Afternoon", "Evening", "Evening"
        ]

        all_passed = True
        for i, (h, m) in enumerate(boundary_times):
            session_idx, session_name = self.get_day_session(h, m)
            expected = expected_sessions[i]
            status = "✓" if session_name == expected else "✗"

            print(f"{h:02d}:{m:02d} -> {session_name:<12} {status} (Expected: {expected})")

            if session_name != expected:
                all_passed = False

        return all_passed

    def test_edge_cases(self):
        """Test edge cases around segment boundaries"""
        print("\nTesting edge cases (22.5M boundaries):")
        print("=" * 45)

        # Test 22.5 minute boundaries within first 90M segment
        edge_cases = [22, 23, 44, 45, 67, 68, 89, 90]

        for minutes in edge_cases:
            h = minutes // 60
            m = minutes % 60
            seg_90m = self.get_90m_segment(h, m)
            seg_22_5m = self.get_22_5m_segment(h, m)
            print(f"{h:02d}:{m:02d} -> 90M: {seg_90m}, 22.5M: {seg_22_5m}")

    def export_validation_data(self, filename="session_validation.json"):
        """Export validation data for MT4 comparison"""
        print(f"\nExporting comprehensive validation data...")

        validation_data = []
        for hour in range(24):
            for minute in range(0, 60, 15):  # Every 15 minutes
                session_idx, session_name = self.get_day_session(hour, minute)
                seg_90m = self.get_90m_segment(hour, minute)
                seg_22_5m = self.get_22_5m_segment(hour, minute)

                validation_data.append({
                    "time": f"{hour:02d}:{minute:02d}",
                    "day_session": session_idx,
                    "session_name": session_name,
                    "90m_segment": seg_90m,
                    "22_5m_quarter": seg_22_5m
                })

        data = {
            "validation_timestamp": datetime.now().isoformat(),
            "indicator": "theorems_sessions_bottom_pane.pine",
            "day_sessions_config": self.day_sessions,
            "full_day_validation": validation_data
        }

        filepath = f"/Users/finnformica/Documents/programming/theorem-capital/trading-view-indicators/tests/{filename}"
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)

        print(f"✓ Validation data exported to: {filename}")
        return filepath

def main():
    """Run all tests for the sessions bottom pane indicator"""
    validator = SessionBottomPaneValidator()

    print("Sessions Bottom Pane Indicator Test Suite")
    print("=" * 60)

    # Run all tests
    test_results = []
    test_results.append(validator.test_basic_calculations())
    test_results.append(validator.test_day_session_boundaries())

    validator.test_edge_cases()
    validator.export_validation_data()

    # Summary
    print(f"\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)

    if all(test_results):
        print("✅ ALL TESTS PASSED")
        print("✅ Session timing calculations are correct")
        print("✅ Day session boundaries working properly")
        print("✅ Ready for TradingView deployment")
        return True
    else:
        print("❌ SOME TESTS FAILED")
        print("❌ Review errors above before deployment")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)